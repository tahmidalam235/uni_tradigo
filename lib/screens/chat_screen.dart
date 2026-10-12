import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/user_avatar.dart';
import '../widgets/verified_badge.dart';
import '../services/chat_service.dart';

/// ChatScreen — real-time chat with another student.
///
/// Opens immediately when pushed, showing the peer's name in the
/// AppBar. The conversation is initialized lazily inside the screen
/// (idempotent — reopens the existing conversation if any, otherwise
/// creates a new one), then messages stream in live.
///
/// To open a chat, just `Navigator.push` this screen with `peerUid`
/// and `peerName`. The screen resolves everything else itself, so the
/// caller never has to wait on an async Firestore write before
/// navigating.
class ChatScreen extends StatefulWidget {
  final String peerName;
  final String peerEmail;
  final String peerUid;

  /// Optional pre-computed conversation id. If null, the screen will
  /// derive the id from the two sorted uids (the same derivation the
  /// service uses), so the screen always reopens the right
  /// conversation.
  final String? conversationId;

  const ChatScreen({
    super.key,
    required this.peerName,
    required this.peerEmail,
    required this.peerUid,
    this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final _chat = ChatService();

  bool _sending = false;
  String? _conversationId;
  String? _initError;

  @override
  void initState() {
    super.initState();
    // If the caller already passed a conversationId, use it. Otherwise
    // compute the deterministic id from the sorted uids so this screen
    // always reopens the same conversation between the two users.
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _conversationId = widget.conversationId ??
        (myUid.isNotEmpty && widget.peerUid.isNotEmpty
            ? _chat.conversationIdFor(myUid, widget.peerUid)
            : null);
    // Kick off the idempotent conversation initialization in the
    // background. The screen renders immediately; messages will stream
    // in once the conversation exists.
    if (_conversationId != null && myUid.isNotEmpty) {
      _ensureConversation();
    } else {
      _initError = 'Cannot open chat: missing user or peer id.';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ensureConversation() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty || widget.peerUid.isEmpty) return;
    try {
      String myName = '';
      final profile =
          await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      if (profile.exists) {
        myName = (profile.data()?['name'] ?? '').toString();
      }
      final id = await _chat.ensureConversation(
        myUid: myUid,
        myName: myName,
        otherUid: widget.peerUid,
        otherName: widget.peerName,
      );
      if (!mounted) return;
      setState(() => _conversationId = id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final convoId = _conversationId;
    if (convoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening chat… try again in a moment.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      String myName = '';
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (profile.exists) {
        myName = (profile.data()?['name'] ?? '').toString();
      }
      await _chat.sendMessage(
        conversationId: convoId,
        senderId: user.uid,
        senderName: myName,
        text: text,
      );
      _ctrl.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final myUid = user?.uid ?? '';
    final convoId = _conversationId;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              name: widget.peerName,
              radius: 18,
              color: Colors.white,
              textColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.peerName,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const VerifiedBadge(
                        size: 14,
                        color: Colors.greenAccent,
                      ),
                    ],
                  ),
                  if (widget.peerEmail.isNotEmpty)
                    Text(
                      widget.peerEmail,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _initError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_initError!, textAlign: TextAlign.center),
              ),
            )
          : convoId == null || myUid.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<ChatMsg>>(
                  stream: _chat.streamMessagesFor(myUid, convoId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Could not load messages: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState ==
                            ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data ?? const <ChatMsg>[];
                    return Column(
                      children: [
                        Expanded(
                          child: messages.isEmpty
                              ? Center(
                                  child: Text(
                                    'Say hello!',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scroll,
                                  padding: const EdgeInsets.all(12),
                                  itemCount: messages.length,
                                  itemBuilder: (_, i) {
                                    final m = messages[i];
                                    final isMe = user != null &&
                                        m.senderId == user.uid;
                                    return _MessageBubble(
                                        message: m, isMe: isMe);
                                  },
                                ),
                        ),
                        SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border(
                                top: BorderSide(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _ctrl,
                                    decoration: InputDecoration(
                                      hintText: 'Message',
                                      fillColor: AppColors.surfaceMuted,
                                      filled: true,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        borderSide: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 1.4,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10),
                                    ),
                                    onSubmitted: (_) => _send(),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton.filled(
                                  onPressed: _sending ? null : _send,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMsg message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isMe ? scheme.primary : AppColors.surfaceMuted;
    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
        ),
      ),
    );
  }
}