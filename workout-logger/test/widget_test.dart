// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WorkoutLoggerApp());

    // Verify that our app shows the loading screen
    expect(find.text('Workout Logger'), findsOneWidget);
  });
}
