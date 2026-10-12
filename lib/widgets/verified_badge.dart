import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// VerifiedBadge — the small check icon shown next to a verified
/// student's name across the app (chat header, message list, item
/// details seller row, etc).
class VerifiedBadge extends StatelessWidget {
  final double size;
  final Color? color;
  final String? tooltip;

  const VerifiedBadge({
    super.key,
    this.size = 14,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.verified_rounded,
      size: size,
      color: color ?? AppColors.success,
    );
    if (tooltip == null) return icon;
    return Tooltip(message: tooltip!, child: icon);
  }
}
