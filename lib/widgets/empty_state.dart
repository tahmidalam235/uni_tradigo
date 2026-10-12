import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// EmptyState — a centered illustration-style empty state used on
/// listings, wishlist, messages, wanted posts, etc.
///
/// Renders an icon inside a soft tinted disc, a title, an optional
/// subtitle, and an optional call-to-action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  /// Optional accent color for the icon disc. Defaults to the theme
  /// primary color.
  final Color? accent;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: tint),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Small badge used for a soft background behind a placeholder.
class _SoftDisc extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SoftDisc({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }
}

// Use the private widget above to avoid an "unused" lint and keep the
// file self-contained; we re-export through a public function for any
// future re-use.
class SoftDiscAvatar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const SoftDiscAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
  });
  @override
  Widget build(BuildContext context) {
    return _SoftDisc(icon: icon, color: color);
  }
}

/// Quick helper for showing a themed error state.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      subtitle: message,
      accent: AppColors.danger,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
    );
  }
}
