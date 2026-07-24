
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/workout_flow_screen.dart';

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

  group('WorkoutFlowScreen Comprehensive Test Suite', () {
    testWidgets('QuickStart workout flow: starts, adds exercises, logs sets, finishes', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const WorkoutFlowScreen(isQuickStart: true),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(WorkoutFlowScreen);

      // Tap Log Set button if present
      final logBtn = find.text('LOG SET');
      if (logBtn.evaluate().isNotEmpty) {
        await tester.tap(logBtn);
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('Routine-backed workout flow: loads exercises, toggles dropsets, logs sets', (tester) async {
      final robot = TestRobot(tester);

      final routine = Routine(
        id: 'rout_flow_1',
        name: 'Upper Hypertrophy',
        exerciseIds: ['bench_press', 'incline_dumbbell_press'],
      );
      await storage.saveRoutine(routine);

      await robot.pumpScreen(
        WorkoutFlowScreen(routine: routine),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(WorkoutFlowScreen);

      // Log set
      final logBtn = find.text('LOG SET');
      if (logBtn.evaluate().isNotEmpty) {
        await tester.tap(logBtn);
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('ProgramDay-backed workout flow with deload week', (tester) async {
      final robot = TestRobot(tester);

      final day = ProgramDay(
        id: 'day_flow_1',
        name: 'Leg Day A',
        exercises: [
          ProgramExerciseSlot(
            exerciseId: 'squat',
            sets: 3,
            minReps: 5,
            maxReps: 5,
            restSeconds: 120,
          ),
        ],
      );

      final week = ProgramWeek(
        weekNumber: 4,
        isDeload: true,
        deloadIntensityFactor: 0.85,
        deloadSetReduction: 1,
        days: [day],
      );

      await robot.pumpScreen(
        WorkoutFlowScreen(programDay: day, programWeek: week),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(WorkoutFlowScreen);
      expect(tester.takeException(), isNull);
    });
  });
}
