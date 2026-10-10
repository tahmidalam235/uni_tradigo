import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/app_state.dart';
import '../models/item.dart';
import '../services/listing_service.dart';
import 'add_listing_screen.dart';

// MyListingsScreen — listings posted by the currently signed-in user.
// Loads from Firestore filtered by the Firebase Auth UID.

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
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
      // If we don't yet have a logged-in user, show an empty state.
      body: uid.isEmpty
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
              stream: listingService.streamMyListings(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <Item>[];

                // Keep AppState in sync so deleting from the in-memory
                // copy works seamlessly for users reading from the same
                // appState cache.
                final appState = AppStateScope.of(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Merge Firestore "my listings" into the AppState cache
                  // (don't drop dummy data, just upsert by id).
                  final byId = <String, Item>{
                    for (final it in appState.listings) it.id: it,
                  };
                  for (final it in items) {
                    byId[it.id] = it;
                  }
                  appState.replaceListings(byId.values.toList());
                });

                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'You have not posted anything yet.\nTap "New" to post a listing.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
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
                                        errorBuilder: (_, __, ___) => CircleAvatar(
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
                                        builder: (_) => AddListingScreen(
                                            editItem: item),
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
                                        SnackBar(
                                          content: Text(
                                            'Could not update: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    item.isAvailable
                                        ? Icons.archive_outlined
                                        : Icons.unarchive_outlined,
                                  ),
                                  label: Text(item.isAvailable ? 'Archive' : 'Activate'),
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
                                                await listingService
                                                    .deleteListing(item.id);
                                                appState.deleteListing(item.id);
                                                if (ctx.mounted) Navigator.pop(ctx);
                                              } catch (e) {
                                                if (ctx.mounted) Navigator.pop(ctx);
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Could not delete: $e',
                                                    ),
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
                  },
                );
              },
            ),
    );
  }
}
