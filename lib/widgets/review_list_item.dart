import 'package:flutter/material.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'rating_stars.dart';
import 'verified_badge.dart';

/// ReviewListItem — a single review row used inside the "Seller Rating
/// & Reviews" section on the item details screen.
///
/// Layout:
///   - Header: tinted avatar (color by rating bucket) + reviewer name +
///     verified badge + relative time.
///   - Stars + numeric value (e.g. "5 / 5").
///   - Feedback paragraph that expands to a "Read more" button when it
///     overflows.
///
/// Tapping the "Read more" button toggles between a clamped 4-line view
/// and the full text. The state is local to the widget so each row
/// toggles independently.
class ReviewListItem extends StatefulWidget {
  final Review review;

  /// Optional callback for tapping the row (e.g. to open the transaction
  /// detail in a future iteration). Currently unused but kept in the API
  /// so callers don't have to change later.
  final VoidCallback? onTap;

  const ReviewListItem({
    super.key,
    required this.review,
    this.onTap,
  });

  @override
  State<ReviewListItem> createState() => _ReviewListItemState();
}

class _ReviewListItemState extends State<ReviewListItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final feedback = r.feedback.trim();
    final hasLongFeedback = feedback.length > 220;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(review: r),
            const SizedBox(height: 10),
            _StarsRow(rating: r.rating),
            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                feedback,
                maxLines: _expanded ? null : 4,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(height: 1.45),
              ),
              if (hasLongFeedback)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Show less' : 'Read more'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Review review;
  const _Header({required this.review});

  // Subtle per-rating avatar tint to help positive vs negative reviews
  // stand out at a glance without being noisy.
  Color _tintFor(int rating) {
    if (rating >= 4) return AppColors.success;
    if (rating == 3) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tintFor(review.rating);
    final displayName = review.reviewerName.trim().isEmpty
        ? 'Anonymous student'
        : review.reviewerName.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: tint.withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: Text(
            review.initials,
            style: AppTypography.titleSmall.copyWith(color: tint),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const VerifiedBadge(size: 12),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _relativeTime(review.createdAt),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Compact "x time ago" formatter. Mirrors the style used in
  // `messages_screen.dart` but stops at "1y" so the row stays one line.
  static String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    if (d.inDays < 30) return '${(d.inDays / 7).floor()}w ago';
    if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo ago';
    return '${(d.inDays / 365).floor()}y ago';
  }
}

class _StarsRow extends StatelessWidget {
  final int rating;
  const _StarsRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final clamped = rating.clamp(0, 5);
    return Row(
      children: [
        RatingStars(
          rating: clamped.toDouble(),
          size: 14,
          emptyColor: AppColors.outline,
        ),
        const SizedBox(width: 8),
        Text(
          '$clamped / 5',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
