import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/app_state.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_pill.dart';
import '../services/listing_service.dart';
import 'add_listing_screen.dart';

/// MyListingsScreen — listings posted by the currently signed-in user.
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
        icon: const Icon(Icons.add_rounded),
        label: const Text('New listing'),
      ),
      body: user == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Please log in',
              subtitle: 'You must be logged in to view your listings.',
            )
          : StreamBuilder<List<Item>>(
              stream: listingService.streamMyListings(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorState(
                    message:
                        'If you just added a Firestore index, wait a minute and try again.\nDetails: ${snapshot.error}',
                    onRetry: () => Navigator.of(context).pop(),
                  );
                }
                final items = snapshot.data ?? const <Item>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.post_add_rounded,
                    title: 'No listings yet',
                    subtitle:
                        'Tap "New listing" to post your first item for the campus.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    await Future<void>.delayed(
                        const Duration(milliseconds: 300));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.shopping_bag_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 30,
                          ),
                        )
                      : Icon(
                          Icons.shopping_bag_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.priceLabel,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: item.price <= 0
                              ? AppColors.success
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          StatusPill(
                            label: item.tradeType,
                            tone: StatusTone.info,
                          ),
                          StatusPill(
                            label: item.isAvailable ? 'Active' : 'Archived',
                            tone: item.isAvailable
                                ? StatusTone.success
                                : StatusTone.neutral,
                            icon: item.isAvailable
                                ? Icons.check_circle_outline_rounded
                                : Icons.archive_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 6),
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
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.danger,
                            ),
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
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
