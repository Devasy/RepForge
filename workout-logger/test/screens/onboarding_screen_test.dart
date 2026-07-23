import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_robot.dart';

void main() {
  testWidgets('Renders WelcomePage welcome page', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await robot.pumpScreen(
      WelcomePage(onComplete: () {}),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: workout,
    );

    robot.expectVisible(WelcomePage);
    expect(find.text('Welcome to RepForge'), findsOneWidget);
  });
}
