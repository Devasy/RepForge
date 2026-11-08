import 'coach_live_eval_test.dart' as evaluation;
import 'package:repforge/services/ai/orchestration/repforge_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/programs/programs_screen.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';
import 'test_utils/test_harness.dart';

void main() {
  test('read-only evaluator rejects every mutating coach tool', () {
    final storage = MockStorageService();
    final provider = WorkoutProvider(
      storage,
      programManager: ProgramManager(storage),
    );
    final service = CoachToolService(
      workoutProvider: provider,
      prManager: PRManager(storage),
    );
    final writes = [
      for (final tool in service.buildTools())
        for (final declaration
            in tool.functionDeclarations ?? <FunctionDeclaration>[])
          if (RepForgeTool.writes.contains(declaration.name)) declaration,
    ];
    expect(
      writes.map((d) => d.name),
      containsAll(['create_training_program', 'follow_training_program']),
    );
    for (final declaration in writes) {
      expect(
        () => evaluation.ObservedReadTool(
          service,
          declaration,
          (_) async => <String, Object?>{},
        ),
        throwsArgumentError,
      );
    }
    provider.dispose();
  });
  test(
    'unreadable Vertex key does not prevent other settings loading',
    () async {
      final storage = MockStorageService();
      await storage.saveSetting('geminiBackend', 'vertexExpress');
      await storage.saveSetting('allowModelFallbacks', 'true');
      final settings = SettingsProvider(
        storage,
        readVertexKey: () async => throw StateError('Keystore unavailable'),
      );
      await settings.init();
      expect(settings.activeAiApiKey, isEmpty);
      expect(settings.allowModelFallbacks, isTrue);
      expect(settings.geminiModel, 'gemini-3.8-flash');
    },
  );
  test(
    'empty and mixed muscle group arrays retain useful default coverage',
    () async {
      final storage = MockStorageService();
      final wp = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await wp.init();
      final tools = CoachToolService(
        workoutProvider: wp,
        prManager: PRManager(storage),
      );
      final empty = await tools.handleCall(
        FunctionCall('get_progress_overview', {
          'days': 14,
          'muscle_groups': [],
        }),
      );
      expect(empty['coverage']! as List, hasLength(10));
      final mixed = await tools.handleCall(
        FunctionCall('get_progress_overview', {
          'days': 14,
          'muscle_groups': [null, 7, '  Chest ', ''],
        }),
      );
      expect(mixed['coverage']! as List, hasLength(1));
      expect((mixed['coverage']! as List).single['muscle_group'], 'Chest');
    },
  );
  test(
    'logged exercise count is not capped at 500 or multiplied by repeated logs',
    () async {
      final storage = MockStorageService();
      for (var i = 0; i < 501; i++) {
        storage.addMockSession(
          WorkoutSession(
            id: 's$i',
            date: DateTime.now().subtract(Duration(minutes: i + 1)),
            duration: 10,
            exercises: [
              for (var log = 0; log < 2; log++)
                ExerciseLog(
                  exerciseId: 'bench_press',
                  sets: [WorkoutSet(weight: 40, reps: 8)],
                ),
            ],
          ),
        );
      }
      final wp = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await wp.init();
      final tools = CoachToolService(
        workoutProvider: wp,
        prManager: PRManager(storage),
      );
      final data = await tools.handleCall(
        FunctionCall('get_logged_exercises', {'days': 14}),
      );
      final bench = (data['exercises']! as List).firstWhere(
        (e) => e['exercise_id'] == 'bench_press',
      );
      expect(bench['session_count'], 501);
    },
  );
  testWidgets(
    'removing exercises from a completed day keeps progress numerator and denominator consistent',
    (tester) async {
      final storage = MockStorageService();
      final plan = TrainingProgram(
        id: 'p',
        name: 'Edited plan',
        totalWeeks: 1,
        phases: [],
        weeks: [
          ProgramWeek(
            weekNumber: 1,
            days: [ProgramDay(id: 'day', name: 'Now empty', exercises: [])],
          ),
        ],
      );
      await storage.saveTrainingProgram(plan);
      storage.addMockSession(
        WorkoutSession(
          id: 's',
          date: DateTime.now(),
          duration: 10,
          programId: 'p',
          programDayId: 'day',
          programWeekNumber: 1,
          exercises: [
            ExerciseLog(
              exerciseId: 'bench_press',
              sets: [WorkoutSet(weight: 40, reps: 8)],
            ),
          ],
        ),
      );
      final wp = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await wp.init();
      await wp.programManager.followProgram('p');
      await tester.pumpWidget(
        TestHarness.wrap(
          const ProgramsScreen(),
          storage: storage,
          workoutProvider: wp,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 of 0 workouts completed'), findsOneWidget);
    },
  );
}
