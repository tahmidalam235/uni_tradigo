import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/item.dart';

// ItemCard — a reusable card for any listing on Home, Search, My Listings, etc.
// Avoids duplicate card code on every screen.
// Keeping it stateless and accepting an `onTap` so each screen can route it.

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
        return Colors.blue.shade700;
      case 'Rent':
        return Colors.purple.shade700;
      case 'Exchange':
        return Colors.orange.shade700;
      case 'Donation':
        return Colors.green.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _categoryIcon() {
    switch (item.category) {
      case 'Books':
        return Icons.menu_book;
      case 'Electronics':
        return Icons.devices;
      case 'Calculator':
        return Icons.calculate;
      case 'Accessories':
        return Icons.lightbulb_outline;
      case 'Furniture':
        return Icons.chair;
      default:
        return Icons.shopping_bag;
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
      return Icon(
        _categoryIcon(),
        size: 36,
        color: Theme.of(context).colorScheme.primary,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.priceLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: item.price <= 0
                            ? Colors.green.shade700
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _metaChip(item.condition, Colors.grey.shade700),
                        _metaChip(item.tradeType, _tradeColor(context)),
                        _metaChip(item.category, Colors.indigo),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.verified,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
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
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    color: isWishlisted ? Colors.red : Colors.grey,
                  ),
                  onPressed: onWishlistToggle,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
