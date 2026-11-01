import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// RatingStars — a horizontal row of star icons that visually represents
/// a numeric rating in the range [0..maxStars]. Supports fractional values
/// (e.g. 4.5) by rendering the trailing star as half-filled.
///
/// Pure presentation: no state, no Firestore reads. Used by the seller
/// summary on the item details screen and by each row in the review list.
class RatingStars extends StatelessWidget {
  /// Numeric rating. Values outside [0..maxStars] are clamped.
  final double rating;

  /// Total number of stars to render. Defaults to 5.
  final int maxStars;

  /// Star icon size in logical pixels. Defaults to 16.
  final double size;

  /// Color of the filled portion of the stars. Defaults to the warning
  /// color (orange) so it stands out on both white and tinted surfaces.
  final Color? color;

  /// Color of the empty (border) stars. Defaults to a muted neutral.
  final Color? emptyColor;

  const RatingStars({
    super.key,
    required this.rating,
    this.maxStars = 5,
    this.size = 16,
    this.color,
    this.emptyColor,
  });

  IconData _iconFor(int index) {
    // index is 0-based. A star is "full" if rating >= index+1, "half" if
    // rating >= index+0.5, otherwise empty.
    if (rating >= index + 1) return Icons.star_rounded;
    if (rating >= index + 0.5) return Icons.star_half_rounded;
    return Icons.star_border_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppColors.warning;
    final empty = emptyColor ?? AppColors.outline;
    // Clamp to a safe range so a misbehaving caller can never crash the
    // build pass with a RangeError.
    final clamped = rating.isFinite
        ? rating.clamp(0.0, maxStars.toDouble()).toDouble()
        : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < maxStars; i++)
          Padding(
            padding: EdgeInsets.only(right: i == maxStars - 1 ? 0 : 2),
            child: Icon(
              _iconFor(i),
              size: size,
              color: i < clamped + 0.5 ? fill : empty,
            ),
          ),
      ],
    );
  }
}
