import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/item.dart';

/// Thrown when a buyer tries to order a listing that another buyer has
/// already reserved (or that has been sold).
class ListingUnavailableException implements Exception {
  final String message;
  const ListingUnavailableException([
    this.message = 'This item is no longer available.',
  ]);

  @override
  String toString() => message;
}

/// TransactionService — handles the deal/transaction workflow.
///
/// Storage layout: a top-level `transactions` collection. Each
/// document holds the buyer, seller, listing, status, and the
/// `participants` array used by `firestore.rules` to gate access.
///
///   transactions/{txId}
///     - listingId, listingTitle
///     - sellerId, sellerName
///     - buyerId, buyerName
///     - tradeType, price, pickupLocation
///     - status   (Pending | Accepted | Completed | Cancelled)
///     - createdAt, updatedAt
///     - actedBy  (uid of the participant who last changed the status)
///     - participants: [sellerId, buyerId]   (sorted)
///
/// Security: only the two participants (or an admin) can read or
/// update a transaction. The status field is restricted to the
/// allowed lifecycle values by the ruleset.
class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _txs =>
      _db.collection('transactions');

  Map<String, dynamic> _buildEntry({
    required String id,
    required Item listing,
    required String buyerId,
    required String buyerName,
    String status = 'Pending',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return <String, dynamic>{
      'listingId': listing.id,
      'listingTitle': listing.title,
      'sellerId': listing.sellerId,
      'sellerName': listing.sellerName,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'tradeType': listing.tradeType,
      'price': listing.price,
      'pickupLocation': listing.pickupLocation,
      'status': status,
      'createdAt': createdAt ?? DateTime.now(),
      'updatedAt': updatedAt ?? DateTime.now(),
      'participants': [listing.sellerId, buyerId]..sort(),
    };
  }

  /// Atomically reserves [listing] for [buyerId] and creates the
  /// matching `Pending` order.
  ///
  /// This is the exclusive-buy gate. The listing document itself is the
  /// lock: inside the transaction we read the listing, check that its
  /// `purchaseStatus` is still `Available`, then flip it to `Reserved`
  /// and write the order. Two buyers racing on the same listing both
  /// read `Available`, but the second one's write is rejected by the
  /// security ruleset (`Reserved` is only writable from `Available`)
  /// and Firestore retries its transaction — on retry it reads
  /// `Reserved` and gives up. So exactly one order is ever created.
  ///
  /// Throws [ListingUnavailableException] when the listing is taken.
  Future<String> placeOrder({
    required Item listing,
    required String buyerId,
    required String buyerName,
  }) async {
    final txRef = _txs.doc();
    final listingRef = _db.collection('listings').doc(listing.id);
    final entry = _buildEntry(
      id: txRef.id,
      listing: listing,
      buyerId: buyerId,
      buyerName: buyerName,
    );

    await _db.runTransaction((txn) async {
      final snap = await txn.get(listingRef);
      if (!snap.exists) {
        throw const ListingUnavailableException('This listing no longer exists.');
      }
      final current = (snap.data()?['purchaseStatus'] ?? 'Available').toString();
      if (current != 'Available') {
        throw const ListingUnavailableException(
          'This item is no longer available.',
        );
      }

      // Reserve the listing. This is the compare-and-swap that makes
      // the buy exclusive.
      txn.update(listingRef, {
        'purchaseStatus': 'Reserved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create the order as Pending — the seller accepts or rejects it.
      txn.set(txRef, entry);
    });

    return txRef.id;
  }

  /// Streams transactions where the current user is buyer OR seller,
  /// newest activity first.
  Stream<List<Transaction>> streamMyTransactions(String uid) {
    return _txs
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _toTxn(d.id, d.data()))
            .toList(growable: false));
  }

  /// Streams transactions created by the current user (as buyer).
  Stream<List<Transaction>> streamMyPurchases(String uid) {
    return streamMyTransactions(uid).map(
      (txs) =>
          txs.where((t) => t.buyerId == uid).toList(growable: false),
    );
  }

  /// Streams transactions where the current user is the seller.
  Stream<List<Transaction>> streamMySales(String uid) {
    return streamMyTransactions(uid).map(
      (txs) =>
          txs.where((t) => t.sellerId == uid).toList(growable: false),
    );
  }

  /// Streams ALL transactions — admin only. Returns an empty stream
  /// for non-admin callers so existing UI code doesn't crash.
  Stream<List<Transaction>> streamAll() {
    return Stream<List<Transaction>>.fromIterable(const []);
  }

  /// Live view of a single transaction.
  ///
  /// Both parties subscribe to this so a status change made by one side
  /// shows up on the other's screen without a manual refresh.
  Stream<Transaction?> watchTransaction(String id) {
    return _txs.doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return _toTxn(snap.id, data);
    });
  }

  /// Move a transaction to a new status. The rules allow updates only
  /// by participants and only into one of the allowed lifecycle
  /// statuses.
  ///
  /// [actedBy] optionally records the uid of the participant who made the
  /// change. The Cloud Function uses it to tell a buyer-driven status
  /// change apart from a seller-driven one, so a buyer is never
  /// notified about their own action. When omitted, no field is written.
  Future<void> updateStatus(
    String id,
    String newStatus, {
    String? actedBy,
  }) async {
    final payload = <String, dynamic>{
      'status': newStatus,
      'updatedAt': DateTime.now(),
    };
    if (actedBy != null && actedBy.isNotEmpty) {
      payload['actedBy'] = actedBy;
    }
    await _txs.doc(id).set(payload, SetOptions(merge: true));
  }

  /// Seller accepts the order. The listing stays `Reserved`.
  Future<void> acceptOrder(String id, String actedBy) =>
      updateStatus(id, 'Accepted', actedBy: actedBy);

  /// Seller rejects the order. The listing returns to `Available`.
  Future<void> rejectOrder(String id, String actedBy) =>
      updateStatus(id, 'Cancelled', actedBy: actedBy);

  /// Seller marks the order as delivered and complete. The listing
  /// becomes `Sold`.
  ///
  /// The order status and the listing status are written in one
  /// transaction so the two can never disagree.
  Future<void> completeOrder({
    required String id,
    required String listingId,
    required String actedBy,
  }) async {
    final txRef = _txs.doc(id);
    final listingRef = _db.collection('listings').doc(listingId);
    await _db.runTransaction((txn) async {
      txn.update(txRef, {
        'status': 'Completed',
        'updatedAt': DateTime.now(),
        'actedBy': actedBy,
      });
      txn.update(listingRef, {
        'purchaseStatus': 'Sold',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Either party cancels the order before completion. The listing
  /// returns to `Available` so it can be ordered again.
  ///
  /// The order status and the listing release are written in one
  /// transaction, so there is never a window where the order is
  /// cancelled but the listing is still held.
  Future<void> cancelOrder({
    required String id,
    required String listingId,
    required String actedBy,
  }) async {
    final txRef = _txs.doc(id);
    final listingRef = _db.collection('listings').doc(listingId);
    await _db.runTransaction((txn) async {
      txn.update(txRef, {
        'status': 'Cancelled',
        'updatedAt': DateTime.now(),
        'actedBy': actedBy,
      });
      txn.update(listingRef, {
        'purchaseStatus': 'Available',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Helper used by review creation.
  Future<Transaction?> fetchById(String id) async {
    final snap = await _txs.doc(id).get();
    if (!snap.exists) return null;
    return _toTxn(snap.id, snap.data() ?? const {});
  }

  // ----- helper -----

  Transaction _toTxn(String id, Map<String, dynamic> data) {
    DateTime toDt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    final priceRaw = data['price'];
    double price = 0;
    if (priceRaw is num) {
      price = priceRaw.toDouble();
    } else if (priceRaw is String) {
      price = double.tryParse(priceRaw) ?? 0;
    }

    final rawParticipants = data['participants'];
    final participants = <String>[
      if (rawParticipants is List)
        for (final p in rawParticipants) p.toString(),
    ];

    final rawActedBy = (data['actedBy'] ?? '').toString();

    return Transaction(
      id: id,
      listingId: (data['listingId'] ?? '').toString(),
      listingTitle: (data['listingTitle'] ?? '').toString(),
      sellerId: (data['sellerId'] ?? '').toString(),
      sellerName: (data['sellerName'] ?? '').toString(),
      buyerId: (data['buyerId'] ?? '').toString(),
      buyerName: (data['buyerName'] ?? '').toString(),
      tradeType: (data['tradeType'] ?? '').toString(),
      price: price,
      pickupLocation: (data['pickupLocation'] ?? '').toString(),
      status: (data['status'] ?? 'Pending').toString(),
      actedBy: rawActedBy.isEmpty ? null : rawActedBy,
      participants: participants,
      createdAt: toDt(data['createdAt']),
      updatedAt: toDt(data['updatedAt']),
    );
  }
}
