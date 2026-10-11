import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple Firestore helper for the `users` collection.
///
/// Document layout (`users/{uid}`):
///   name       : String
///   studentId  : String
///   department : String
///   email      : String
///   createdAt  : Timestamp
///   updatedAt  : Timestamp
///   suspended  : bool         (admin can set this; suspends the user)
///
/// The user profile document is also where we keep fields that other
/// authenticated users are allowed to read (display name, department, etc.).
class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Creates (or overwrites) the profile document at users/{uid}.
  Future<void> saveProfile({
    required String uid,
    required String name,
    required String studentId,
    required String department,
    required String email,
  }) async {
    await _users.doc(uid).set({
      'name': name,
      'studentId': studentId,
      'department': department,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates only the profile fields that the user is allowed to change.
  /// Suspended status and email are NOT editable from the client.
  /// (The security rules mirror this.)
  ///
  /// Handles the "profile document doesn't exist yet" case (which happens
  /// for accounts created before the profile migration, or when the
  /// user signed up via a flow that didn't write a profile doc). In
  /// that case a Firestore `update` call fails with `NOT_FOUND`, so we
  /// fall back to a `set` (which is treated as a `create` by the
  /// security rules and only requires `isOwner(uid)`).
  Future<void> updateProfile({
    required String uid,
    required String name,
    required String department,
    String? studentId,
    String? fallbackEmail,
  }) async {
    final ref = _users.doc(uid);
    try {
      await ref.update({
        'name': name,
        'department': department,
        if (studentId != null) 'studentId': studentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
      // Profile document does not exist yet — create it. The `create`
      // rule only requires isOwner(uid), so we just need to write the
      // editable fields plus the immutable ones (email, createdAt,
      // suspended) so subsequent updates pass the immutable-fields
      // check in the `update` rule. `studentId` is included so future
      // edits don't have to re-supply it.
      await ref.set({
        'name': name,
        'department': department,
        'studentId': studentId ?? '',
        'email': fallbackEmail ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'suspended': false,
      });
    }
  }

  /// Reads the profile document at users/{uid}, or null if it doesn't exist.
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final snap = await _users.doc(uid).get();
    return snap.data();
  }

  /// Real-time stream of the profile document at users/{uid}.
  Stream<Map<String, dynamic>?> streamProfile(String uid) {
    return _users.doc(uid).snapshots().map((s) => s.data());
  }

  /// Streams a list of all user profiles. Used by the admin "Manage Users"
  /// screen. Requires admin custom claim (enforced in security rules).
  Stream<List<Map<String, dynamic>>> streamAllUsers() {
    return _users
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['uid'] = d.id;
              return data;
            }).toList(growable: false));
  }

  /// Admin-only: suspend or re-activate a user account by setting the
  /// `suspended` flag on their profile. The user is blocked from writing
  /// when this flag is true (see firestore.rules).
  Future<void> setSuspended(String uid, bool suspended) async {
    await _users.doc(uid).update({'suspended': suspended});
  }
}
