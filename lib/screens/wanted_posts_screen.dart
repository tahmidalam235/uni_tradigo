import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/busy_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_pill.dart';
import '../widgets/status_pill.dart';
import '../widgets/user_avatar.dart';
import '../widgets/verified_badge.dart';
import '../services/wanted_service.dart';
import 'chat_screen.dart';

/// WantedPostsScreen — shows wanted requests from other students.
///
/// Reads from the `wantedPosts` collection in Firestore. The current user
/// can create new ones via the FAB, and tap "Contact Student" to open a
/// real-time chat with the post's owner.
class WantedPostsScreen extends StatelessWidget {
  const WantedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = WantedService();
    return Scaffold(
      appBar: AppBar(title: const Text('Wanted Posts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.streamAllRaw(),
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
          final docs = snapshot.data ?? const <Map<String, dynamic>>[];
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.campaign_rounded,
              title: 'No wanted posts yet',
              subtitle: 'Tap "New" to ask for an item.',
            );
          }
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i];
              final id = (d['id'] ?? '').toString();
              final ownerUid = (d['postedById'] ?? '').toString();
              final isMine = ownerUid == uid && ownerUid.isNotEmpty;
              final post = WantedPost(
                id: id,
                title: (d['title'] ?? '').toString(),
                description: (d['description'] ?? '').toString(),
                postedBy: (d['postedBy'] ?? '').toString(),
                department: (d['department'] ?? '').toString(),
                postedAt: _toDt(d['createdAt']),
              );
              final contactEmail = (d['contactEmail'] ?? '').toString();
              return _WantedCard(
                post: post,
                ownerUid: ownerUid,
                isMine: isMine,
                onContact: () =>
                    _contact(context, post, ownerUid, contactEmail),
                onEdit: () => _openEditor(context, post),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _contact(
      BuildContext context, WantedPost p, String? ownerUid,
      String contactEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (ownerUid == null || ownerUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading contact info…')),
      );
      return;
    }
    if (ownerUid == user.uid) {
      // Can't chat with yourself.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot chat with yourself.')),
      );
      return;
    }
    // Open the chatbox immediately — same pattern the listing Chat
    // button uses. ChatScreen initializes the conversation
    // (idempotent) and streams messages; no need to await any
    // Firestore write before navigating.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerName: p.postedBy,
          peerEmail: contactEmail,
          peerUid: ownerUid,
        ),
      ),
    );
  }

  DateTime _toDt(dynamic v) =>
      v is Timestamp ? v.toDate() : DateTime.now();

  void _openEditor(BuildContext context, WantedPost? existing) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _WantedEditor(existing: existing)),
    );
  }
}

class _WantedCard extends StatelessWidget {
  final WantedPost post;
  final String ownerUid;
  final bool isMine;
  final VoidCallback onContact;
  final VoidCallback onEdit;
  const _WantedCard({
    required this.post,
    required this.ownerUid,
    required this.isMine,
    required this.onContact,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // The card itself is tappable for the owner: tapping their own post
    // opens the editor. For other users' posts the card body is not
    // tappable — the explicit "Contact Student" button is the call to
    // action so we don't accidentally open the editor for someone else.
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(name: post.postedBy, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.postedBy,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 12),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isMine)
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        onEdit();
                      } else if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete wanted post?'),
                            content: Text('Remove "${post.title}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          try {
                            await WantedService().delete(
                              uid: ownerUid,
                              id: post.id,
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not delete: $e')),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.description,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                InfoPill(
                  icon: Icons.school_outlined,
                  label: post.department.isEmpty ? '—' : post.department,
                ),
                InfoPill(
                  icon: Icons.calendar_today_rounded,
                  label:
                      '${post.postedAt.year}-${post.postedAt.month.toString().padLeft(2, '0')}-${post.postedAt.day.toString().padLeft(2, '0')}',
                ),
                if (isMine)
                  const StatusPill(
                    label: 'Your post',
                    tone: StatusTone.primary,
                    icon: Icons.person_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // For our own posts, show an "Edit" button (also tappable
            // anywhere on the card). For other students' posts, show
            // "Contact Student" so they can open a chat with the post
            // owner.
            Align(
              alignment: Alignment.centerRight,
              child: isMine
                  ? OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    )
                  : FilledButton.icon(
                      onPressed: onContact,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Contact Student'),
                    ),
            ),
          ],
        ),
      ),
    );
    if (!isMine) return card;
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}

class _WantedEditor extends StatefulWidget {
  final WantedPost? existing;
  const _WantedEditor({this.existing});

  @override
  State<_WantedEditor> createState() => _WantedEditorState();
}

class _WantedEditorState extends State<_WantedEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _dept;
  final _service = WantedService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _desc = TextEditingController(text: widget.existing?.description ?? '');
    _dept = TextEditingController(text: widget.existing?.department ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _dept.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_busy) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      // Read profile for display name and default department.
      final profileSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final profile = profileSnap.data() ?? const {};
      final name = (profile['name'] ?? '').toString();
      final defaultDept = (profile['department'] ?? '').toString();
      final email =
          (profile['email'] ?? user.email ?? '').toString();
      if (widget.existing == null) {
        await _service.create(
          title: _title.text.trim(),
          description: _desc.text.trim(),
          postedBy: name,
          postedById: user.uid,
          contactEmail: email,
          department:
              _dept.text.trim().isEmpty ? defaultDept : _dept.text.trim(),
        );
      } else {
        await _service.update(
          uid: user.uid,
          id: widget.existing!.id,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          department: _dept.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'New Wanted Post'
            : 'Edit Wanted Post'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dept,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 24),
              BusyButton(
                onPressed: _save,
                busy: _busy,
                label: widget.existing == null ? 'Post Request' : 'Save Changes',
                icon: Icons.send_rounded,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}