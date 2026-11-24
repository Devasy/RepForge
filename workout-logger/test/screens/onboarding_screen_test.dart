import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/onboarding_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_robot.dart';

void main() {
  testWidgets('First launch can continue without saving a profile', (WidgetTester tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'RepForge', packageName: 'repforge', version: '2.2.5',
      buildNumber: '76', buildSignature: '',
    );
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    var completed = false;
    await robot.pumpScreen(
      WelcomePage(onComplete: () => completed = true),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: workout,
    );

    robot.expectVisible(WelcomePage);
    await tester.tap(find.text('Continue without a profile'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(settings.userName, isNull);
    expect(settings.lastSeenVersion, isNotNull);
  });
}
