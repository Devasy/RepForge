import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/home_screen.dart';
import 'package:repforge/screens/routines_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders HomeScreen with navigation bar items', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(TestHarness.wrap(
      const HomeScreen(),
      storage: storage,
      workoutProvider: workout,
      settingsProvider: settings,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
  });

  testWidgets('Switches tabs when floating nav bar item is tapped', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(TestHarness.wrap(
      const HomeScreen(),
      storage: storage,
      workoutProvider: workout,
      settingsProvider: settings,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Tap Routines tab (Icons.layers_rounded)
    await tester.tap(find.byIcon(Icons.layers_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // RoutinesScreen should be displayed in IndexedStack
    expect(find.byType(RoutinesScreen), findsOneWidget);
  });
}
