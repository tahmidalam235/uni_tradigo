import 'package:cloud_firestore/cloud_firestore.dart';

/// ChatService — simple real-time chat between two students.
///
/// Storage layout:
///   conversations/{conversationId} = {
///     participants : [uidA, uidB]   // sorted, exactly 2 entries
///     participantNames: { uidA: "Name A", uidB: "Name B" }
///     lastMessage  : String
///     lastSenderId : String
///     lastUpdatedAt: Timestamp
///     createdAt    : Timestamp
///   }
///   conversations/{conversationId}/messages/{messageId} = {
///     senderId   : String
///     senderName : String
///     text       : String
///     createdAt  : Timestamp
///   }
///
/// The conversation id is derived deterministically from the two
/// participant UIDs (sorted and joined) so two students always agree on
/// the same conversation id without an extra "find or create" round-trip.
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  CollectionReference<Map<String, dynamic>> _messages(String conversationId) =>
      _conversations.doc(conversationId).collection('messages');

  /// Computes a stable conversation id for a pair of user UIDs.
  /// Sorts so (a,b) and (b,a) always produce the same id.
  String conversationIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('__');
  }

  /// Returns the existing conversation id between the current user and
  /// [otherUid], or null if no conversation has been started yet.
  Future<String?> findConversationId(String myUid, String otherUid) async {
    final id = conversationIdFor(myUid, otherUid);
    final snap = await _conversations.doc(id).get();
    return snap.exists ? id : null;
  }

  /// Ensures the conversation document exists with both participants
  /// recorded. Returns the conversation id.
  Future<String> ensureConversation({
    required String myUid,
    required String myName,
    required String otherUid,
    required String otherName,
  }) async {
    final id = conversationIdFor(myUid, otherUid);
    final ref = _conversations.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [myUid, otherUid]..sort(),
        'participantNames': {
          myUid: myName,
          otherUid: otherName,
        },
        'lastMessage': '',
        'lastSenderId': '',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Backfill display names for users that joined earlier without one.
      await ref.set({
        'participantNames': {
          myUid: myName,
          otherUid: otherName,
        },
      }, SetOptions(merge: true));
    }
    return id;
  }

  /// Streams the list of conversations the current user is part of,
  /// newest activity first. Used by the Messages tab.
  Stream<List<ConversationSummary>> streamMyConversations(String myUid) {
    return _conversations
        .where('participants', arrayContains: myUid)
        .orderBy('lastUpdatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _toSummary(myUid, d.id, d.data()))
            .toList(growable: false));
  }

  /// Streams the live messages of a conversation, oldest first.
  Stream<List<ChatMsg>> streamMessages(String conversationId) {
    return _messages(conversationId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _toMessage(d.id, d.data()))
            .toList(growable: false));
  }

  /// Sends a message in a conversation. Updates the conversation summary
  /// (lastMessage, lastUpdatedAt) atomically via a Firestore batch.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final batch = _db.batch();
    final msgRef = _messages(conversationId).doc();
    batch.set(msgRef, {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_conversations.doc(conversationId), {
      'lastMessage': text,
      'lastSenderId': senderId,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ----- helpers -----

  ConversationSummary _toSummary(
      String myUid, String id, Map<String, dynamic> data) {
    final names = (data['participantNames'] as Map?) ?? const {};
    String otherName = '';
    String otherUid = '';
    names.forEach((uid, name) {
      if (uid != myUid) {
        otherUid = uid.toString();
        otherName = (name ?? '').toString();
      }
    });
    final updated = data['lastUpdatedAt'];
    DateTime lastTime;
    if (updated is Timestamp) {
      lastTime = updated.toDate();
    } else {
      lastTime = DateTime.now();
    }
    return ConversationSummary(
      id: id,
      otherUserId: otherUid,
      otherUserName: otherName,
      lastMessage: (data['lastMessage'] ?? '').toString(),
      lastTime: lastTime,
    );
  }

  ChatMsg _toMessage(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    DateTime time;
    if (created is Timestamp) {
      time = created.toDate();
    } else {
      time = DateTime.now();
    }
    return ChatMsg(
      id: id,
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      time: time,
    );
  }
}

/// Lightweight DTOs for the chat layer. They live next to the service
/// so the screens only need to import one place.

class ConversationSummary {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime lastTime;

  ConversationSummary({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastTime,
  });
}

class ChatMsg {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime time;

  ChatMsg({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.time,
  });
}
