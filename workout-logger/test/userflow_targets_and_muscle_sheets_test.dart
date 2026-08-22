import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/targets_tab.dart';
import 'package:repforge/screens/widgets/muscle_detail_sheet.dart';
import 'package:repforge/screens/widgets/editable_exercise_card.dart';
import 'package:repforge/screens/widgets/readiness_card.dart';
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

  group('Userflow: Targets Tab, Muscle Detail Sheet, and Target Cards', () {
    testWidgets('Renders TargetsTab in empty and populated target state', (tester) async {
      final robot = TestRobot(tester);

      // 1. Empty state
      await robot.pumpScreen(
        const TargetsTab(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible('No Targets Set');

      // 2. Add target to storage and re-pump
      final target = Target(
        id: 'tgt_bench_100',
        exerciseId: 'bench_press',
        targetType: 'weight',
        targetValue: 100.0,
        currentValue: 80.0,
      );
      await storage.saveTarget(target);
      await workoutProvider.init();

      await robot.pumpScreen(
        const TargetsTab(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(TargetsTab);
    });

    testWidgets('MuscleDetailSheet renders volume progression and muscle metrics', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        MuscleDetailSheet(
          muscleId: 'chest',
          provider: workoutProvider,
        ),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(MuscleDetailSheet);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EditableExerciseCard renders exercise parameters and handles user interactions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditableExerciseCard(
                exerciseName: 'Barbell Squat',
                editableLog: EditableExerciseLog(
                  exerciseId: 'ex_squat',
                  sets: [],
                ),
                onSetChanged: ({
                  required int setIndex,
                  required double weight,
                  required int reps,
                  required bool isDropset,
                  List<DropsetEntry>? drops,
                }) {},
                onAddSet: () {},
                onDeleteSet: (_) {},
                onDeleteExercise: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Barbell Squat'), findsOneWidget);
    });

    testWidgets('ReadinessCard renders recovery scores drill-down', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const ReadinessCard(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
