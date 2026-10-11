import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

/// WantedService — "I am looking for..." posts created by students.
///
/// Collection: `wantedPosts`
/// Document layout:
///   id           : String  (Firestore doc id)
///   title        : String
///   description  : String
///   postedBy     : String  (display name of the creator)
///   postedById   : String  (Firebase Auth UID of the creator)
///   department   : String
///   contactEmail : String
///   createdAt    : Timestamp
class WantedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _wanted =>
      _db.collection('wantedPosts');

  /// Streams all wanted posts, newest first.
  Stream<List<WantedPost>> streamAll() {
    return _wanted.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(_toPost).toList(growable: false),
        );
  }

  /// Streams the raw documents for wanted posts. Used by the listing UI
  /// to read the owner's uid for the "Contact Student" button.
  Stream<List<Map<String, dynamic>>> streamAllRaw() {
    return _wanted
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            })
            .toList(growable: false));
  }

  /// Streams the wanted posts created by a specific user.
  Stream<List<WantedPost>> streamMine(String uid) {
    return _wanted
        .where('postedById', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_toPost).toList(growable: false));
  }

  /// Creates a new wanted post. Returns the generated id.
  Future<String> create({
    required String title,
    required String description,
    required String postedBy,
    required String postedById,
    required String department,
    required String contactEmail,
  }) async {
    final ref = _wanted.doc();
    await ref.set({
      'title': title,
      'description': description,
      'postedBy': postedBy,
      'postedById': postedById,
      'department': department,
      'contactEmail': contactEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Updates an existing wanted post. Only the owner is allowed to update
  /// (enforced in security rules).
  Future<void> update({
    required String id,
    required String title,
    required String description,
    required String department,
  }) async {
    await _wanted.doc(id).update({
      'title': title,
      'description': description,
      'department': department,
    });
  }

  /// Deletes a wanted post. Only the owner is allowed (security rules).
  Future<void> delete(String id) async {
    await _wanted.doc(id).delete();
  }

  // ----- helper -----

  WantedPost _toPost(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    DateTime postedAt;
    if (created is Timestamp) {
      postedAt = created.toDate();
    } else {
      postedAt = DateTime.now();
    }
    return WantedPost(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      postedBy: (data['postedBy'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      postedAt: postedAt,
    );
  }
}
