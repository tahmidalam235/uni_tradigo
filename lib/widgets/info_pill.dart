import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// InfoPill — a small rounded chip that pairs an icon with a label.
/// Used in item card meta rows, item details, wanted posts, etc.
///
/// The visual contract is intentionally minimal: an icon (16 px), a
/// 4-px gap, a label (12-px / w600), all on a tinted surface.
class InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final double iconSize;
  final double fontSize;

  const InfoPill({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.iconSize = 14,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: tint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
