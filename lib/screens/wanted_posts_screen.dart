import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import 'chat_screen.dart';

// WantedPostsScreen — shows wanted requests from other students.

class WantedPostsScreen extends StatelessWidget {
  const WantedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = DummyData.wantedPosts;
    return Scaffold(
      appBar: AppBar(title: const Text('Wanted Posts')),
      body: posts.isEmpty
          ? const Center(child: Text('No wanted posts.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: posts.length,
              itemBuilder: (_, i) {
                final p = posts[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.description,
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              p.postedBy,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.school, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              p.department,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.calendar_today,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${p.postedAt.year}-${p.postedAt.month.toString().padLeft(2, '0')}-${p.postedAt.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    peerName: p.postedBy,
                                    peerEmail: '${p.postedBy.toLowerCase()}@bup.edu.bd',
                                    conversationId: 'wanted_${p.id}',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Contact Student'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}