import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uni_tradigo/screens/splash_screen.dart';

/// Verifies the splash logo artwork is laid out fully inside its card and
/// is horizontally centred — i.e. the "U" mark, the "Uni-Tradigo" wordmark
/// and the tagline are all visible rather than clipped.
void main() {
  testWidgets('splash logo is fully visible and centred', (tester) async {
    // Match a real phone: 1080x2460 @ 3.0x => 360x820 logical pixels.
    tester.view.physicalSize = const Size(1080, 2460);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Let the entrance animations settle. The progress indicator animates
    // forever, so pump a fixed duration rather than pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    final logoFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.contains('uni_tradigo_logo'),
    );

    expect(logoFinder, findsOneWidget);

    final logoRect = tester.getRect(logoFinder);
    final screenWidth = tester.view.physicalSize.width /
        tester.view.devicePixelRatio;

    // The image must not overflow its parent card.
    final containerFinder = find.ancestor(
      of: logoFinder,
      matching: find.byType(Container),
    );
    final cardRect = tester.getRect(containerFinder.first);

    expect(
      logoRect.left,
      greaterThanOrEqualTo(cardRect.left),
      reason: 'logo must not be clipped on the left',
    );
    expect(
      logoRect.right,
      lessThanOrEqualTo(cardRect.right),
      reason: 'logo must not be clipped on the right',
    );
    expect(
      logoRect.top,
      greaterThanOrEqualTo(cardRect.top),
      reason: 'logo must not be clipped at the top',
    );
    expect(
      logoRect.bottom,
      lessThanOrEqualTo(cardRect.bottom),
      reason: 'logo must not be clipped at the bottom',
    );

    // The whole logo block should be centred on the screen.
    final cardCentre = cardRect.center.dx;
    expect(
      (cardCentre - screenWidth / 2).abs(),
      lessThan(2.0),
      reason: 'logo card must be horizontally centred',
    );

    // The logo should not be absurdly small or absurdly large.
    expect(logoRect.width, greaterThan(200));
    expect(logoRect.width, lessThanOrEqualTo(290));
  });
}
