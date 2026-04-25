// Tests for the shared exercise-history helper.
//
// Sessions can be passed in any order — the helper must always return the
// log from the most-recently-dated session.

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/utils/exercise_history.dart';

WorkoutSet _set({double weight = 50, int reps = 8}) =>
    WorkoutSet(weight: weight, reps: reps);

ExerciseLog _log(String exerciseId, {List<WorkoutSet>? sets}) =>
    ExerciseLog(exerciseId: exerciseId, sets: sets ?? [_set()]);

WorkoutSession _session(
  String id,
  DateTime date,
  List<ExerciseLog> logs,
) => WorkoutSession(
  id: id,
  date: date,
  exercises: logs,
  duration: 30,
);

void main() {
  group('findMostRecentExerciseLog', () {
    test('returns null when sessions is empty', () {
      expect(findMostRecentExerciseLog('bench', const []), isNull);
    });

    test('returns null when no session contains the exercise', () {
      final sessions = [
        _session('s1', DateTime(2025, 1, 1), [_log('squat')]),
      ];
      expect(findMostRecentExerciseLog('bench', sessions), isNull);
    });

    test('returns the log from the most-recently-dated session', () {
      final marker = [_set(weight: 100, reps: 5)];
      final sessions = [
        _session('old', DateTime(2025, 1, 1), [_log('bench')]),
        _session('newest', DateTime(2025, 3, 1), [_log('bench', sets: marker)]),
        _session('mid', DateTime(2025, 2, 1), [_log('bench')]),
      ];

      final result = findMostRecentExerciseLog('bench', sessions);

      expect(result, isNotNull);
      expect(result!.sets.first.weight, 100);
      expect(result.sets.first.reps, 5);
    });

    test('does not depend on input order', () {
      final marker = [_set(weight: 200, reps: 3)];
      final newest = _session('newest', DateTime(2025, 6, 1), [
        _log('bench', sets: marker),
      ]);
      final older1 = _session('a', DateTime(2025, 1, 1), [_log('bench')]);
      final older2 = _session('b', DateTime(2025, 4, 1), [_log('bench')]);

      // Pass with the newest session in the middle — wrong-order input.
      final result = findMostRecentExerciseLog('bench', [
        older1,
        newest,
        older2,
      ]);

      expect(result!.sets.first.weight, 200);
    });

    test('skips sessions that do not contain the target exercise', () {
      final markerSets = [_set(weight: 80, reps: 10)];
      final sessions = [
        _session('newer-without-bench', DateTime(2025, 5, 1), [_log('squat')]),
        _session('older-with-bench', DateTime(2025, 2, 1), [
          _log('bench', sets: markerSets),
        ]),
      ];

      final result = findMostRecentExerciseLog('bench', sessions);

      expect(result, isNotNull);
      expect(result!.sets.first.weight, 80);
    });
  });
}
