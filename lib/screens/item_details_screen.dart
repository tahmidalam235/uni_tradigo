import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/app_state.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/info_pill.dart';
import '../widgets/section_header.dart';
import '../widgets/status_pill.dart';
import '../widgets/user_avatar.dart';
import '../widgets/verified_badge.dart';
import '../services/listing_service.dart';
import '../services/report_service.dart';
import '../services/wishlist_service.dart';
import 'chat_screen.dart';
import 'transaction_screen.dart';

/// ItemDetailsScreen — full item details, seller info, action buttons.
class ItemDetailsScreen extends StatelessWidget {
  final String itemId;

  const ItemDetailsScreen({super.key, required this.itemId});

  Widget _buildImage(BuildContext context, Item item) {
    final url = item.imageUrl;
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _errorIcon(context, item.category),
        );
      } catch (e) {
        return _errorIcon(context, item.category);
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _errorIcon(context, item.category),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _errorIcon(BuildContext context, String category) {
    return Center(
      child: Icon(
        _categoryIcon(category),
        size: 100,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return AnimatedBuilder(
      animation: appState,
      builder: (_, __) {
        final item = appState.itemById(itemId);
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Item')),
            body: const Center(child: Text('Item not found.')),
          );
        }
        final isWished = appState.isWishlisted(item.id);
        // Ownership check: when the current user IS the seller of this
        // listing, we hide the Chat and Buy buttons and show a single
        // "Update Status" button instead, so users cannot message or
        // purchase their own listings.
        final isOwner =
            currentUid.isNotEmpty && item.sellerId == currentUid;
        return Scaffold(
          appBar: AppBar(
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: isWished ? 'Remove from wishlist' : 'Add to wishlist',
                onPressed: () async => _toggleWishlist(context, appState, item.id),
                icon: Icon(
                  isWished ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isWished ? AppColors.danger : null,
                ),
              ),
              if (_canReport(context, item))
                IconButton(
                  tooltip: 'Report this listing',
                  onPressed: () => _openReportDialog(context, item),
                  icon: const Icon(Icons.flag_outlined),
                ),
            ],
          ),
          body: ListView(
            children: [
              // Hero image area — shows the Firestore image if available,
              // otherwise falls back to a category-icon placeholder.
              Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                ),
                child: item.imageUrl.isNotEmpty
                    ? _buildImage(context, item)
                    : Center(
                        child: Icon(
                          _categoryIcon(item.category),
                          size: 100,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTypography.headlineSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(
                          label: item.isAvailable ? 'Available' : 'Unavailable',
                          tone: item.isAvailable
                              ? StatusTone.success
                              : StatusTone.danger,
                          icon: item.isAvailable
                              ? Icons.check_circle_outline_rounded
                              : Icons.do_not_disturb_on_outlined,
                          fontSize: 11,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.priceLabel,
                      style: AppTypography.headlineSmall.copyWith(
                        color: item.price <= 0
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metaPill(
                          icon: Icons.verified_outlined,
                          label: item.condition,
                          tone: StatusTone.info,
                        ),
                        _metaPill(
                          icon: Icons.swap_horiz_rounded,
                          label: item.tradeType,
                          tone: StatusTone.primary,
                        ),
                        _metaPill(
                          icon: Icons.category_outlined,
                          label: item.category,
                          tone: StatusTone.neutral,
                        ),
                        _metaPill(
                          icon: Icons.place_outlined,
                          label: item.pickupLocation,
                          tone: StatusTone.neutral,
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.xxl),
                    const SectionHeader(title: 'Description'),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.description,
                      style: AppTypography.bodyMedium.copyWith(height: 1.4),
                    ),
                    const Divider(height: AppSpacing.xxl),
                    const SectionHeader(title: 'Seller'),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        UserAvatar(name: item.sellerName, radius: 24),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.sellerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.titleMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const VerifiedBadge(size: 14),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${item.sellerId}',
                                style: AppTypography.bodySmall,
                              ),
                              Text(
                                item.sellerEmail,
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InfoPill(
                      icon: Icons.schedule_rounded,
                      label: 'Posted ${_formatTime(item.postedAt)}',
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              // When the current user is the seller, show Wishlist + a
              // single Update Status button (Available/Unavailable) and
              // hide Chat + Buy so they cannot message or buy themselves.
              // For other users, keep the original Wishlist + Chat + Buy
              // row unchanged.
              child: isOwner
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _toggleWishlist(
                                context, appState, item.id),
                            icon: Icon(
                              isWished
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isWished ? AppColors.danger : null,
                            ),
                            label: Text(
                                isWished ? 'Wishlisted' : 'Wishlist'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: item.isAvailable
                                ? () => _setAvailability(
                                      context, appState, item, false,
                                    )
                                : () => _setAvailability(
                                      context, appState, item, true,
                                    ),
                            icon: Icon(
                              item.isAvailable
                                  ? Icons.archive_outlined
                                  : Icons.unarchive_outlined,
                            ),
                            label: Text(
                              item.isAvailable
                                  ? 'Mark Unavailable'
                                  : 'Mark Available',
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _toggleWishlist(
                                context, appState, item.id),
                            icon: Icon(
                              isWished
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isWished ? AppColors.danger : null,
                            ),
                            label: Text(
                                isWished ? 'Wishlisted' : 'Wishlist'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: item.sellerId.isEmpty
                                ? null
                                : () => _openChat(context, item),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: const Text('Chat'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TransactionScreen(item: item),
                                ),
                              );
                            },
                            icon:
                                const Icon(Icons.shopping_cart_checkout_rounded),
                            label: const Text('Buy'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleWishlist(
      BuildContext context, AppState appState, String itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final isWished = appState.isWishlisted(itemId);
    appState.toggleWishlistLocal(itemId);
    try {
      final svc = WishlistService();
      if (isWished) {
        await svc.remove(user.uid, itemId);
      } else {
        await svc.add(user.uid, itemId);
      }
    } catch (e) {
      appState.toggleWishlistLocal(itemId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update wishlist: $e')),
      );
    }
  }

  /// Toggles the listing's availability (Active <-> Archived) for the
  /// owner. Updates Firestore via [ListingService.setAvailability] and
  /// keeps the in-memory AppState cache in sync so the badge and the
  /// button label refresh immediately.
  Future<void> _setAvailability(
    BuildContext context,
    AppState appState,
    Item item,
    bool isAvailable,
  ) async {
    if (item.sellerId != FirebaseAuth.instance.currentUser?.uid) return;
    try {
      await ListingService().setAvailability(item.id, isAvailable);
      // Reflect the new state in the local cache so the badge/button
      // update on the next AnimatedBuilder tick.
      appState.replaceListings([
        for (final existing in appState.listings)
          if (existing.id == item.id)
            Item(
              id: existing.id,
              title: existing.title,
              description: existing.description,
              price: existing.price,
              category: existing.category,
              condition: existing.condition,
              tradeType: existing.tradeType,
              imageUrl: existing.imageUrl,
              sellerName: existing.sellerName,
              sellerEmail: existing.sellerEmail,
              sellerId: existing.sellerId,
              pickupLocation: existing.pickupLocation,
              isAvailable: isAvailable,
              postedAt: existing.postedAt,
            )
          else
            existing,
      ]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    }
  }

  Future<void> _openChat(BuildContext context, Item item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (item.sellerId.isEmpty || item.sellerId == user.uid) {
      // Can't chat with yourself.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot chat with yourself.')),
      );
      return;
    }
    // Open the chatbox immediately. The screen itself initializes the
    // conversation (idempotent) and streams messages — no need to
    // await any Firestore write before navigating.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerName: item.sellerName,
          peerEmail: item.sellerEmail,
          peerUid: item.sellerId,
        ),
      ),
    );
  }

  bool _canReport(BuildContext context, Item item) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    // You can only report listings that you don't own.
    return item.sellerId.isNotEmpty && item.sellerId != user.uid;
  }

  Future<void> _openReportDialog(BuildContext context, Item item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report listing'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Why is this listing inappropriate?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = (snap.data()?['name'] ?? '').toString();
      await ReportService().createReport(
        listingId: item.id,
        listingTitle: item.title,
        reason: reason,
        reporterId: user.uid,
        reporterName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $e')),
      );
    }
  }

  Widget _metaPill({
    required IconData icon,
    required String label,
    required StatusTone tone,
  }) {
    return StatusPill(
      label: label.isEmpty ? '—' : label,
      tone: tone,
      icon: icon,
      fontSize: 11,
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Books':
        return Icons.menu_book_rounded;
      case 'Electronics':
        return Icons.devices_rounded;
      case 'Calculator':
        return Icons.calculate_rounded;
      case 'Accessories':
        return Icons.lightbulb_outline_rounded;
      case 'Furniture':
        return Icons.chair_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  String _formatTime(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}