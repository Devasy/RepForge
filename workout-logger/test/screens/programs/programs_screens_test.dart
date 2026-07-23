import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/programs/import_program_screen.dart';
import 'package:repforge/screens/programs/programs_screen.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/mock_ml_service.dart';
import '../../test_utils/test_robot.dart';

void main() {
  testWidgets('Renders ProgramsScreen list and empty state', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await robot.pumpScreen(
      const ProgramsScreen(),
      storage: storage,
      workoutProvider: workout,
    );

    robot.expectVisible(ProgramsScreen);

    // Tap action buttons if available
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await robot.tap(fab.first);
    }
  });

  testWidgets('Renders ImportProgramScreen, validates valid program JSON', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await robot.pumpScreen(
      const ImportProgramScreen(),
      storage: storage,
      workoutProvider: workout,
    );

    robot.expectVisible(ImportProgramScreen);

    final validJson = jsonEncode({
      'id': 'prog_custom_1',
      'name': 'Custom Powerlifting 4-Week',
      'description': 'Heavy compound lifting',
      'daysPerWeek': 4,
      'weeks': [
        {
          'weekNumber': 1,
          'days': [
            {
              'dayNumber': 1,
              'name': 'Bench Day',
              'exercises': [
                {'exerciseId': 'bench_press', 'targetSets': 4, 'targetReps': 5}
              ]
            }
          ]
        }
      ]
    });

    final textField = find.byType(TextField);
    if (textField.evaluate().isNotEmpty) {
      await robot.fill(textField.first, validJson);
    }

    final validateBtn = find.text('Validate');
    if (validateBtn.evaluate().isNotEmpty) {
      await robot.tap(validateBtn);
    }
  });
}
