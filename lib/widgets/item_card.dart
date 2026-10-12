import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import 'info_pill.dart';
import 'verified_badge.dart';

/// ItemCard — a reusable card for any listing on Home, Search, My
/// Listings, etc. Keeps the visual contract identical across screens.
class ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  final bool isWishlisted;
  final VoidCallback? onWishlistToggle;

  const ItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isWishlisted = false,
    this.onWishlistToggle,
  });

  // Trade type → color (kept inline so we don't introduce an extra file).
  Color _tradeColor(BuildContext context) {
    switch (item.tradeType) {
      case 'Sale':
        return AppColors.info;
      case 'Rent':
        return Colors.purple.shade700;
      case 'Exchange':
        return AppColors.warning;
      case 'Donation':
        return AppColors.success;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _categoryIcon() {
    switch (item.category) {
      case 'Books':
        return Icons.menu_book_rounded;
      case 'Electronics':
        return Icons.devices_rounded;
      case 'Calculator':
        return Icons.calculate_rounded;
      case 'Accessories':
        return Icons.lightbulb_outline;
      case 'Furniture':
        return Icons.chair_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  Widget _buildImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _errorIcon(),
        );
      } catch (e) {
        return _errorIcon();
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _errorIcon(),
    );
  }

  Widget _errorIcon() {
    return Builder(builder: (context) {
      return Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        alignment: Alignment.center,
        child: Icon(
          _categoryIcon(),
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image / icon placeholder. Shows the listing image if
              // imageUrl is set (supports both http URLs and Base64 data
              // URLs); otherwise falls back to a category icon.
              Container(
                width: 72,
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: item.imageUrl.isNotEmpty
                    ? _buildImage(item.imageUrl)
                    : Icon(
                        _categoryIcon(),
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 12),
              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.priceLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: item.price <= 0
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.condition.isNotEmpty)
                          InfoPill(
                            icon: Icons.star_outline_rounded,
                            label: item.condition,
                            color: AppColors.textSecondary,
                          ),
                        if (item.tradeType.isNotEmpty)
                          InfoPill(
                            icon: Icons.swap_horiz_rounded,
                            label: item.tradeType,
                            color: _tradeColor(context),
                          ),
                        if (item.category.isNotEmpty)
                          InfoPill(
                            icon: _categoryIcon(),
                            label: item.category,
                            color: AppColors.info,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const VerifiedBadge(size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onWishlistToggle != null)
                IconButton(
                  tooltip: isWishlisted
                      ? 'Remove from wishlist'
                      : 'Add to wishlist',
                  icon: Icon(
                    isWishlisted
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isWishlisted
                        ? AppColors.danger
                        : AppColors.textMuted,
                  ),
                  onPressed: onWishlistToggle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
