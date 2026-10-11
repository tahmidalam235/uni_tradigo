import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

/// ReviewService — ratings and written feedback for a completed deal.
///
/// Collection: `reviews`
/// Document layout:
///   id             : String  (Firestore doc id)
///   transactionId  : String
///   listingId      : String
///   reviewerId     : String  (Firebase Auth UID)
///   reviewerName   : String
///   reviewedId     : String  (UID of the user being reviewed)
///   rating         : int     (1..5)
///   feedback       : String
///   createdAt      : Timestamp
class ReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _db.collection('reviews');

  /// Returns true if a review by [reviewerId] for [transactionId] already
  /// exists. Used to enforce "one review per transaction per reviewer".
  Future<bool> hasReviewed({
    required String transactionId,
    required String reviewerId,
  }) async {
    final snap = await _reviews
        .where('transactionId', isEqualTo: transactionId)
        .where('reviewerId', isEqualTo: reviewerId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Creates a new review. Throws if a duplicate already exists.
  /// The security rules also block duplicate writes for safety.
  Future<String> create({
    required String transactionId,
    required String listingId,
    required String reviewerId,
    required String reviewerName,
    required String reviewedId,
    required int rating,
    required String feedback,
  }) async {
    final exists = await hasReviewed(
      transactionId: transactionId,
      reviewerId: reviewerId,
    );
    if (exists) {
      throw StateError('You have already reviewed this transaction.');
    }
    final ref = _reviews.doc();
    await ref.set({
      'transactionId': transactionId,
      'listingId': listingId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewedId': reviewedId,
      'rating': rating,
      'feedback': feedback,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Streams all reviews for a specific user (most recent first).
  Stream<List<Review>> streamForUser(String uid) {
    return _reviews
        .where('reviewedId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_toReview).toList(growable: false));
  }

  /// Average rating (1..5) for a user. Returns 0 if no reviews.
  Future<double> averageRating(String uid) async {
    final snap = await _reviews.where('reviewedId', isEqualTo: uid).get();
    if (snap.docs.isEmpty) return 0;
    int total = 0;
    for (final d in snap.docs) {
      final r = d.data()['rating'];
      if (r is num) total += r.toInt();
    }
    return total / snap.docs.length;
  }

  Review _toReview(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    DateTime postedAt =
        created is Timestamp ? created.toDate() : DateTime.now();
    return Review(
      id: doc.id,
      transactionId: (data['transactionId'] ?? '').toString(),
      listingId: (data['listingId'] ?? '').toString(),
      reviewerId: (data['reviewerId'] ?? '').toString(),
      reviewerName: (data['reviewerName'] ?? '').toString(),
      reviewedId: (data['reviewedId'] ?? '').toString(),
      rating: (data['rating'] is num)
          ? (data['rating'] as num).toInt()
          : 0,
      feedback: (data['feedback'] ?? '').toString(),
      createdAt: postedAt,
    );
  }
}
