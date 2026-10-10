// Basic smoke test for Uni-Tradigo.
import 'package:flutter_test/flutter_test.dart';

import 'package:uni_tradigo/main.dart';

void main() {
  testWidgets('Splash screen shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(const UniTradigoApp());
    // Pump a frame so the splash builds.
    await tester.pump();
    expect(find.text('Uni-Tradigo'), findsOneWidget);
  });
}
