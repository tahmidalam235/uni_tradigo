import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Tone drives the pill's color pair. Each tone is a foreground +
/// background that work together for legibility.
enum StatusTone {
  primary,
  success,
  warning,
  danger,
  info,
  neutral,
}

/// StatusPill — a small colored pill used everywhere the app needs to
/// show a status (Pending, Confirmed, Available, Archived, etc).
///
/// Visual contract: rounded pill (radius 999) with a 4-px horizontal
/// padding inside, 2-px vertical padding, and a 1-px border in the same
/// hue at 12% opacity. Optional leading icon.
class StatusPill extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;
  final double fontSize;

  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.fontSize = 11,
  });

  ({Color bg, Color fg, Color border}) _palette(BuildContext context) {
    switch (tone) {
      case StatusTone.primary:
        final c = Theme.of(context).colorScheme.primary;
        return (
          bg: c.withValues(alpha: 0.10),
          fg: c,
          border: c.withValues(alpha: 0.18),
        );
      case StatusTone.success:
        return (
          bg: AppColors.successContainer,
          fg: AppColors.success,
          border: AppColors.success.withValues(alpha: 0.18),
        );
      case StatusTone.warning:
        return (
          bg: AppColors.warningContainer,
          fg: AppColors.warning,
          border: AppColors.warning.withValues(alpha: 0.18),
        );
      case StatusTone.danger:
        return (
          bg: AppColors.dangerContainer,
          fg: AppColors.danger,
          border: AppColors.danger.withValues(alpha: 0.18),
        );
      case StatusTone.info:
        return (
          bg: AppColors.infoContainer,
          fg: AppColors.info,
          border: AppColors.info.withValues(alpha: 0.18),
        );
      case StatusTone.neutral:
        return (
          bg: AppColors.surfaceMuted,
          fg: AppColors.textSecondary,
          border: AppColors.outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: p.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: p.fg,
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
