import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

/// WantedService — "I am looking for..." posts created by students.
///
/// Storage layout: a `wantedPosts` array field on each user document at
/// `users/{uid}`. Each entry has the same fields as before (title,
/// description, postedBy, postedById, department, contactEmail,
/// createdAt) plus a client-generated `id`.
///
/// Why not a top-level `wantedPosts` collection: the deployed Firestore
/// ruleset in this project does not include a `match /wantedPosts/...`
/// block, so writes return `PERMISSION_DENIED` from the default-deny
/// rule. Storing the wanted posts as a plain field on the existing
/// `users/{uid}` document piggy-backs on the `users/{userId}` rule that
/// is already in every shipped ruleset (read by any signed-in user,
/// write by the owner), so wanted posts work on any ruleset that
/// already lets users read/write their own profile. Other users can
/// still browse wanted posts by reading each user doc.
class WantedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _users.doc(uid);

  // Reads the wanted-post array out of a user document. Returns an
  // empty list if the field is missing or the doc doesn't exist.
  List<Map<String, dynamic>> _readList(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final raw = data['wantedPosts'];
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>().toList(growable: false);
    }
    return const [];
  }

  /// Streams ALL wanted posts across all users, newest first. The
  /// client subscribes to every user document in the `users`
  /// collection; any signed-in user can read them per the deployed
  /// `users/{userId}` rule.
  Stream<List<WantedPost>> streamAll() {
    return _users.snapshots().map((snap) {
      final all = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final list = _readList(doc.data());
        for (final entry in list) {
          all.add({...entry, 'postedById': entry['postedById'] ?? doc.id});
        }
      }
      all.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is Timestamp && tb is Timestamp) {
          return tb.compareTo(ta);
        }
        return 0;
      });
      return all.map(_toPost).toList(growable: false);
    });
  }

  /// Streams the raw wanted-post maps. Used by the listing UI to read
  /// the owner's uid for the "Contact Student" button.
  Stream<List<Map<String, dynamic>>> streamAllRaw() {
    return streamAll().map(
      (posts) => posts.map((p) {
        return <String, dynamic>{
          'id': p.id,
          'title': p.title,
          'description': p.description,
          'postedBy': p.postedBy,
          'postedById': p.postedById,
          'department': p.department,
          'createdAt': Timestamp.fromDate(p.postedAt),
        };
      }).toList(growable: false),
    );
  }

  /// Streams the wanted posts created by a specific user.
  Stream<List<WantedPost>> streamMine(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final list = _readList(snap.data());
      list.sort((a, b) {
        final ta = a['createdAt'];
        final tb = b['createdAt'];
        if (ta is Timestamp && tb is Timestamp) {
          return tb.compareTo(ta);
        }
        return 0;
      });
      return list.map(_toPost).toList(growable: false);
    });
  }

  /// Creates a new wanted post on the given user's document. Returns
  /// the generated id. Uses `FieldValue.arrayUnion` so the operation
  /// is atomic and the `users/{userId}` write rule (which requires
  /// email/studentId/createdAt/suspended to remain unchanged) is
  /// satisfied.
  Future<String> create({
    required String title,
    required String description,
    required String postedBy,
    required String postedById,
    required String department,
    required String contactEmail,
  }) async {
    final id = _db.collection('wantedPosts').doc().id; // unique id
    final entry = <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'postedBy': postedBy,
      'postedById': postedById,
      'department': department,
      'contactEmail': contactEmail,
      'createdAt': Timestamp.now(),
    };
    await _userDoc(postedById).set({
      'wantedPosts': FieldValue.arrayUnion([entry]),
    }, SetOptions(merge: true));
    return id;
  }

  /// Updates an existing wanted post owned by [uid]. Re-reads the
  /// current list, replaces the matching entry, and writes it back.
  /// (Cannot use `arrayUnion` for a partial-field update.)
  Future<void> update({
    required String uid,
    required String id,
    required String title,
    required String description,
    required String department,
  }) async {
    final ref = _userDoc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? const {};
    final list = _readList(data);
    final updated = <Map<String, dynamic>>[];
    for (final entry in list) {
      if (entry['id'] == id) {
        updated.add({
          ...entry,
          'title': title,
          'description': description,
          'department': department,
        });
      } else {
        updated.add(entry);
      }
    }
    await ref.set({
      'wantedPosts': updated,
    }, SetOptions(merge: true));
  }

  /// Deletes a wanted post owned by [uid].
  Future<void> delete({required String uid, required String id}) async {
    final ref = _userDoc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? const {};
    final list = _readList(data);
    final kept = list.where((e) => e['id'] != id).toList(growable: false);
    await ref.set({
      'wantedPosts': kept,
    }, SetOptions(merge: true));
  }

  // ----- helper -----

  WantedPost _toPost(Map<String, dynamic> data) {
    final created = data['createdAt'];
    DateTime postedAt;
    if (created is Timestamp) {
      postedAt = created.toDate();
    } else {
      postedAt = DateTime.now();
    }
    return WantedPost(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      postedBy: (data['postedBy'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      postedAt: postedAt,
    );
  }
}
