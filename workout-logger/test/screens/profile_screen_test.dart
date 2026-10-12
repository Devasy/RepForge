import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/profile_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/exercise_guide_cache.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_robot.dart';

class _ProfileGuideCache extends ExerciseGuideCache {
  int calls = 0;
  @override
  Future<void> downloadAll({
    void Function(int completed, int total)? onProgress,
  }) async {
    calls++;
    onProgress?.call(6, 6);
  }
}

void main() {
  testWidgets('Profile downloads all curated guides on request', (
    tester,
  ) async {
    final cache = _ProfileGuideCache();
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();
    final workout = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    await workout.init();
    await TestRobot(tester).pumpScreen(
      ProfileScreen(guideCache: cache),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: workout,
    );
    await tester.ensureVisible(find.text('Download all exercise guides'));
    await tester.tap(find.text('Download all exercise guides'));
    await tester.pumpAndSettle();
    expect(cache.calls, 1);
    expect(
      find.text('All exercise photo guides are available offline.'),
      findsOneWidget,
    );
  });

  testWidgets('Renders ProfileScreen with sections', (
    WidgetTester tester,
  ) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    await workout.init();

    await robot.pumpScreen(
      const ProfileScreen(),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: workout,
    );

    robot.expectVisible('Preferences');
    robot.expectVisible('Data Management');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    robot.expectVisible('About');
  });

  testWidgets('Toggles weight unit preference', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    await workout.init();

    await robot.pumpScreen(
      const ProfileScreen(),
      storage: storage,
      settingsProvider: settings,
      workoutProvider: workout,
    );

    await robot.tap('lbs');
    expect(settings.weightUnit, equals(WeightUnit.lbs));
  });
}
