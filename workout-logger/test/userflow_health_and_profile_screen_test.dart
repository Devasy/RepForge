import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/heart_rate_detail_screen.dart';
import 'package:repforge/screens/sleep_detail_screen.dart';
import 'package:repforge/screens/profile_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';

import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';
import 'test_utils/test_robot.dart';

void main() {
  late MockStorageService storage;
  late WorkoutProvider workoutProvider;
  late SettingsProvider settingsProvider;

  setUp(() async {
    storage = MockStorageService();
    workoutProvider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    settingsProvider = SettingsProvider(storage);

    await workoutProvider.init();
    await settingsProvider.init();
  });

  group('Userflow: Heart Rate Detail, Sleep Detail, and Profile Screens', () {
    testWidgets('HeartRateDetailScreen renders correctly with date anchor', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        HeartRateDetailScreen(initialDate: DateTime.now()),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(HeartRateDetailScreen);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SleepDetailScreen renders correctly with date anchor', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        SleepDetailScreen(initialDate: DateTime.now()),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(SleepDetailScreen);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileScreen renders settings options and user metrics', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const ProfileScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(ProfileScreen);
      expect(tester.takeException(), isNull);
    });
  });
}
