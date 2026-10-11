import 'package:cloud_firestore/cloud_firestore.dart';

/// ChatService — real-time chat between two students.
///
/// Storage layout: a top-level `conversations` collection with a
/// `messages` subcollection.
///
///   conversations/{conversationId}
///     - participants: [uidA, uidB]   (sorted)
///     - participantNames: { uid: name }
///     - lastMessage, lastSenderId, lastUpdatedAt
///     - messages:  (subcollection)
///         conversations/{conversationId}/messages/{messageId}
///           - senderId, senderName, text, createdAt
///
/// Security is enforced by `firestore.rules`: only the two
/// participants can read or write a conversation and its messages.
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('conversations');

  /// Computes a stable conversation id for a pair of user UIDs.
  /// Sorts so (a,b) and (b,a) always produce the same id.
  String conversationIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('__');
  }

  DocumentReference<Map<String, dynamic>> _convoRef(String id) =>
      _conversations.doc(id);

  CollectionReference<Map<String, dynamic>> _messagesRef(String id) =>
      _convoRef(id).collection('messages');

  /// Ensures the conversation exists. Idempotent. Returns the
  /// conversation id.
  Future<String> ensureConversation({
    required String myUid,
    required String myName,
    required String otherUid,
    required String otherName,
  }) async {
    final id = conversationIdFor(myUid, otherUid);
    final ref = _convoRef(id);
    // set with merge: true won't create a new doc if it exists, and
    // won't clobber existing fields on update.
    final participants = [myUid, otherUid]..sort();
    await ref.set({
      'participants': participants,
      'participantNames': {myUid: myName, otherUid: otherName},
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return id;
  }

  /// Streams the list of conversations the current user is part of,
  /// newest activity first.
  Stream<List<ConversationSummary>> streamMyConversations(String myUid) {
    return _conversations
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => _toSummary(myUid, d.id, d.data()))
          .toList(growable: false);
      list.sort((a, b) => b.lastTime.compareTo(a.lastTime));
      return list;
    });
  }

  /// Streams the live messages of a conversation, oldest first.
  Stream<List<ChatMsg>> streamMessagesFor(
      String myUid, String conversationId) {
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _toMessage(d.id, d.data()))
            .toList(growable: false));
  }

  /// Sends a message in a conversation. Writes to the message
  /// subcollection and updates the parent conversation's last-*
  /// summary fields so list views can sort by recency.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final convoRef = _convoRef(conversationId);
    final msgRef = _messagesRef(conversationId).doc();
    final convoSnap = await convoRef.get();
    if (!convoSnap.exists) {
      // The conversation was never initialized. Create it now so the
      // first message isn't lost. (Caller normally opens the chat via
      // ensureConversation, but this is a safety net.)
      final parts = conversationId.split('__');
      if (parts.length != 2) {
        throw StateError('Malformed conversationId: $conversationId');
      }
      final otherUid = parts[0] == senderId ? parts[1] : parts[0];
      await ensureConversation(
        myUid: senderId,
        myName: senderName,
        otherUid: otherUid,
        otherName: '',
      );
    }
    final msg = <String, dynamic>{
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await msgRef.set(msg);
    await convoRef.set({
      'lastMessage': text,
      'lastSenderId': senderId,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    } else if (updated is DateTime) {
      lastTime = updated;
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
    } else if (created is DateTime) {
      time = created;
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
