import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/item.dart';

/// TransactionService — handles the deal/transaction workflow.
///
/// Collection: `transactions`
/// Document layout:
///   id              : String  (Firestore doc id)
///   listingId       : String
///   listingTitle    : String
///   sellerId        : String  (Firebase Auth UID)
///   sellerName      : String
///   buyerId         : String  (Firebase Auth UID)
///   buyerName       : String
///   tradeType       : String  (Sale / Rent / Exchange / Donation)
///   price           : double
///   pickupLocation  : String
///   status          : String  ('Pending' | 'Confirmed' | 'Completed' | 'Cancelled')
///   createdAt       : Timestamp
///   updatedAt       : Timestamp
class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tx =>
      _db.collection('transactions');

  /// Creates a new deal in `Pending` status. The current user is the buyer.
  Future<String> createDeal({
    required Item listing,
    required String buyerId,
    required String buyerName,
  }) async {
    final ref = _tx.doc();
    await ref.set({
      'listingId': listing.id,
      'listingTitle': listing.title,
      'sellerId': listing.sellerId,
      'sellerName': listing.sellerName,
      'buyerId': buyerId,
      'buyerName': buyerName,
      // participants is what we use for the "transactions involving me"
      // array-contains query. Keep it in sync with buyerId/sellerId.
      'participants': [listing.sellerId, buyerId]..sort(),
      'tradeType': listing.tradeType,
      'price': listing.price,
      'pickupLocation': listing.pickupLocation,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Streams transactions where the current user is buyer OR seller,
  /// newest activity first.
  Stream<List<Transaction>> streamMyTransactions(String uid) {
    // Firestore can only do one `array-contains` per query, so we keep a
    // `participants` field on every transaction. See write paths below.
    return _tx
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => _toTxn(d.id, d.data())).toList(growable: false));
  }

  /// Streams transactions created by the current user (as buyer).
  Stream<List<Transaction>> streamMyPurchases(String uid) {
    return _tx
        .where('buyerId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => _toTxn(d.id, d.data())).toList(growable: false));
  }

  /// Streams transactions where the current user is the seller.
  Stream<List<Transaction>> streamMySales(String uid) {
    return _tx
        .where('sellerId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => _toTxn(d.id, d.data())).toList(growable: false));
  }

  /// Streams ALL transactions — admin only (enforced in security rules).
  Stream<List<Transaction>> streamAll() {
    return _tx.orderBy('updatedAt', descending: true).snapshots().map(
        (snap) =>
            snap.docs.map((d) => _toTxn(d.id, d.data())).toList(growable: false));
  }

  /// Move a transaction to a new status. Permission checks are enforced
  /// by the security rules (only buyer/seller can update their deal).
  Future<void> updateStatus(String id, String newStatus) async {
    await _tx.doc(id).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Helper used internally and by review creation.
  Future<Transaction?> fetchById(String id) async {
    final snap = await _tx.doc(id).get();
    if (!snap.exists) return null;
    return _toTxn(snap.id, snap.data() ?? const {});
  }

  // ----- helper -----

  Transaction _toTxn(String id, Map<String, dynamic> data) {
    DateTime toDt(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();
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
