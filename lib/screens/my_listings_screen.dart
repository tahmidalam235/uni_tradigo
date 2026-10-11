import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/app_state.dart';
import '../models/item.dart';
import '../services/listing_service.dart';
import 'add_listing_screen.dart';

// MyListingsScreen — listings posted by the currently signed-in user.
// Loads from Firestore filtered by the Firebase Auth UID.
//
// Important: the Firestore query
//   listings.where('sellerId', isEqualTo: <uid>).orderBy('createdAt', descending: true)
// requires a composite index on (sellerId ASC, createdAt DESC). The
// index is declared in firestore.indexes.json. Without it Firestore
// returns an index-required error and the screen will appear empty.

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final listingService = ListingService();

    return Scaffold(
      appBar: AppBar(title: const Text('My Listings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddListingScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: user == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'You must be logged in to view your listings.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : StreamBuilder<List<Item>>(
              stream: listingService.streamMyListings(user.uid),
              builder: (context, snapshot) {
                // 1) Loading: show a spinner on the very first build only.
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 2) Error: show a friendly message + retry hint.
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Could not load your listings.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'If you just added a Firestore index, '
                            'wait a minute and try again.\n'
                            'Details: ${snapshot.error}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 3) Loaded: items from Firestore.
                final items = snapshot.data ?? const <Item>[];

                // 4) Empty: only show the empty state when we are
                //    confident the query is done and really returned 0.
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'You have not posted anything yet.\n'
                        'Tap "New" to post a listing.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // 5) Show the list.
                return RefreshIndicator(
                  onRefresh: () async {
                    // Firestore streams auto-refresh; this is just a
                    // visual cue that pulling down will re-query.
                    await Future<void>.delayed(
                        const Duration(milliseconds: 300));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return _MyListingCard(
                        item: item,
                        listingService: listingService,
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  final Item item;
  final ListingService listingService;
  const _MyListingCard({required this.item, required this.listingService});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: item.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Icon(
                            Icons.shopping_bag,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      child: Icon(Icons.shopping_bag,
                          color: Theme.of(context).colorScheme.primary),
                    ),
              title: Text(item.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${item.priceLabel} • ${item.tradeType}\n'
                'Status: ${item.isAvailable ? "Active" : "Archived"}',
              ),
              isThreeLine: true,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddListingScreen(editItem: item),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await listingService.setAvailability(
                        item.id,
                        !item.isAvailable,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not update: $e')),
                      );
                    }
                  },
                  icon: Icon(
                    item.isAvailable
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                  ),
                  label: Text(
                      item.isAvailable ? 'Archive' : 'Activate'),
                ),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete listing?'),
                        content: Text(
                            'Remove "${item.title}" from your listings?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                await listingService.deleteListing(item.id);
                                appState.deleteListing(item.id);
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not delete: $e'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  label: const Text('Delete',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}