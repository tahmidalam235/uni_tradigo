import 'package:cloud_firestore/cloud_firestore.dart';

/// WishlistService — per-user wishlist persisted to Firestore.
///
/// Storage layout: a `wishlist` array field on the user document at
/// `users/{uid}`. The list contains listing ids. The user document
/// itself is protected by the `users/{userId}` rules in
/// `firestore.rules`: any signed-in user can read it, only the owner
/// can update it (and only fields other than the immutable ones
/// `email`, `studentId`, `createdAt`, `suspended`).
///
/// Why not a subcollection: storing wishlist entries as a
/// `users/{uid}/wishlist/{listingId}` subcollection requires an
/// explicit `match` rule for that subcollection, and an older
/// deployed ruleset that did not include it returns
/// `PERMISSION_DENIED` for the wishlist stream. Storing the ids as a
/// plain field on the existing `users/{uid}` document piggy-backs on
/// the already-granted `allow read, write: if isOwner(userId)` rule
/// for that document, so the wishlist works on any ruleset that
/// already lets the user read/write their own profile.
class WishlistService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  /// Streams the current user's wishlist listing ids.
  Stream<Set<String>> streamWishlistIds(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return <String>{};
      final raw = data['wishlist'];
      if (raw is List) {
        return raw.map((e) => e.toString()).toSet();
      }
      return <String>{};
    });
  }

  /// One-shot fetch (used on login).
  Future<Set<String>> fetchWishlistIds(String uid) async {
    final snap = await _userDoc(uid).get();
    final data = snap.data();
    if (data == null) return <String>{};
    final raw = data['wishlist'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toSet();
    }
    return <String>{};
  }

  /// Adds a listing id to the user's wishlist. Idempotent.
  Future<void> add(String uid, String listingId) async {
    final ref = _userDoc(uid);
    await ref.set({
      'wishlist': FieldValue.arrayUnion([listingId]),
    }, SetOptions(merge: true));
  }

  /// Removes a listing id from the user's wishlist. Idempotent.
  Future<void> remove(String uid, String listingId) async {
    final ref = _userDoc(uid);
    await ref.set({
      'wishlist': FieldValue.arrayRemove([listingId]),
    }, SetOptions(merge: true));
  }
}
