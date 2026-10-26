// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/main.dart';
import 'package:repforge/screens/app_startup_screen.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RepForgeApp());

    // Verify that our app shows the loading screen
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'RepForge',
    );
    expect(find.byType(AppLoadingScreen), findsOneWidget);
    expect(find.text('Workout Logger'), findsNothing);
  });
}
