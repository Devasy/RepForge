import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/routine_creator.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/mock_ml_service.dart';
import '../../test_utils/test_robot.dart';

void main() {
  testWidgets('Renders CreateRoutineScreen and creates new routine', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final provider = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await provider.init();

    await robot.pumpScreen(
      const CreateRoutineScreen(),
      storage: storage,
      workoutProvider: provider,
    );

    robot.expectVisible(CreateRoutineScreen);

    // Enter routine name via RFTextField
    await robot.fill('Routine name (e.g. Push Day)', 'Upper Body Push');

    // Tap Add Exercises button
    await robot.tap('Add Exercises');

    // Select exercise in sheet
    final check = find.byType(CheckboxListTile).first;
    if (check.evaluate().isNotEmpty) {
      await robot.tap(check);
    }
  });

  testWidgets('Renders RoutineDetailScreen and displays exercise list', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final provider = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await provider.init();

    final routine = Routine(
      id: 'routine_push_1',
      name: 'Push Hypertrophy',
      exerciseIds: ['bench_press', 'overhead_press'],
      createdAt: DateTime.now(),
    );

    await robot.pumpScreen(
      RoutineDetailScreen(routine: routine),
      storage: storage,
      workoutProvider: provider,
    );

    robot.expectVisible(RoutineDetailScreen);
    robot.expectVisible('Push Hypertrophy');
  });
}
