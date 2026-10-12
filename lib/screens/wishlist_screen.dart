import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/app_state.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_pill.dart';
import '../widgets/verified_badge.dart';
import 'item_details_screen.dart';
import '../services/listing_service.dart';
import '../services/wishlist_service.dart';

/// WishlistScreen — listings the current user has saved.
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
            final ids = snapshot.data ?? <String>{};
            if (snapshot.hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                appState.setWishlist(ids);
              });
            }

            if (uid.isEmpty) {
              return const EmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Please log in',
                subtitle: 'Sign in to view your wishlist.',
              );
            }

            if (snapshot.hasError) {
              return ErrorState(
                message: 'Details: ${snapshot.error}',
                onRetry: () => setState(() {}),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (ids.isEmpty) {
              return const EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Your wishlist is empty',
                subtitle:
                    'Save items you like by tapping the heart on any listing.',
              );
            }

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
                if (missing.isNotEmpty &&
                    fbSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (missing.isNotEmpty && fbSnapshot.hasError) {
                  return ErrorState(
                    message:
                        'Could not load listing details: ${fbSnapshot.error}',
                    onRetry: () => setState(() {}),
                  );
                }
                final fetched = fbSnapshot.data ?? const <Item>[];
                items.addAll(fetched);

                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Your wishlist is empty',
                    subtitle:
                        'Save items you like by tapping the heart on any listing.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return _WishlistCard(
                      item: item,
                      onOpen: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ItemDetailsScreen(itemId: item.id),
                          ),
                        );
                      },
                      onRemove: () async {
                        try {
                          await _wishlistService.remove(uid, item.id);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not remove: $e')),
                          );
                        }
                      },
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

  Future<List<Item>> _fetchListings(List<String> ids) async {
    final results = await Future.wait(
      ids.map((id) => _listingService.fetchListingById(id)),
    );
    return results.whereType<Item>().toList(growable: false);
  }
}

class _WishlistCard extends StatelessWidget {
  final Item item;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  const _WishlistCard({
    required this.item,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
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
                    Row(
                      children: [
                        const VerifiedBadge(size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (item.isAvailable)
                    const InfoPill(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Available',
                      color: AppColors.success,
                    )
                  else
                    const InfoPill(
                      icon: Icons.do_not_disturb_on_outlined,
                      label: 'Unavailable',
                      color: AppColors.danger,
                    ),
                  const SizedBox(height: 8),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.heart_broken_rounded),
                    color: AppColors.danger,
                    onPressed: onRemove,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
