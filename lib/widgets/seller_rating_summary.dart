import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'rating_stars.dart';

/// SellerRatingSummary — the composite "average + count + distribution"
/// panel that sits on the item details page above the review list.
///
/// Two visual modes:
///   - default: big number on the left, five horizontal stacked bars on
///     the right (5★ at the top down to 1★ at the bottom), each bar
///     filled proportionally to the share of reviews at that star.
///   - loading: a subtle progress bar and muted copy ("Loading reviews…").
///   - empty (reviewCount == 0 and not loading): single-line "No reviews
///     yet" so the section never looks broken.
class SellerRatingSummary extends StatelessWidget {
  /// Average rating in the range 0..5.
  final double average;

  /// Total number of reviews with rating 1..5.
  final int reviewCount;

  /// Map of rating (1..5) -> count of reviews at that rating. Missing
  /// keys are treated as zero.
  final Map<int, int> distribution;

  /// When true, shows a progress strip instead of the numbers. The
  /// caller should pass `loading: true` while the first Firestore
  /// snapshot is still pending.
  final bool loading;

  const SellerRatingSummary({
    super.key,
    required this.average,
    required this.reviewCount,
    required this.distribution,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingState();
    if (reviewCount == 0) return const _EmptyState();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: big number + stars + count
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  average.toStringAsFixed(1),
                  style: AppTypography.displaySmall.copyWith(
                    fontSize: 28,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                RatingStars(
                  rating: average,
                  size: 16,
                  emptyColor: AppColors.outline,
                ),
                const SizedBox(height: 6),
                Text(
                  _reviewCountLabel(reviewCount),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: stacked distribution bars (5★ on top, 1★ at bottom)
          Expanded(
            flex: 6,
            child: _Distribution(distribution: distribution),
          ),
        ],
      ),
    );
  }

  static String _reviewCountLabel(int n) {
    if (n == 1) return '1 review';
    return '$n reviews';
  }
}

class _Distribution extends StatelessWidget {
  final Map<int, int> distribution;
  const _Distribution({required this.distribution});

  @override
  Widget build(BuildContext context) {
    // Largest bucket sets the bar's 100% width so even a single 5★ review
    // shows a visible 5★ bar without all the others collapsing to zero.
    final maxCount = distribution.values.fold<int>(
      0,
      (m, v) => v > m ? v : m,
    );
    // Stars are rendered from 5 down to 1 (top to bottom).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final star in [5, 4, 3, 2, 1])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _DistributionRow(
              star: star,
              count: distribution[star] ?? 0,
              maxCount: maxCount,
            ),
          ),
      ],
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final int star;
  final int count;
  final int maxCount;
  const _DistributionRow({
    required this.star,
    required this.count,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    // Fraction in [0..1]. When maxCount is zero (empty list — should not
    // happen because we early-return above) default to zero width.
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;
    return Row(
      children: [
        SizedBox(
          width: 12,
          child: Text(
            '$star',
            textAlign: TextAlign.right,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.star_rounded,
          size: 10,
          color: AppColors.warning,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: AppColors.outlineSoft,
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.warning.withValues(alpha: 0.85),
                          AppColors.warning,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 18,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading reviews…',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No reviews yet for this seller.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
