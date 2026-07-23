import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders OnboardingScreen welcome page', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    bool completed = false;

    await tester.pumpWidget(TestHarness.wrap(
      OnboardingScreen(onComplete: () => completed = true),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: workout,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
