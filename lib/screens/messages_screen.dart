import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/user_avatar.dart';
import '../widgets/verified_badge.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

/// MessagesScreen — list of conversations the current user participates in.
/// Backed by the `conversations` collection in Firestore.
class MessagesScreen extends StatelessWidget {
  final bool embedded;
  const MessagesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chat = ChatService();

    final body = uid.isEmpty
        ? const EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Please log in',
            subtitle: 'Sign in to view your messages.',
          )
        : StreamBuilder<List<ConversationSummary>>(
            stream: chat.streamMyConversations(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorState(
                  message: 'Details: ${snapshot.error}',
                  onRetry: () => (context as Element).markNeedsBuild(),
                );
              }
              final convos = snapshot.data ?? const <ConversationSummary>[];
              if (convos.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No messages yet',
                  subtitle:
                      'Start a conversation from a listing or wanted post.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: convos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = convos[i];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 4,
                      ),
                      leading: UserAvatar(
                        name: c.otherUserName,
                        radius: 22,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.otherUserName,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 12),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          c.lastMessage.isEmpty ? 'Say hello!' : c.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _ago(c.lastTime),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              peerName: c.otherUserName,
                              peerEmail: '',
                              peerUid: c.otherUserId,
                              conversationId: c.id,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );

    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: body,
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}