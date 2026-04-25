// Performance regression tests for PR 2 optimisations.
//
// Strategy: seed a fixture with N sessions × M exercises and assert that
// the new index/cache-based paths return results identical to the brute-force
// reference implementation.  If behaviour drifts the tests will catch it,
// without needing micro-benchmark assertions.

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/analytics_manager.dart';
import 'package:repforge/services/managers/exercise_manager.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import 'package:repforge/services/strategies/target_calculator.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';


// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

/// Build N workout sessions, each containing logs for all [exerciseIds].
List<WorkoutSession> buildFixture({
  required List<String> exerciseIds,
  required int sessionCount,
}) {
  final sessions = <WorkoutSession>[];
  for (var i = 0; i < sessionCount; i++) {
    final date = DateTime(2025, 1, 1).add(Duration(days: i));
    final logs = exerciseIds.map((id) {
      // Weight & reps increase over time so there is a recognisable maximum.
      final weight = 50.0 + i.toDouble();
      final reps = 5 + (i % 5);
      return ExerciseLog(
        exerciseId: id,
        sets: [WorkoutSet(weight: weight, reps: reps)],
      );
    }).toList();
    sessions.add(
      WorkoutSession(
        id: 'session_$i',
        date: date,
        exercises: logs,
        duration: 30,
      ),
    );
  }
  // Return in reverse order so that insertion order ≠ chronological order,
  // catching any code that relied on implicit ordering.
  return sessions.reversed.toList();
}

const _exerciseIds = [
  'ex_0',
  'ex_1',
  'ex_2',
  'ex_3',
  'ex_4',
  'ex_5',
  'ex_6',
  'ex_7',
  'ex_8',
  'ex_9',
];

// ---------------------------------------------------------------------------
// AnalyticsManager — session index
// ---------------------------------------------------------------------------

void main() {
  group('AnalyticsManager.buildSessionIndex — behavioral parity', () {
    late MockStorageService mockStorage;
    late AnalyticsManager analytics;
    late List<WorkoutSession> sessions;

    setUp(() {
      mockStorage = MockStorageService();
      analytics = AnalyticsManager(mockStorage, _FakeMLService());
      sessions = buildFixture(exerciseIds: _exerciseIds, sessionCount: 10);
    });

    test('getRecommendations with index == getRecommendations without index',
        () {
      // Without index (cold)
      final withoutIndex = analytics.getRecommendations('ex_0', sessions);

      // Build the index
      analytics.buildSessionIndex(sessions);

      // With index (warm)
      final withIndex = analytics.getRecommendations('ex_0', sessions);

      expect(
        withIndex.length,
        equals(withoutIndex.length),
        reason: 'Recommendation count should be identical',
      );
      for (var i = 0; i < withoutIndex.length; i++) {
        expect(
          withIndex[i].reps,
          equals(withoutIndex[i].reps),
          reason: 'reps mismatch at index $i',
        );
        expect(
          withIndex[i].weight,
          equals(withoutIndex[i].weight),
          reason: 'weight mismatch at index $i',
        );
      }
    });

    test('getVolumeProgression with index is chronologically ordered', () {
      analytics.buildSessionIndex(sessions);
      final progression = analytics.getVolumeProgression('ex_3', sessions);

      // Should be oldest-first
      expect(progression, isNotEmpty);
      for (var i = 1; i < progression.length; i++) {
        expect(
          progression[i].date.isAfter(progression[i - 1].date) ||
              progression[i].date.isAtSameMomentAs(progression[i - 1].date),
          isTrue,
          reason: 'Progression should be in ascending date order',
        );
      }
    });

    test('getVolumeProgression volumes match brute-force totals', () {
      analytics.buildSessionIndex(sessions);
      final indexedResult = analytics.getVolumeProgression('ex_1', sessions);

      // Brute-force reference: sort sessions oldest-first, pick first log per session
      final sorted = List<WorkoutSession>.from(sessions)
        ..sort((a, b) => a.date.compareTo(b.date));
      final reference = <double>[];
      for (final session in sorted) {
        for (final log in session.exercises) {
          if (log.exerciseId == 'ex_1') {
            reference.add(log.totalVolume);
            break;
          }
        }
      }

      expect(indexedResult.map((e) => e.volume).toList(), equals(reference));
    });

    test('getWeeklyVolumeByMuscle with exerciseMap equals without', () {
      // Build a minimal one-exercise list so the map has something to look up
      final exercise = Exercise(
        id: 'ex_0',
        name: 'Test Exercise',
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100),
        ],
        category: 'compound',
      );
      final exercises = [exercise];
      final exerciseMap = {exercise.id: exercise};
      final now = sessions.first.date.add(const Duration(days: 1));

      final withMap = analytics.getWeeklyVolumeByMuscle(
        sessions,
        exercises,
        now: now,
        exerciseMap: exerciseMap,
      );
      final withoutMap = analytics.getWeeklyVolumeByMuscle(
        sessions,
        exercises,
        now: now,
      );

      expect(withMap, equals(withoutMap));
    });
  });

  // ---------------------------------------------------------------------------
  // ExerciseManager — memoized exercise index
  // ---------------------------------------------------------------------------

  group('ExerciseManager.getExercise — O(1) map lookup parity', () {
    late MockStorageService mockStorage;
    late ExerciseManager exerciseManager;

    setUp(() async {
      mockStorage = MockStorageService();
      exerciseManager = ExerciseManager(mockStorage);
      await exerciseManager.loadExercises();
    });

    test('getExercise returns same result for known exercise', () async {
      // Add a custom exercise and immediately look it up
      final added = await exerciseManager.addCustomExercise(
        name: 'Index Lookup Test',
        category: 'compound',
        primaryMuscleGroupId: 'chest',
      );

      final found = exerciseManager.getExercise(added.id);
      expect(found, isNotNull);
      expect(found!.id, equals(added.id));
      expect(found.name, equals('Index Lookup Test'));
    });

    test('getExercise returns null for unknown id', () {
      expect(exerciseManager.getExercise('phantom_id'), isNull);
    });

    test('cache is invalidated after deleteCustomExercise', () async {
      final added = await exerciseManager.addCustomExercise(
        name: 'To Delete Cache Test',
        category: 'isolation',
        primaryMuscleGroupId: 'biceps',
      );

      // Should be found before deletion
      expect(exerciseManager.getExercise(added.id), isNotNull);

      await exerciseManager.deleteCustomExercise(added.id);

      // Should be gone after deletion
      expect(exerciseManager.getExercise(added.id), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // TargetCalculator — RepsTargetCalculator in-place max scan
  // ---------------------------------------------------------------------------

  group('RepsTargetCalculator — in-place max scan parity', () {
    test('returns max reps across all sessions', () {
      final sessions = [
        WorkoutSession(
          id: 's1',
          date: DateTime(2025, 1, 1),
          exercises: [
            ExerciseLog(
              exerciseId: 'ex_0',
              sets: [WorkoutSet(weight: 50, reps: 8), WorkoutSet(weight: 50, reps: 10)],
            ),
          ],
          duration: 30,
        ),
        WorkoutSession(
          id: 's2',
          date: DateTime(2025, 2, 1),
          exercises: [
            ExerciseLog(
              exerciseId: 'ex_0',
              sets: [WorkoutSet(weight: 60, reps: 12)],
            ),
          ],
          duration: 30,
        ),
      ];

      final result = RepsTargetCalculator().calculate('ex_0', sessions);
      expect(result, equals(12.0));
    });

    test('returns 0 when no sessions for the exercise', () {
      final result = RepsTargetCalculator().calculate('unknown', []);
      expect(result, equals(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // WorkoutProvider.getWeeklyVolumeByMuscle — early-exit sort
  // ---------------------------------------------------------------------------

  group('WorkoutProvider.getWeeklyVolumeByMuscle — early exit + map', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      // Seed one session from 3 days ago and one from 30 days ago.
      final recent = WorkoutSession(
        id: 'recent',
        date: DateTime.now().subtract(const Duration(days: 3)),
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press', // built-in exercise
            sets: [WorkoutSet(weight: 100, reps: 5)],
          ),
        ],
        duration: 30,
      );
      final old = WorkoutSession(
        id: 'old',
        date: DateTime.now().subtract(const Duration(days: 30)),
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [WorkoutSet(weight: 80, reps: 5)],
          ),
        ],
        duration: 30,
      );
      mockStorage.addMockSession(recent);
      mockStorage.addMockSession(old);
      provider = WorkoutProvider(
        mockStorage,
        programManager: ProgramManager(mockStorage),
      );
      await provider.init();
    });

    test('only counts sessions within the last 7 days', () {
      final result = provider.getWeeklyVolumeByMuscle();
      // bench_press activates multiple muscle groups (chest, triceps, shoulders
      // etc.) so the total distributed volume may be > 500 kg.
      // The recent session lifts 100kg × 5 reps = 500 kg raw; with muscle
      // activations summed it can be up to 500 * (number of muscle groups).
      // The old session lifts 80kg × 5 reps = 400 kg raw.
      // Key invariant: result is positive (recent session counted) yet below
      // the combined total of both sessions (old session excluded).
      expect(result.isNotEmpty, isTrue);

      final totalVolume = result.values.reduce((a, b) => a + b);
      // With only the recent session: max distributed volume is 500 × groups.
      // With both sessions: it would be at least (500 + 400) = 900 baseline.
      // Verify old session is excluded by checking total < combined maximum.
      // bench_press raw: recent=500, old=400; combined minimum = 900.
      expect(
        totalVolume,
        lessThan(900),
        reason: 'Old session (30 days ago) should be excluded',
      );
      expect(totalVolume, greaterThan(0));
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal fake ML service — returns deterministic recommendations
// ---------------------------------------------------------------------------

class _FakeMLService implements IMLService {
  @override
  List<SetRecommendation> getDefaultRecommendations(int count) => [
        for (var i = 0; i < count; i++)
          SetRecommendation(
            reps: 8,
            weight: 20.0,
            confidence: 'low',
            reasoning: 'default',
          ),
      ];

  @override
  List<SetRecommendation> recommendSets({
    required List<WorkoutSet> lastSession,
    GrowthModel? growthModel,
  }) =>
      // Echo last session's sets as recommendations (deterministic)
      lastSession
          .map(
            (s) => SetRecommendation(
              reps: s.reps,
              weight: s.weight,
              confidence: 'high',
              reasoning: 'echo',
            ),
          )
          .toList();

  @override
  List<DataPoint> extractExerciseDataPoints(
    String exerciseId,
    List<WorkoutSession> sessions,
  ) =>
      [];

  @override
  GrowthModel trainGrowthModel(List<DataPoint> dataPoints) => GrowthModel(
        slope: 0,
        intercept: 0,
        r2: 0,
        lastTrained: DateTime(2025),
      );

  @override
  DateTime? predictTargetCompletion({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
  }) =>
      null;
}

