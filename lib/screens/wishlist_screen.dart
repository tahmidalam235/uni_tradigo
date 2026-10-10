import 'package:flutter/material.dart';
import '../data/app_state.dart';
import 'item_details_screen.dart';

// WishlistScreen — local list of items the user has saved.

class WishlistScreen extends StatelessWidget {
  final bool embedded;
  const WishlistScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final body = AnimatedBuilder(
      animation: appState,
      builder: (_, __) {
        final items = appState.wishlistItems;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Your wishlist is empty.\nTap the heart on a listing to save it here.',
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
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.shopping_bag,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(item.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(item.priceLabel),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => appState.toggleWishlist(item.id),
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

    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: body,
    );
  }
}