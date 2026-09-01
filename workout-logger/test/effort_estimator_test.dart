import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/utils/effort_estimator.dart';

WorkoutSet _set({
  double weight = 60.0,
  int reps = 10,
  DateTime? timestamp,
  int? timeTaken,
}) =>
    WorkoutSet(
      weight: weight,
      reps: reps,
      timestamp: timestamp ?? DateTime(2026, 1, 1, 10, 0),
      timeTaken: timeTaken,
    );

void main() {
  const estimator = EffortEstimator();

  group('EffortEstimator - no signals available', () {
    test('returns the RPE-8 anchor with base confidence', () {
      final result = estimator.estimate(set: _set());
      expect(result.rpe, closeTo(EffortEstimator.anchorRpe, 0.001));
      expect(result.source, EffortSource.estimatedHrless);
      expect(result.confidence, closeTo(0.35, 0.001));
    });

    test('calibrationOffset shifts the anchor', () {
      final result = estimator.estimate(set: _set(), calibrationOffset: 0.5);
      expect(result.rpe, closeTo(EffortEstimator.anchorRpe + 0.5, 0.001));
    });
  });

  group('EffortEstimator - term 1: trend deviation', () {
    test('actual volume above trend lowers RPE (easier than expected)', () {
      final model = GrowthModel(
        slope: 5.0,
        intercept: 500.0, // predicted volume at x=0 is 500
        r2: 0.9,
        lastTrained: DateTime.now(),
        stdError: 50.0,
      );
      // set volume = 60*10 = 600, well above the 500 prediction.
      final result = estimator.estimate(
        set: _set(weight: 60, reps: 10),
        growthModel: model,
        growthModelX: 0,
      );
      expect(result.rpe, lessThan(EffortEstimator.anchorRpe));
      expect(result.confidence, greaterThan(0.35));
    });

    test('actual volume below trend raises RPE (harder than expected)', () {
      final model = GrowthModel(
        slope: 5.0,
        intercept: 900.0,
        r2: 0.9,
        lastTrained: DateTime.now(),
        stdError: 50.0,
      );
      final result = estimator.estimate(
        set: _set(weight: 60, reps: 10), // volume 600, well below 900
        growthModel: model,
        growthModelX: 0,
      );
      expect(result.rpe, greaterThan(EffortEstimator.anchorRpe));
    });

    test('untrustworthy fit (low r2) is ignored', () {
      final model = GrowthModel(
        slope: 5.0,
        intercept: 900.0,
        r2: 0.05, // below the 0.2 trust threshold
        lastTrained: DateTime.now(),
        stdError: 50.0,
      );
      final result = estimator.estimate(
        set: _set(weight: 60, reps: 10),
        growthModel: model,
        growthModelX: 0,
      );
      expect(result.rpe, closeTo(EffortEstimator.anchorRpe, 0.001));
    });

    test('missing growthModelX skips the term even with a trustworthy model',
        () {
      final model = GrowthModel(
        slope: 5.0,
        intercept: 900.0,
        r2: 0.9,
        lastTrained: DateTime.now(),
      );
      final result = estimator.estimate(set: _set(), growthModel: model);
      expect(result.rpe, closeTo(EffortEstimator.anchorRpe, 0.001));
    });
  });

  group('EffortEstimator - term 2: intra-session decline', () {
    test('flat volume across sets contributes nothing', () {
      final prior = [_set(weight: 60, reps: 10)];
      final result = estimator.estimate(
        set: _set(weight: 60, reps: 10),
        priorSetsThisExerciseToday: prior,
      );
      expect(result.rpe, closeTo(EffortEstimator.anchorRpe, 0.001));
    });

    test('a small dip within the deadband contributes nothing', () {
      final prior = [_set(weight: 100, reps: 10)]; // volume 1000
      final result = estimator.estimate(
        set: _set(weight: 97, reps: 10), // volume 970, 3% drop — within the 5% deadband
        priorSetsThisExerciseToday: prior,
      );
      expect(result.rpe, closeTo(EffortEstimator.anchorRpe, 0.001));
    });

    test('a drop just past the deadband raises RPE', () {
      final prior = [_set(weight: 100, reps: 10)]; // volume 1000
      final result = estimator.estimate(
        set: _set(weight: 90, reps: 10), // volume 900, 10% drop
        priorSetsThisExerciseToday: prior,
      );
      expect(result.rpe, greaterThan(EffortEstimator.anchorRpe));
    });

    test('a real volume drop across sets raises RPE', () {
      final prior = [_set(weight: 100, reps: 10)]; // volume 1000
      final result = estimator.estimate(
        set: _set(weight: 100, reps: 6), // volume 600, 40% drop
        priorSetsThisExerciseToday: prior,
      );
      expect(result.rpe, greaterThan(EffortEstimator.anchorRpe + 1));
    });
  });

  group('EffortEstimator - term 3: rest/tempo drift', () {
    test('needs at least 2 prior sets to establish a baseline', () {
      final prior = [
        _set(timestamp: DateTime(2026, 1, 1, 10, 0), timeTaken: 30),
      ];
      final result = estimator.estimate(
        set: _set(timestamp: DateTime(2026, 1, 1, 10, 5), timeTaken: 90),
        priorSetsThisExerciseToday: prior,
      );
      // Only decline term (n/a here, flat volume) applies; rest/tempo is
      // skipped with a single prior set.
      expect(result.rpe, closeTo(EffortEstimator.anchorRpe, 0.001));
    });

    test('a much longer rest gap than usual raises RPE', () {
      final prior = [
        _set(timestamp: DateTime(2026, 1, 1, 10, 0)),
        _set(timestamp: DateTime(2026, 1, 1, 10, 2)), // 120s gap
      ];
      final result = estimator.estimate(
        // 600s gap vs a 120s median — well over double.
        set: _set(timestamp: DateTime(2026, 1, 1, 10, 12)),
        priorSetsThisExerciseToday: prior,
      );
      expect(result.rpe, greaterThan(EffortEstimator.anchorRpe));
    });

    test('a much slower tempo than usual raises RPE', () {
      final prior = [
        _set(timestamp: DateTime(2026, 1, 1, 10, 0), reps: 10, timeTaken: 20),
        _set(timestamp: DateTime(2026, 1, 1, 10, 2), reps: 10, timeTaken: 20),
      ];
      final result = estimator.estimate(
        set: _set(timestamp: DateTime(2026, 1, 1, 10, 4), reps: 10, timeTaken: 60),
        priorSetsThisExerciseToday: prior,
      );
      expect(result.rpe, greaterThan(EffortEstimator.anchorRpe));
    });
  });

  group('EffortEstimator - term 4: heart rate (optional)', () {
    test('is skipped entirely when hrSignal is null', () {
      final result = estimator.estimate(set: _set());
      expect(result.source, EffortSource.estimatedHrless);
    });

    test('too few samples in the set window is ignored', () {
      final result = estimator.estimate(
        set: _set(),
        hrSignal: const HrEffortSignal(
          setPeakBpm: 170,
          setSampleCount: 2, // below minHrSamplesForSignal
          sessionFloorBpm: 90,
          sessionPeakBpm: 175,
        ),
      );
      expect(result.source, EffortSource.estimatedHrless);
      expect(result.rpe, closeTo(EffortEstimator.anchorRpe, 0.001));
    });

    test('a set peak near the session ceiling raises RPE and confidence', () {
      final withoutHr = estimator.estimate(set: _set());
      final withHr = estimator.estimate(
        set: _set(),
        hrSignal: const HrEffortSignal(
          setPeakBpm: 174,
          setSampleCount: 5,
          sessionFloorBpm: 90,
          sessionPeakBpm: 175,
        ),
      );
      expect(withHr.source, EffortSource.estimatedWithHr);
      expect(withHr.rpe, greaterThan(withoutHr.rpe));
      expect(withHr.confidence, greaterThan(withoutHr.confidence));
    });

    test('a set peak well below the session ceiling lowers RPE', () {
      final result = estimator.estimate(
        set: _set(),
        hrSignal: const HrEffortSignal(
          setPeakBpm: 100,
          setSampleCount: 5,
          sessionFloorBpm: 90,
          sessionPeakBpm: 175,
        ),
      );
      expect(result.rpe, lessThan(EffortEstimator.anchorRpe));
    });
  });

  group('EffortEstimator - confidence ladder', () {
    test('never exceeds maxEstimatedConfidence even with every bonus', () {
      final model = GrowthModel(
        slope: 5.0,
        intercept: 500.0,
        r2: 0.9,
        lastTrained: DateTime.now(),
        stdError: 50.0,
      );
      final prior = [
        _set(timestamp: DateTime(2026, 1, 1, 10, 0)),
        _set(timestamp: DateTime(2026, 1, 1, 10, 2)),
      ];
      final result = estimator.estimate(
        set: _set(timestamp: DateTime(2026, 1, 1, 10, 4)),
        priorSetsThisExerciseToday: prior,
        growthModel: model,
        growthModelX: 0,
        sessionHistoryCount: 10,
        hrSignal: const HrEffortSignal(
          setPeakBpm: 174,
          setSampleCount: 5,
          sessionFloorBpm: 90,
          sessionPeakBpm: 175,
        ),
      );
      expect(result.confidence, lessThanOrEqualTo(EffortEstimator.maxEstimatedConfidence));
    });

    // The trend term alone cannot reach the outer clamp: z is already
    // clamped to ±2, so it contributes at most ±1.6 around the 8.0 anchor.
    // Driving calibrationOffset past the bound is what actually exercises
    // rpe.clamp — without it these assertions pass with the clamp removed.
    test('rpe is clamped to minRpe when the calibration offset drives it under',
        () {
      final result = estimator.estimate(
        set: _set(weight: 1, reps: 1),
        calibrationOffset: -50.0,
      );
      expect(result.rpe, EffortEstimator.minRpe);
    });

    test('rpe is clamped to maxRpe when the calibration offset drives it over',
        () {
      final result = estimator.estimate(
        set: _set(weight: 1, reps: 1),
        calibrationOffset: 50.0,
      );
      expect(result.rpe, EffortEstimator.maxRpe);
    });
  });
}
