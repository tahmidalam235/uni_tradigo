import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import 'chat_screen.dart';

// MessagesScreen — list of conversations.

class MessagesScreen extends StatelessWidget {
  final bool embedded;
  const MessagesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = DummyData.conversations.isEmpty
        ? const Center(child: Text('No messages yet.'))
        : ListView.builder(
            itemCount: DummyData.conversations.length,
            itemBuilder: (_, i) {
              final c = DummyData.conversations[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      c.otherUserName[0].toUpperCase(),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(c.otherUserName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          color: Colors.green, size: 14),
                    ],
                  ),
                  subtitle: Text(c.lastMessage,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    _ago(c.lastTime),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          peerName: c.otherUserName,
                          peerEmail: c.otherUserEmail,
                          conversationId: c.id,
                        ),
                      ),
                    );
                  },
                ),
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
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}