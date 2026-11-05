import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  test(
    'old sessions cannot masquerade as recent sessions and PR maxima remain separate',
    () async {
      final storage = MockStorageService();
      final old = DateTime.now().subtract(const Duration(days: 160));
      storage.addMockSession(
        WorkoutSession(
          id: 'old',
          date: old,
          duration: 30,
          exercises: [
            ExerciseLog(
              exerciseId: 'bicep_curl',
              sets: [
                WorkoutSet(weight: 12.5, reps: 8),
                WorkoutSet(weight: 7.5, reps: 14),
              ],
            ),
          ],
        ),
      );
      final provider = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await provider.init();
      final pr = PRManager(storage);
      await pr.backfillFromSessions(provider.sessions);
      final tools = CoachToolService(workoutProvider: provider, prManager: pr);
      final result = await tools.handleCall(
        FunctionCall('get_exercise_performance', {
          'exercise_name': 'Bicep Curl',
          'days': 90,
        }),
      );
      expect(result['session_count'], 0);
      expect(result['last_session'], isNull);
      expect(result['last_session_date'], isNull);
      expect(result['growth'], isNull);
      expect(
        (result['last_logged_session'] as Map)['date'],
        old.toIso8601String().substring(0, 10),
      );
      expect(
        (result['personal_record'] as Map)['record_semantics'],
        contains('Never combine'),
      );
      final discovery = await tools.handleCall(
        FunctionCall('get_logged_exercises', {
          'muscle_group': 'Biceps',
          'days': 90,
        }),
      );
      expect(discovery['exercises'], isEmpty);
      final all = await tools.handleCall(
        FunctionCall('get_logged_exercises', {
          'muscle_group': 'Biceps',
          'days': 365,
        }),
      );
      expect(
        ((all['exercises'] as List).single as Map)['exercise'],
        'Bicep Curl',
      );
    },
  );
}
