import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

void main() {
  test(
    'overview counts every session once and keeps chronological endpoints',
    () async {
      final storage = MockStorageService();
      final now = DateTime.now();
      for (var i = 0; i < 501; i++) {
        storage.addMockSession(
          WorkoutSession(
            id: 'indexed-$i',
            date: now.subtract(Duration(hours: i)),
            duration: 30,
            exercises: [
              ExerciseLog(
                exerciseId: 'bench_press',
                sets: [WorkoutSet(weight: i.toDouble(), reps: 8)],
              ),
              ExerciseLog(
                exerciseId: 'bench_press',
                sets: [WorkoutSet(weight: 1, reps: 8)],
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
      addTearDown(wp.dispose);
      final tools = CoachToolService(
        workoutProvider: wp,
        prManager: PRManager(storage),
      );
      final result = await tools.handleCall(
        FunctionCall('get_progress_overview', {
          'days': 30,
          'muscle_groups': ['Chest', 'Triceps'],
        }),
      );
      final chest = (result['coverage'] as List).first as Map;
      final lift = (chest['exercises'] as List).single as Map;
      expect(lift['session_count'], 501);
      expect(
        (lift['earliest_session_in_window'] as Map)['sets'][0]['weight'],
        500,
      );
      expect((lift['latest_session_in_window'] as Map)['sets'][0]['weight'], 0);
    },
  );

  test(
    'complex six-month analysis retains baseline, incline work and coverage gaps',
    () async {
      final storage = MockStorageService();
      final now = DateTime.now();
      // More than 40 sessions: the baseline must survive a small recent-history cap.
      for (var i = 0; i < 50; i++) {
        storage.addMockSession(
          WorkoutSession(
            id: 's$i',
            date: now.subtract(Duration(days: 180 - i * 3)),
            duration: 30,
            exercises: [
              ExerciseLog(
                exerciseId: 'incline_bench_press',
                sets: [WorkoutSet(weight: 40 + i.toDouble(), reps: 8)],
              ),
              ExerciseLog(
                exerciseId: 'bench_press',
                sets: [WorkoutSet(weight: 60, reps: 8)],
              ),
            ],
          ),
        );
      }
      storage.addMockCustomExercise(
        Exercise(
          id: 'overlap',
          name: 'Overlap Press',
          isCustom: true,
          category: 'compound',
          muscleActivations: [
            MuscleActivation(muscleGroupId: 'chest', activationPercentage: 50),
            MuscleActivation(
              muscleGroupId: 'upper_chest',
              activationPercentage: 50,
            ),
          ],
        ),
      );
      storage.addMockSession(
        WorkoutSession(
          id: 'overlap-session',
          date: now.subtract(const Duration(days: 100)),
          duration: 10,
          exercises: [
            ExerciseLog(
              exerciseId: 'overlap',
              sets: [WorkoutSet(weight: 10, reps: 10)],
            ),
          ],
        ),
      );
      final wp = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await wp.init();
      final pr = PRManager(storage);
      await pr.backfillFromSessions(wp.sessions);
      final tools = CoachToolService(workoutProvider: wp, prManager: pr);
      final chest = await tools.handleCall(
        FunctionCall('get_logged_exercises', {
          'muscle_group': 'Chest',
          'days': 183,
        }),
      );
      expect(
        (chest['exercises'] as List).map((e) => (e as Map)['exercise_id']),
        containsAll(['incline_bench_press', 'bench_press']),
      );
      final volume = await tools.handleCall(
        FunctionCall('get_muscle_group_volume', {
          'muscle_groups': ['Chest'],
          'days': 183,
        }),
      );
      expect(
        (volume['totals'] as Map)['Chest'],
        49900,
      ); // Overlap log counts once.
      final upper = await tools.handleCall(
        FunctionCall('get_logged_exercises', {
          'muscle_group': 'Upper Chest',
          'days': 183,
        }),
      );
      expect(
        (upper['exercises'] as List).map((e) => (e as Map)['exercise_id']),
        isNot(contains('bench_press')),
      );
      final result = await tools.handleCall(
        FunctionCall('get_progress_overview', {
          'days': 183,
          'muscle_groups': ['Chest', 'Calves'],
        }),
      );
      expect(result['window_days'], 183);
      final coverage = result['coverage'] as List;
      expect((coverage.last as Map)['logged_exercise_count'], 0);
      final lifts = (coverage.first as Map)['exercises'] as List;
      final incline = lifts.cast<Map>().firstWhere(
        (e) => e['exercise_id'] == 'incline_bench_press',
      );
      expect(
        (incline['earliest_session_in_window'] as Map)['sets'][0]['weight'],
        40,
      );
      expect(
        (incline['latest_session_in_window'] as Map)['sets'][0]['weight'],
        89,
      );
      final performance = await tools.handleCall(
        FunctionCall('get_exercise_performance', {
          'exercise_name': incline['exercise'],
          'days': 183,
          'limit': 1,
        }),
      );
      expect((performance['set_history'] as List).length, 1);
      expect(
        (performance['earliest_session_in_window'] as Map)['sets'][0]['weight'],
        40,
      );
      final recent = await tools.handleCall(
        FunctionCall('get_progress_overview', {
          'days': 10,
          'muscle_groups': ['Chest'],
        }),
      );
      expect(
        ((recent['coverage'] as List).first as Map)['logged_exercise_count'],
        0,
      );
      wp.dispose();
    },
  );

  test(
    'Vertex key is separate, secure, persists selection and survives switching',
    () async {
      final storage = MockStorageService();
      String? secured;
      final settings = SettingsProvider(
        storage,
        readVertexKey: () => Future.value(secured),
        writeVertexKey: (s) async {
          secured = s;
        },
      );
      await settings.init();
      await settings.setGeminiApiKey('studio');
      await settings.setGeminiBackend(GeminiBackend.vertexExpress);
      expect(settings.activeAiApiKey, isEmpty);
      expect(settings.geminiModel, 'gemini-3.8-flash');
      await settings.setGeminiModel('gemini-3.7-flash');
      await settings.setActiveAiApiKey('vertex');
      expect(settings.geminiApiKey, 'studio');
      expect(await storage.getSetting('vertexApiKey'), isNull);
      final restarted = SettingsProvider(
        storage,
        readVertexKey: () => Future.value(secured),
      );
      await restarted.init();
      expect(restarted.geminiBackend, GeminiBackend.vertexExpress);
      expect(restarted.activeAiApiKey, 'vertex');
      expect(restarted.geminiModel, 'gemini-3.7-flash');
      await restarted.setGeminiBackend(GeminiBackend.aiStudio);
      expect(restarted.activeAiApiKey, 'studio');
      expect(restarted.geminiModel, kDefaultGeminiModel);
    },
  );
}
