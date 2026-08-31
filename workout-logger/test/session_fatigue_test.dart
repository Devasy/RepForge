import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/utils/session_fatigue.dart';

WorkoutSet _hardSet({
  double weight = 100,
  int reps = 5,
  DateTime? timestamp,
}) =>
    WorkoutSet(
      weight: weight,
      reps: reps,
      timestamp: timestamp ?? DateTime(2026, 1, 1, 10, 0),
    );

void main() {
  const accumulator = SessionFatigueAccumulator();

  test('empty session logs produce zero factor', () {
    expect(accumulator.factorFor(exerciseLogs: []), 0.0);
  });

  test('logs with no sets yet (pre-selected exercises) contribute nothing', () {
    final factor = accumulator.factorFor(
      exerciseLogs: [const ExerciseLog(exerciseId: 'squat', sets: [])],
    );
    expect(factor, 0.0);
  });

  test('excludeExerciseId skips that exercise but keeps others', () {
    // Each hard set contributes (8.0 − 6.0) / 3.0 ≈ 0.667, and the factor is
    // 0.0 until the raw total passes _softCap (16.0). With one set per
    // exercise both branches sit at 0.0 and the comparison holds even if the
    // exclusion were ignored — so load each exercise past the cap, where
    // dropping one is actually observable.
    const setsPerExercise = 30; // ≈20.0 raw, comfortably past _softCap
    List<WorkoutSet> hardSets() => [
          for (var i = 0; i < setsPerExercise; i++)
            _hardSet(timestamp: DateTime(2026, 1, 1, 10, i)),
        ];

    final logs = [
      ExerciseLog(exerciseId: 'squat', sets: hardSets()),
      ExerciseLog(exerciseId: 'leg_press', sets: hardSets()),
    ];

    final withSquatExcluded = accumulator.factorFor(
      exerciseLogs: logs,
      excludeExerciseId: 'squat',
    );
    final legPressOnly = accumulator.factorFor(exerciseLogs: [logs[1]]);

    expect(withSquatExcluded, closeTo(legPressOnly, 0.0001));
    // Strictly inside (0, 1): at 0.0 or 1.0 the assertion above would pass
    // whether or not the exclusion happened.
    expect(withSquatExcluded, greaterThan(0.0));
    expect(withSquatExcluded, lessThan(1.0));
    // And keeping both exercises must land somewhere different.
    expect(
      accumulator.factorFor(exerciseLogs: logs),
      greaterThan(withSquatExcluded),
    );
  });

  test('a realistic session (a handful of sets across a few exercises) '
      'stays at zero — this is the calibrated-inert case', () {
    // 4 exercises, 3 sets each = 12 sets, well within what a real session
    // looks like (backtest max across 254 real contexts was 11.87 raw,
    // caps start at 16.0).
    final logs = [
      for (var ex = 0; ex < 4; ex++)
        ExerciseLog(
          exerciseId: 'ex$ex',
          sets: [
            for (var s = 0; s < 3; s++)
              _hardSet(timestamp: DateTime(2026, 1, 1, 10, ex * 10 + s * 2)),
          ],
        ),
    ];
    final factor = accumulator.factorFor(exerciseLogs: logs);
    expect(factor, 0.0);
  });

  test('an extreme, unrealistic session eventually saturates the factor '
      'toward 1.0 — proves the mechanism works end-to-end even though '
      'real sessions never reach it', () {
    final logs = [
      for (var ex = 0; ex < 10; ex++)
        ExerciseLog(
          exerciseId: 'ex$ex',
          sets: [
            for (var s = 0; s < 5; s++)
              _hardSet(timestamp: DateTime(2026, 1, 1, 10, ex * 10 + s * 2)),
          ],
        ),
    ];
    final factor = accumulator.factorFor(exerciseLogs: logs);
    expect(factor, greaterThan(0.0));
  });

  test('factor is always clamped to [0.0, 1.0]', () {
    final logs = [
      for (var ex = 0; ex < 30; ex++)
        ExerciseLog(
          exerciseId: 'ex$ex',
          sets: [_hardSet(timestamp: DateTime(2026, 1, 1, 10, ex * 5))],
        ),
    ];
    final factor = accumulator.factorFor(exerciseLogs: logs);
    expect(factor, greaterThanOrEqualTo(0.0));
    expect(factor, lessThanOrEqualTo(1.0));
  });
}
