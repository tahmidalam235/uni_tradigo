import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple Firestore helper for the `users` collection.
///
/// Document layout:
///   users/{uid} = {
///     name: String,
///     studentId: String,
///     department: String,
///     email: String,
///     createdAt: Timestamp,
///   }
///
/// For now this service is intentionally tiny: only what register flow needs.
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
    });
  }

  /// Reads the profile document at users/{uid}, or null if it doesn't exist.
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final snap = await _users.doc(uid).get();
    return snap.data();
  }
}
