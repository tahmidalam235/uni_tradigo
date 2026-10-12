import 'package:flutter/material.dart';

/// AppColors — central palette for the Uni-Tradigo marketplace.
///
/// All screens read colors from here (or via `Theme.of(context)` which
/// is seeded from these tokens) so the visual identity is consistent
/// across the app and easy to tweak in one place.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1B5E96);
  static const Color primaryContainer = Color(0xFFD7E5F4);
  static const Color primaryDark = Color(0xFF103E66);

  static const Color secondary = Color(0xFF2E7D32);
  static const Color secondaryContainer = Color(0xFFDCEDC8);

  static const Color tertiary = Color(0xFF26A69A);

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color successContainer = Color(0xFFE6F4EA);
  static const Color warning = Color(0xFFED6C02);
  static const Color warningContainer = Color(0xFFFFF1E0);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerContainer = Color(0xFFFDECEC);
  static const Color info = Color(0xFF0277BD);
  static const Color infoContainer = Color(0xFFE3F4FB);

  // Neutrals
  static const Color surface = Color(0xFFFAFBFD);
  static const Color surfaceMuted = Color(0xFFF1F4F8);
  static const Color surfaceContainer = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFEFF4FA);
  static const Color outline = Color(0xFFD7DEE6);
  static const Color outlineSoft = Color(0xFFE6EAF0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF1B5E96), Color(0xFF2E7D32)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF1B5E96), Color(0xFF2E7D32), Color(0xFF26A69A)],
    stops: [0.0, 0.6, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFFAFBFD), Color(0xFFEFF4FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1B5E96), Color(0xFF26A69A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}
