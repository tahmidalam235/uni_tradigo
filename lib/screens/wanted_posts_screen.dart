import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../services/wanted_service.dart';
import '../services/chat_service.dart';
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
          final docs = snapshot.data ?? const <Map<String, dynamic>>[];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No wanted posts yet.\nTap "New" to ask for an item.',
                  textAlign: TextAlign.center,
                ),
              ),
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
              return _WantedCard(
                post: post,
                isMine: isMine,
                onContact: () => _contact(context, post, ownerUid),
                onEdit: () => _openEditor(context, post),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _contact(
      BuildContext context, WantedPost p, String? ownerUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (ownerUid == null || ownerUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading contact info…')),
      );
      return;
    }
    final myName = await _readMyName();
    final chat = ChatService();
    final convoId = await chat.ensureConversation(
      myUid: user.uid,
      myName: myName,
      otherUid: ownerUid,
      otherName: p.postedBy,
    );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerName: p.postedBy,
          peerEmail: '',
          peerUid: ownerUid,
          conversationId: convoId,
        ),
      ),
    );
  }

  Future<String> _readMyName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return (snap.data()?['name'] ?? '').toString();
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
  final bool isMine;
  final VoidCallback onContact;
  final VoidCallback onEdit;
  const _WantedCard({
    required this.post,
    required this.isMine,
    required this.onContact,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
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
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          try {
                            await WantedService().delete(post.id);
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
            const SizedBox(height: 6),
            Text(
              post.description,
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(post.postedBy, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.school, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(post.department, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${post.postedAt.year}-${post.postedAt.month.toString().padLeft(2, '0')}-${post.postedAt.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isMine ? null : onContact,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Contact Student'),
              ),
            ),
          ],
        ),
      ),
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
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dept,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}