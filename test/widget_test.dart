// Basic smoke test for Uni-Tradigo.
// We only test the splash screen widget directly, not the full app
// (because the full app requires Firebase initialization, which is not
// available in the unit test environment).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_tradigo/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    // Pump a frame so the splash builds.
    await tester.pump();
    expect(find.text('Uni-Tradigo'), findsOneWidget);
  });
}