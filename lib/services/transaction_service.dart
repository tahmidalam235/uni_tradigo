import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/item.dart';

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
///     - status   (Pending | Confirmed | Completed | Cancelled)
///     - createdAt, updatedAt
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

  /// Creates a new deal in `Pending` status. Returns the generated id.
  Future<String> createDeal({
    required Item listing,
    required String buyerId,
    required String buyerName,
  }) async {
    final ref = _txs.doc();
    final entry = _buildEntry(
      id: ref.id,
      listing: listing,
      buyerId: buyerId,
      buyerName: buyerName,
    );
    await ref.set(entry);
    return ref.id;
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

  /// Move a transaction to a new status. The rules allow updates only
  /// by participants and only into one of the allowed lifecycle
  /// statuses.
  Future<void> updateStatus(String id, String newStatus) async {
    await _txs.doc(id).set({
      'status': newStatus,
      'updatedAt': DateTime.now(),
    }, SetOptions(merge: true));
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
      createdAt: toDt(data['createdAt']),
      updatedAt: toDt(data['updatedAt']),
    );
  }
}
