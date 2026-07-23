import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/gemini_context_builder.dart';

void main() {
  group('GeminiContextBuilder', () {
    test('buildCoachSystemPrompt includes today date, unit label, and username', () {
      final now = DateTime(2026, 7, 23);
      final prompt = GeminiContextBuilder.buildCoachSystemPrompt(
        userName: 'Devasy',
        unitLabel: 'lbs',
        now: now,
      );

      expect(prompt, contains('Today is 2026-07-23'));
      expect(prompt, contains('Weights are in lbs'));
      expect(prompt, contains("The user's name is Devasy"));
      expect(prompt, contains('RepForge'));
    });

    test('buildOptimizerSystemPrompt builds routine optimizer system prompt', () {
      final now = DateTime(2026, 7, 23);
      final prompt = GeminiContextBuilder.buildOptimizerSystemPrompt(
        userName: 'Devasy',
        unitLabel: 'kg',
        now: now,
      );

      expect(prompt, contains('specialized routine optimizer'));
      expect(prompt, contains('Today is 2026-07-23'));
      expect(prompt, contains('Weights are in kg'));
      expect(prompt, contains("The user's name is Devasy"));
    });

    test('buildWeeklyInsightsContext formats sessions and volumes for this and last week', () {
      final exerciseMap = <String, Exercise>{
        'ex1': Exercise(
          id: 'ex1',
          name: 'Bench Press',
          category: 'compound',
          muscleActivations: [
            MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100),
          ],
        ),
      };

      final thisWeekSession = WorkoutSession(
        id: 's1',
        date: DateTime(2026, 7, 20), // Monday
        duration: 45,
        exercises: [
          ExerciseLog(
            exerciseId: 'ex1',
            sets: [
              WorkoutSet(weight: 100, reps: 10),
            ],
          ),
        ],
      );

      final lastWeekSession = WorkoutSession(
        id: 's2',
        date: DateTime(2026, 7, 13), // Monday
        duration: 45,
        exercises: [
          ExerciseLog(
            exerciseId: 'ex1',
            sets: [
              WorkoutSet(weight: 95, reps: 10),
            ],
          ),
        ],
      );

      final result = GeminiContextBuilder.buildWeeklyInsightsContext(
        thisWeek: [thisWeekSession],
        lastWeek: [lastWeekSession],
        exerciseMap: exerciseMap,
        unitLabel: 'kg',
      );

      expect(result, contains('THIS WEEK — 1 sessions'));
      expect(result, contains('Bench Press 1×sets (1000kg vol)'));
      expect(result, contains('LAST WEEK — 1 sessions'));
      expect(result, contains('Mon: Bench Press'));
    });
  });
}
