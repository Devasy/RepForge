// Unit tests for the two new parameterised analytics query methods on
// WorkoutProvider:  getSetProgression()  and  getMuscleExerciseBreakdown().
//
// These methods are designed as the future agent-tool surface, so the tests
// double as a contract: pure, side-effect-free, date-range-aware.

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

WorkoutSession _session({
  required String id,
  required DateTime date,
  required List<ExerciseLog> logs,
}) =>
    WorkoutSession(id: id, date: date, duration: 30, exercises: logs);

ExerciseLog _log(String exerciseId, List<WorkoutSet> sets) =>
    ExerciseLog(exerciseId: exerciseId, sets: sets);

WorkoutSet _set({double weight = 80.0, int reps = 10}) =>
    WorkoutSet(weight: weight, reps: reps);

Exercise _exercise(String id, String muscleId, {int activation = 100}) =>
    Exercise(
      id: id,
      name: 'Ex-$id',
      category: 'compound',
      muscleActivations: [
        MuscleActivation(
            muscleGroupId: muscleId, activationPercentage: activation),
      ],
    );

Future<WorkoutProvider> _makeProvider(
  MockStorageService storage, {
  MockMLService? ml,
}) async {
  final p = WorkoutProvider(
    storage,
    mlService: ml ?? MockMLService(),
    programManager: ProgramManager(storage),
  );
  await p.init();
  return p;
}

// ── getSetProgression ─────────────────────────────────────────────────────────

void main() {
  group('WorkoutProvider.getSetProgression', () {
    late MockStorageService storage;

    setUp(() => storage = MockStorageService());

    test('returns empty list when no sessions exist', () async {
      final p = await _makeProvider(storage);
      expect(p.getSetProgression('bench'), isEmpty);
    });

    test('returns empty list when exercise was never performed', () async {
      storage.addMockSession(_session(
        id: 's1',
        date: DateTime(2024, 1, 10),
        logs: [_log('squat', [_set(weight: 100)])],
      ));
      final p = await _makeProvider(storage);
      expect(p.getSetProgression('bench'), isEmpty);
    });

    test('returns sessions oldest-first', () async {
      storage.addMockSession(_session(
        id: 's1',
        date: DateTime(2024, 1, 10),
        logs: [_log('bench', [_set(weight: 80)])],
      ));
      storage.addMockSession(_session(
        id: 's2',
        date: DateTime(2024, 1, 5),
        logs: [_log('bench', [_set(weight: 75)])],
      ));
      final p = await _makeProvider(storage);

      final result = p.getSetProgression('bench');

      expect(result.length, 2);
      expect(result[0].date, DateTime(2024, 1, 5)); // older first
      expect(result[1].date, DateTime(2024, 1, 10));
    });

    test('each entry carries the correct sets', () async {
      final set1 = _set(weight: 80, reps: 8);
      final set2 = _set(weight: 85, reps: 6);
      storage.addMockSession(_session(
        id: 's1',
        date: DateTime(2024, 2, 1),
        logs: [_log('bench', [set1, set2])],
      ));
      final p = await _makeProvider(storage);

      final result = p.getSetProgression('bench');
      expect(result.length, 1);
      expect(result[0].sets.length, 2);
      expect(result[0].sets[0].weight, 80.0);
      expect(result[0].sets[1].weight, 85.0);
    });

    test('excludes sessions outside [start, end] range', () async {
      storage.addMockSession(_session(
        id: 's1',
        date: DateTime(2024, 3, 1),
        logs: [_log('bench', [_set(weight: 70)])],
      ));
      storage.addMockSession(_session(
        id: 's2',
        date: DateTime(2024, 3, 10),
        logs: [_log('bench', [_set(weight: 80)])],
      ));
      storage.addMockSession(_session(
        id: 's3',
        date: DateTime(2024, 3, 20),
        logs: [_log('bench', [_set(weight: 90)])],
      ));
      final p = await _makeProvider(storage);

      final result = p.getSetProgression(
        'bench',
        start: DateTime(2024, 3, 5),
        end: DateTime(2024, 3, 15),
      );

      // Only s2 (Mar 10) falls in [Mar 5, Mar 15].
      expect(result.length, 1);
      expect(result[0].sets[0].weight, 80.0);
    });

    test('start-only filter excludes sessions before start', () async {
      storage.addMockSession(_session(
        id: 's1',
        date: DateTime(2024, 1, 1),
        logs: [_log('bench', [_set(weight: 60)])],
      ));
      storage.addMockSession(_session(
        id: 's2',
        date: DateTime(2024, 6, 1),
        logs: [_log('bench', [_set(weight: 90)])],
      ));
      final p = await _makeProvider(storage);

      final result = p.getSetProgression(
        'bench',
        start: DateTime(2024, 3, 1),
      );

      expect(result.length, 1);
      expect(result[0].sets[0].weight, 90.0);
    });

    test('only includes the target exercise from mixed-exercise sessions',
        () async {
      storage.addMockSession(_session(
        id: 's1',
        date: DateTime(2024, 4, 1),
        logs: [
          _log('bench', [_set(weight: 80)]),
          _log('squat', [_set(weight: 120)]),
        ],
      ));
      final p = await _makeProvider(storage);

      final bench = p.getSetProgression('bench');
      final squat = p.getSetProgression('squat');

      expect(bench.length, 1);
      expect(bench[0].sets[0].weight, 80.0);
      expect(squat.length, 1);
      expect(squat[0].sets[0].weight, 120.0);
    });

    test('sessions with no sets for the exercise are excluded', () async {
      storage.addMockSession(_session(
        id: 's1',
        date: DateTime(2024, 5, 1),
        logs: [_log('bench', [])], // empty sets
      ));
      storage.addMockSession(_session(
        id: 's2',
        date: DateTime(2024, 5, 10),
        logs: [_log('bench', [_set(weight: 80)])],
      ));
      final p = await _makeProvider(storage);

      final result = p.getSetProgression('bench');
      // Session with empty log is excluded; only s2 appears.
      expect(result.length, 1);
      expect(result[0].date, DateTime(2024, 5, 10));
    });
  });

  // ── getMuscleExerciseBreakdown ─────────────────────────────────────────────

  group('WorkoutProvider.getMuscleExerciseBreakdown', () {
    late MockStorageService storage;

    setUp(() => storage = MockStorageService());

    test('returns empty list when no sessions exist', () async {
      storage.addMockCustomExercise(_exercise('bench', 'chest'));
      final p = await _makeProvider(storage);
      expect(p.getMuscleExerciseBreakdown('chest'), isEmpty);
    });

    test('returns empty list when no session is in the default 7-day window',
        () async {
      storage.addMockCustomExercise(_exercise('bench', 'chest'));
      storage.addMockSession(_session(
        id: 's1',
        date: DateTime(2020, 1, 1), // long ago
        logs: [_log('bench', [_set(weight: 80)])],
      ));
      final p = await _makeProvider(storage);
      expect(p.getMuscleExerciseBreakdown('chest'), isEmpty);
    });

    test('returns exercises sorted by contributed volume descending', () async {
      // Two exercises both hitting chest.
      storage.addMockCustomExercise(
          _exercise('bench', 'chest', activation: 70));
      storage.addMockCustomExercise(
          _exercise('cable', 'chest'));

      final now = DateTime.now();
      // bench: 80kg × 10 reps × 70% = 560 volume
      // cable: 30kg × 8 reps × 100% = 240 volume
      storage.addMockSession(_session(
        id: 's1',
        date: now,
        logs: [
          _log('bench', [_set(weight: 80, reps: 10)]),
          _log('cable', [_set(weight: 30, reps: 8)]),
        ],
      ));
      final p = await _makeProvider(storage);

      final result = p.getMuscleExerciseBreakdown('chest');

      expect(result.length, 2);
      expect(result[0].exerciseId, 'bench'); // higher volume first
      expect(result[1].exerciseId, 'cable');
    });

    test('volume is weight × reps × (activationPercentage / 100)', () async {
      storage.addMockCustomExercise(
          _exercise('bench', 'chest', activation: 70));

      final now = DateTime.now();
      // 1 set: 100kg × 5 reps × 70% = 350
      storage.addMockSession(_session(
        id: 's1',
        date: now,
        logs: [_log('bench', [_set(weight: 100, reps: 5)])],
      ));
      final p = await _makeProvider(storage);

      final result = p.getMuscleExerciseBreakdown('chest');
      expect(result.length, 1);
      expect(result[0].volume, closeTo(350.0, 0.01));
    });

    test('exercises that do not activate the muscle are excluded', () async {
      storage.addMockCustomExercise(_exercise('bench', 'chest'));
      storage.addMockCustomExercise(_exercise('curl', 'biceps'));

      final now = DateTime.now();
      storage.addMockSession(_session(
        id: 's1',
        date: now,
        logs: [
          _log('bench', [_set(weight: 80)]),
          _log('curl', [_set(weight: 20)]),
        ],
      ));
      final p = await _makeProvider(storage);

      final chestResult = p.getMuscleExerciseBreakdown('chest');
      expect(chestResult.every((e) => e.exerciseId == 'bench'), isTrue);

      final bicepsResult = p.getMuscleExerciseBreakdown('biceps');
      expect(bicepsResult.every((e) => e.exerciseId == 'curl'), isTrue);
    });

    test('date range filter excludes sessions outside [start, end]', () async {
      storage.addMockCustomExercise(_exercise('bench', 'chest'));
      storage.addMockSession(_session(
        id: 's_old',
        date: DateTime(2024, 1, 1),
        logs: [_log('bench', [_set(weight: 60)])],
      ));
      storage.addMockSession(_session(
        id: 's_new',
        date: DateTime(2024, 6, 15),
        logs: [_log('bench', [_set(weight: 90)])],
      ));
      final p = await _makeProvider(storage);

      final result = p.getMuscleExerciseBreakdown(
        'chest',
        start: DateTime(2024, 6, 1),
        end: DateTime(2024, 6, 30),
      );

      expect(result.length, 1);
      // 90kg × 10 reps × 100%
      expect(result[0].volume, closeTo(900.0, 0.01));
    });

    test('sums volume across multiple sessions for the same exercise', () async {
      storage.addMockCustomExercise(_exercise('bench', 'chest'));
      final start = DateTime(2024, 7, 1);
      // Two sessions: 800 + 1000 = 1800 total volume (100% activation).
      storage.addMockSession(_session(
        id: 's1',
        date: DateTime(2024, 7, 5),
        logs: [_log('bench', [_set(weight: 80, reps: 10)])],
      ));
      storage.addMockSession(_session(
        id: 's2',
        date: DateTime(2024, 7, 10),
        logs: [_log('bench', [_set(weight: 100, reps: 10)])],
      ));
      final p = await _makeProvider(storage);

      final result = p.getMuscleExerciseBreakdown(
        'chest',
        start: start,
        end: DateTime(2024, 7, 31),
      );

      expect(result.length, 1);
      expect(result[0].volume, closeTo(1800.0, 0.01));
    });

    test('returns exercise name via getExerciseName', () async {
      storage.addMockCustomExercise(
        Exercise(
          id: 'bench_custom',
          name: 'Bench Press Custom',
          category: 'compound',
          isCustom: true,
          muscleActivations: [
            MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100),
          ],
        ),
      );
      final now = DateTime.now();
      storage.addMockSession(_session(
        id: 's1',
        date: now,
        logs: [_log('bench_custom', [_set(weight: 80)])],
      ));
      final p = await _makeProvider(storage);

      final result = p.getMuscleExerciseBreakdown('chest');
      expect(result.length, 1);
      expect(result[0].name, 'Bench Press Custom');
    });
  });
}
