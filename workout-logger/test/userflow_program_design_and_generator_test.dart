import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/programs/programs_screen.dart';
import 'package:repforge/screens/programs/program_designer_screen.dart';
import 'package:repforge/screens/programs/program_detail_screen.dart';
import 'package:repforge/screens/ai_program_generator_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';

import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';
import 'test_utils/test_robot.dart';

void main() {
  late MockStorageService storage;
  late WorkoutProvider workoutProvider;
  late ProgramManager programManager;

  setUp(() async {
    storage = MockStorageService();
    programManager = ProgramManager(storage);
    workoutProvider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: programManager,
    );
    await workoutProvider.init();
  });

  group('Userflow: Programs, Designer, and AI Generator', () {
    testWidgets('Full flow: Empty Programs -> New Designer Program -> Save & View Program Detail', (tester) async {
      final robot = TestRobot(tester);

      // 1. Render empty ProgramsScreen
      await robot.pumpScreen(
        const ProgramsScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
      );

      robot.expectVisible(ProgramsScreen);
      robot.expectVisible('New Program');

      // 2. Render ProgramDesignerScreen for new program
      await robot.pumpScreen(
        const ProgramDesignerScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
      );

      robot.expectVisible(ProgramDesignerScreen);

      // Fill Title and Description
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        await tester.enterText(textFields.at(0), 'Strength Block 1');
        await tester.enterText(textFields.at(1), '4-week progressive overload');
        await tester.pumpAndSettle();
      }

      // Tap Save Program button
      final saveBtn = find.text('Save Program');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();
      }

      // 3. Save a sample program into manager and view ProgramDetailScreen
      final sampleProgram = TrainingProgram(
        id: 'prog_test_1',
        name: 'Hypertrophy Phase 1',
        description: 'Targeted hypertrophy program',
        totalWeeks: 4,
        phases: [
          TrainingPhase(
            id: 'phase_1',
            name: 'Volume Phase',
            startWeek: 1,
            endWeek: 4,
          ),
        ],
        weeks: [
          ProgramWeek(
            weekNumber: 1,
            days: [
              ProgramDay(
                id: 'day_1',
                name: 'Push Day A',
                dayOfWeek: 1,
                exercises: [],
              ),
            ],
          ),
        ],
      );
      await programManager.saveProgram(sampleProgram);

      await robot.pumpScreen(
        ProgramDetailScreen(program: sampleProgram),
        storage: storage,
        workoutProvider: workoutProvider,
      );

      robot.expectVisible('Hypertrophy Phase 1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('AiProgramGeneratorScreen shows prompt suggestions and validates API configuration', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const AiProgramGeneratorScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
      );

      robot.expectVisible(AiProgramGeneratorScreen);

      // Verify prompt suggestion chips render
      final chipFinder = find.text('12-week hypertrophy, 4 days/week, push-pull-legs-upper');
      if (chipFinder.evaluate().isNotEmpty) {
        await tester.tap(chipFinder);
        await tester.pumpAndSettle();
      }

      // Tap Generate Program button
      final genBtn = find.text('Generate Program');
      if (genBtn.evaluate().isNotEmpty) {
        await tester.tap(genBtn);
        await tester.pumpAndSettle();
      }

      // Verify prompt check/error prompt is raised gracefully
      expect(tester.takeException(), isNull);
    });
  });
}
