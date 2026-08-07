import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/programs/programs_screen.dart';
import 'package:repforge/screens/programs/program_detail_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';

import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';
import 'test_utils/test_robot.dart';

void main() {
  late MockStorageService storage;
  late ProgramManager programManager;
  late WorkoutProvider workoutProvider;

  setUp(() async {
    storage = MockStorageService();
    programManager = ProgramManager(storage);
    workoutProvider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: programManager,
    );

    await workoutProvider.init();

    // Create a sample program in storage
    final program = TrainingProgram(
      id: 'prog_deep_1',
      name: 'Powerbuilding V1',
      description: 'Strength and hypertrophy',
      author: 'User',
      totalWeeks: 4,
      phases: [
        TrainingPhase(
          id: 'phase_1',
          name: 'Hypertrophy Phase',
          startWeek: 1,
          endWeek: 4,
        ),
      ],
      weeks: [
        ProgramWeek(
          weekNumber: 1,
          phaseId: 'phase_1',
          days: [
            ProgramDay(
              id: 'day_1',
              name: 'Push Day A',
              exercises: [
                ProgramExerciseSlot(
                  exerciseId: 'bench_press',
                  sets: 4,
                  minReps: 8,
                  maxReps: 10,
                  restSeconds: 90,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await programManager.saveProgram(program);
  });

  group('ProgramsScreen Deep Coverage Suite', () {
    testWidgets('Populated ProgramsScreen interactions: activate, view, and popups', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const ProgramsScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
      );

      robot.expectVisible(ProgramsScreen);
      robot.expectVisible('Powerbuilding V1');

      // Tap program card to open detail screen
      await robot.tap('Powerbuilding V1');
      robot.expectVisible(ProgramDetailScreen);

      // Pop detail screen back to ProgramsScreen
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Tap FABs
      final fabs = find.byType(FloatingActionButton);
      expect(fabs, findsWidgets);

      for (int i = 0; i < fabs.evaluate().length; i++) {
        await tester.tap(fabs.at(i));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });
  });
}
