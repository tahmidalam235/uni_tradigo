import 'package:cloud_firestore/cloud_firestore.dart';

/// ReportService — student reports on a listing and admin actions on it.
///
/// Two collections:
///   reports/{reportId} = {
///     listingId : String
///     listingTitle : String
///     reason    : String
///     reporterId: String  (Firebase Auth UID of the reporter)
///     reporterName: String
///     status    : 'Pending' | 'Resolved' | 'Dismissed'
///     resolution: 'Approved' | 'Removed' | ''
///     createdAt : Timestamp
///     updatedAt : Timestamp
///   }
class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  /// Creates a report. Throws if a duplicate by the same reporter for the
  /// same listing is still pending.
  Future<String> createReport({
    required String listingId,
    required String listingTitle,
    required String reason,
    required String reporterId,
    required String reporterName,
  }) async {
    final existing = await _reports
        .where('listingId', isEqualTo: listingId)
        .where('reporterId', isEqualTo: reporterId)
        .where('status', isEqualTo: 'Pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw StateError('You have already reported this listing.');
    }
    final ref = _reports.doc();
    await ref.set({
      'listingId': listingId,
      'listingTitle': listingTitle,
      'reason': reason,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'status': 'Pending',
      'resolution': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Streams all reports, newest first. Admin only (security rules).
  Stream<List<Map<String, dynamic>>> streamAll() {
    return _reports
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

  /// Streams pending reports — used by the admin dashboard badge.
  Stream<List<Map<String, dynamic>>> streamPending() {
    return _reports
        .where('status', isEqualTo: 'Pending')
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

  /// Resolves a report. Admin only.
  Future<void> resolve({
    required String reportId,
    required String resolution, // 'Approved' or 'Removed'
  }) async {
    await _reports.doc(reportId).update({
      'status': 'Resolved',
      'resolution': resolution,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Dismisses a report. Admin only.
  Future<void> dismiss(String reportId) async {
    await _reports.doc(reportId).update({
      'status': 'Dismissed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
