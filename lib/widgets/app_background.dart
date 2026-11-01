import 'package:flutter/material.dart';

/// AppBackground — the app-wide decorative background layer.
///
/// Renders the Uni-Tradigo campus artwork (`assets/images/campus_artwork.png`)
/// as a faint, transparent watercolour watermark behind a screen's content.
///
/// Design notes:
///   - The artwork is a monochrome pencil/watercolour sketch of the campus
///     on a near-white background. It is shown at a low opacity so only the
///     delicate line work and washes are visible — it reads as texture, not
///     as an illustration competing with the UI.
///   - The artwork is a wide panorama (600×404). It is laid out with
///     `BoxFit.contain` and anchored to the BOTTOM of the screen so the
///     whole campus reads as a horizon line beneath the content.
///     `BoxFit.cover` is deliberately NOT used here: on a tall phone it
///     scales the panorama up ~5.8× and crops it down to a narrow slice,
///     which magnifies the ink until it fights with the UI. `contain` keeps
///     the drawing whole and correctly scaled on every screen shape, and
///     because the artwork's own background is near-white it blends
///     invisibly into the page instead of leaving a hard edge.
///   - It sits in a `Stack` behind a `Positioned.fill`, so it stays
///     anchored to the screen while the page content scrolls over it.
///
/// Readability is preserved because every opaque surface in the app (cards,
/// inputs, app bars, nav bars) is drawn *above* this layer, and the
/// artwork contributes only a small fraction of the final pixel.
///
/// Usage:
/// ```dart
/// Scaffold(
///   appBar: AppBar(...),
///   body: const AppBackground(child: MyContent()),
/// )
/// ```
class AppBackground extends StatelessWidget {
  /// The screen content rendered above the watermark.
  final Widget child;

  /// Opacity of the artwork layer. Kept low by default so the watermark
  /// never competes with text or controls.
  final double artworkOpacity;

  const AppBackground({
    super.key,
    required this.child,
    this.artworkOpacity = 0.10,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- Artwork watermark ---------------------------------------------
        // Sits behind everything and does not intercept taps.
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: artworkOpacity,
              child: Image.asset(
                'assets/images/campus_artwork.png',
                fit: BoxFit.contain,
                // Anchor to the bottom so the campus silhouette reads as a
                // horizon line and never collides with the content above.
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),

        // --- Screen content -------------------------------------------------
        child,
      ],
    );
  }
}
