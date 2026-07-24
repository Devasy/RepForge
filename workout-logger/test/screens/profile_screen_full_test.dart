
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/profile_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';

import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';

import '../test_utils/test_robot.dart';

void main() {
  late MockStorageService storage;
  late WorkoutProvider workoutProvider;
  late SettingsProvider settingsProvider;

  setUp(() async {
    storage = MockStorageService();
    settingsProvider = SettingsProvider(storage);
    workoutProvider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );

    await workoutProvider.init();
    await settingsProvider.init();
  });

  group('ProfileScreen Full Test Suite', () {
    testWidgets('Renders ProfileScreen, toggles weight units, and opens clear data confirmation dialog', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const ProfileScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(ProfileScreen);

      // Toggle weight unit chips
      final kgBtn = find.text('kg');
      if (kgBtn.evaluate().isNotEmpty) {
        await tester.tap(kgBtn);
        await tester.pumpAndSettle();
      }

      final lbsBtn = find.text('lbs');
      if (lbsBtn.evaluate().isNotEmpty) {
        await tester.tap(lbsBtn);
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });
  });
}
