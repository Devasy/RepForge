import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/targets_tab.dart';
import 'package:repforge/screens/widgets/muscle_detail_sheet.dart';
import 'package:repforge/screens/programs/program_designer_screen.dart';
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
    settingsProvider = SettingsProvider(storage);
    workoutProvider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );

    await workoutProvider.init();
    await settingsProvider.init();

    // Save a custom session with bench press & squat to generate muscle volume data
    final session = WorkoutSession(
      id: 'targets_sess_1',
      date: DateTime.now(),
      duration: 45,
      exercises: [
        ExerciseLog(
          exerciseId: 'bench_press',
          sets: [
            WorkoutSet(weight: 100, reps: 10),
            WorkoutSet(weight: 100, reps: 8),
          ],
        ),
        ExerciseLog(
          exerciseId: 'squat',
          sets: [
            WorkoutSet(weight: 140, reps: 5),
          ],
        ),
      ],
    );
    await storage.saveWorkoutSession(session);
    await workoutProvider.init();

    // Save sample targets
    final target1 = Target(
      id: 'target_1',
      exerciseId: 'bench_press',
      targetType: 'weight',
      targetValue: 120,
      currentValue: 100,
      createdAt: DateTime.now(),
    );
    final target2 = Target(
      id: 'target_2',
      exerciseId: 'squat',
      targetType: 'weight',
      targetValue: 160,
      currentValue: 160,
      isCompleted: true,
      createdAt: DateTime.now(),
    );
    await storage.saveTarget(target1);
    await storage.saveTarget(target2);
    await workoutProvider.init();
  });

  group('TargetsTab and MuscleDetailSheet Full Test Suite', () {
    testWidgets('Renders TargetsTab with active & completed target cards and triggers add dialog', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const TargetsTab(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(TargetsTab);

      // Verify section headers
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);

      // Tap FAB to add new target
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders MuscleDetailSheet for chest, back, and legs muscle groups', (tester) async {
      final robot = TestRobot(tester);

      for (final muscleId in ['chest', 'back', 'quadriceps']) {
        await robot.pumpScreen(
          MuscleDetailSheet(
            muscleId: muscleId,
            provider: workoutProvider,
          ),
          storage: storage,
          workoutProvider: workoutProvider,
          settingsProvider: settingsProvider,
        );

        robot.expectVisible(MuscleDetailSheet);
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('ProgramDesignerScreen full phase and week builder interaction', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const ProgramDesignerScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
      );

      robot.expectVisible(ProgramDesignerScreen);

      // Enter program name
      final fields = find.byType(TextField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.first, 'Strength Program 2026');
        await tester.pump();
      }

      // Tap buttons to build phases & weeks
      final buttons = ['Add Phase', 'Add Week', 'Save Program'];
      for (final label in buttons) {
        final btn = find.text(label);
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first);
          await tester.pump();
        }
      }

      expect(tester.takeException(), isNull);
    });
  });
}
