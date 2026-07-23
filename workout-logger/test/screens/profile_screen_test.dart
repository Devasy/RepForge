import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/profile_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders ProfileScreen with sections', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(TestHarness.wrap(
      const ProfileScreen(),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: workout,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Data Management'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('Toggles weight unit preference', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(TestHarness.wrap(
      const ProfileScreen(),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: workout,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // Tap lbs unit button
    final lbsBtn = find.text('lbs');
    await tester.tap(lbsBtn);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(settings.weightUnit, equals(WeightUnit.lbs));
  });
}
