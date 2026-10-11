import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/app_state.dart';
import '../models/item.dart';
import 'item_details_screen.dart';
import '../services/listing_service.dart';
import '../services/wishlist_service.dart';

/// WishlistScreen — listings the current user has saved.
///
/// Loads the user's wishlist ids from `users/{uid}/wishlist`, then
/// resolves each id into a full `Item` (either from the in-memory
/// AppState cache or, if not cached yet, directly from Firestore) so
/// the page works correctly even if the Home tab has never been
/// visited.
class WishlistScreen extends StatefulWidget {
  final bool embedded;
  const WishlistScreen({super.key, this.embedded = false});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final WishlistService _wishlistService = WishlistService();
  final ListingService _listingService = ListingService();

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final body = AnimatedBuilder(
      animation: appState,
      builder: (_, _) {
        return StreamBuilder<Set<String>>(
          stream: uid.isEmpty
              ? const Stream<Set<String>>.empty()
              : _wishlistService.streamWishlistIds(uid),
          builder: (context, snapshot) {
            // Keep AppState in sync with the Firestore truth.
            final ids = snapshot.data ?? <String>{};
            if (snapshot.hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                appState.setWishlist(ids);
              });
            }

            // 1) Not logged in.
            if (uid.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Please log in to view your wishlist.'),
                ),
              );
            }

            // 2) Error.
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
                        'Could not load your wishlist.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
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

            // 3) Still waiting for the very first event.
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // 4) No items saved.
            if (ids.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    "You haven't added anything to your wishlist yet.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // 5) Resolve ids → Item. Prefer the in-memory cache (kept in
            //    sync by HomeScreen); fall back to a direct Firestore
            //    fetch so the screen works even if Home was never opened.
            final items = <Item>[];
            final missing = <String>[];
            for (final id in ids) {
              final cached = appState.itemById(id);
              if (cached != null) {
                items.add(cached);
              } else {
                missing.add(id);
              }
            }
            return FutureBuilder<List<Item>>(
              future: missing.isEmpty
                  ? Future<List<Item>>.value(const <Item>[])
                  : _fetchListings(missing),
              builder: (context, fbSnapshot) {
                if (missing.isNotEmpty && fbSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (missing.isNotEmpty && fbSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Could not load listing details: '
                        '${fbSnapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final fetched = fbSnapshot.data ?? const <Item>[];
                items.addAll(fetched);

                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "You haven't added anything to your wishlist yet.",
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
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          child: Icon(
                            Icons.shopping_bag,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(item.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.priceLabel),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () async {
                            try {
                              await _wishlistService.remove(uid, item.id);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Could not remove: $e')),
                              );
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ItemDetailsScreen(itemId: item.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: body,
    );
  }

  // Fetch listings by id in parallel; skip ids that no longer exist.
  Future<List<Item>> _fetchListings(List<String> ids) async {
    final results = await Future.wait(
      ids.map((id) => _listingService.fetchListingById(id)),
    );
    return results.whereType<Item>().toList(growable: false);
  }
}
