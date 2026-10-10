import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

/// ListingService — handles all Firestore operations for marketplace listings.
///
/// Collection: `listings`
/// Document layout:
///   id           : String  (Firestore doc id)
///   title        : String
///   description  : String
///   price        : double
///   category     : String
///   condition    : String
///   tradeType    : String
///   pickupLocation: String
///   sellerId     : String  (Firebase Auth UID)
///   sellerName   : String
///   sellerEmail  : String
///   imageUrl     : String  (Firebase Storage download URL, or empty)
///   createdAt    : Timestamp
///   isAvailable  : bool
///
/// Kept intentionally simple — no repository pattern, no use cases.
class ListingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reference to the `listings` collection.
  CollectionReference<Map<String, dynamic>> get _listings =>
      _db.collection('listings');

  /// Creates a new listing document and returns the generated id.
  /// The Firestore document id is used as the listing id.
  Future<String> createListing(Item item) async {
    // Use Firestore-generated doc id, then set fields.
    final docRef = _listings.doc();
    await docRef.set({
      'title': item.title,
      'description': item.description,
      'price': item.price,
      'category': item.category,
      'condition': item.condition,
      'tradeType': item.tradeType,
      'pickupLocation': item.pickupLocation,
      'sellerId': item.sellerId,
      'sellerName': item.sellerName,
      'sellerEmail': item.sellerEmail,
      'imageUrl': item.imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isAvailable': item.isAvailable,
    });
    return docRef.id;
  }

  /// Updates an existing listing document by id.
  Future<void> updateListing(Item item) async {
    await _listings.doc(item.id).update({
      'title': item.title,
      'description': item.description,
      'price': item.price,
      'category': item.category,
      'condition': item.condition,
      'tradeType': item.tradeType,
      'pickupLocation': item.pickupLocation,
      'imageUrl': item.imageUrl,
      'isAvailable': item.isAvailable,
    });
  }

  /// Fetches a single listing by id, or null if it does not exist.
  Future<Item?> fetchListingById(String id) async {
    final snap = await _listings.doc(id).get();
    if (!snap.exists) return null;
    return _toItem(snap.id, snap.data()!);
  }

  /// Streams ALL listings ordered by most recent. Used by the marketplace tab.
  Stream<List<Item>> streamAllListings() {
    return _listings
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _toItem(d.id, d.data()))
            .toList(growable: false));
  }

  /// One-shot fetch of all listings (newest first).
  Future<List<Item>> fetchAllListings() async {
    final snap = await _listings.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => _toItem(d.id, d.data()))
        .toList(growable: false);
  }

  /// Streams listings that belong to [sellerUid], newest first.
  /// Used by the My Listings screen.
  Stream<List<Item>> streamMyListings(String sellerUid) {
    return _listings
        .where('sellerId', isEqualTo: sellerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _toItem(d.id, d.data()))
            .toList(growable: false));
  }

  /// One-shot fetch of the current user's listings.
  Future<List<Item>> fetchMyListings(String sellerUid) async {
    final snap = await _listings
        .where('sellerId', isEqualTo: sellerUid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => _toItem(d.id, d.data()))
        .toList(growable: false);
  }

  /// Deletes a listing by id.
  Future<void> deleteListing(String id) async {
    await _listings.doc(id).delete();
  }

  /// Toggles availability (archive / activate) for a listing.
  Future<void> setAvailability(String id, bool isAvailable) async {
    await _listings.doc(id).update({'isAvailable': isAvailable});
  }

  // ---------- helper ----------

  Item _toItem(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    DateTime postedAt;
    if (created is Timestamp) {
      postedAt = created.toDate();
    } else if (created is DateTime) {
      postedAt = created;
    } else {
      postedAt = DateTime.now();
    }

    final priceRaw = data['price'];
    double price = 0;
    if (priceRaw is num) {
      price = priceRaw.toDouble();
    } else if (priceRaw is String) {
      price = double.tryParse(priceRaw) ?? 0;
    }

    return Item(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      price: price,
      category: (data['category'] ?? '').toString(),
      condition: (data['condition'] ?? '').toString(),
      tradeType: (data['tradeType'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      sellerName: (data['sellerName'] ?? '').toString(),
      sellerEmail: (data['sellerEmail'] ?? '').toString(),
      sellerId: (data['sellerId'] ?? '').toString(),
      pickupLocation: (data['pickupLocation'] ?? '').toString(),
      isAvailable: data['isAvailable'] is bool ? data['isAvailable'] as bool : true,
      postedAt: postedAt,
    );
  }
}
