// Basic smoke test for Uni-Tradigo.
// We only test the splash screen widget directly, not the full app
// (because the full app requires Firebase initialization, which is not
// available in the unit test environment).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_tradigo/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows the logo artwork', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    // Pump a frame so the splash builds.
    await tester.pump();

    // The "Uni-Tradigo" branding is rendered as the logo image asset, not as
    // a text widget, so assert on the asset itself.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains(
              'uni_tradigo_logo',
            ),
      ),
      findsOneWidget,
    );

    // The splash also surfaces a clear loading state while auth resolves.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
