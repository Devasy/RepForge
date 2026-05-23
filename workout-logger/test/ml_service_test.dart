import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/ml_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

DataPoint dp(double x, double y) => DataPoint(x: x, y: y);

WorkoutSet wset({double weight = 60.0, int reps = 10}) =>
    WorkoutSet(weight: weight, reps: reps);

Exercise makeExercise(String id, String muscleId) => Exercise(
      id: id,
      name: id,
      category: 'compound',
      muscleActivations: [
        MuscleActivation(muscleGroupId: muscleId, activationPercentage: 100),
      ],
    );

WorkoutSession makeSession({
  required String id,
  required DateTime date,
  required String exerciseId,
  required String muscleId,
  double weight = 60.0,
  int reps = 10,
}) {
  return WorkoutSession(
    id: id,
    date: date,
    exercises: [
      ExerciseLog(
        exerciseId: exerciseId,
        sets: [wset(weight: weight, reps: reps)],
      ),
    ],
    duration: 45,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  final ml = MLService();

  group('MLService - trainGrowthModel', () {
    test('empty data returns zero-slope model', () {
      final model = ml.trainGrowthModel([]);
      expect(model.slope, 0.0);
      expect(model.intercept, 0.0);
      expect(model.r2, 0.0);
    });

    test('single data point returns zero-slope model with intercept = y', () {
      final model = ml.trainGrowthModel([dp(0, 500)]);
      expect(model.slope, closeTo(0.0, 0.001));
      expect(model.intercept, closeTo(500.0, 0.001));
    });

    test('perfect linear data yields r2 close to 1.0', () {
      // y = 10x + 100 → perfect linear
      final points = List.generate(8, (i) => dp(i.toDouble(), 100 + 10.0 * i));
      final model = ml.trainGrowthModel(points);
      expect(model.r2, closeTo(1.0, 0.01));
    });

    test('constant data yields slope close to 0', () {
      final points = List.generate(5, (i) => dp(i.toDouble(), 200.0));
      final model = ml.trainGrowthModel(points);
      expect(model.slope.abs(), lessThan(0.001));
    });

    test('positive-trending data produces positive slope', () {
      final points = [dp(0, 100), dp(1, 110), dp(2, 120), dp(3, 130)];
      final model = ml.trainGrowthModel(points);
      expect(model.slope, greaterThan(0));
    });

    test('r2 is clamped between 0 and 1', () {
      final points = [dp(0, 100), dp(1, 90), dp(2, 110), dp(3, 80)];
      final model = ml.trainGrowthModel(points);
      expect(model.r2, greaterThanOrEqualTo(0.0));
      expect(model.r2, lessThanOrEqualTo(1.0));
    });

    test('predict(n) = slope * n + intercept', () {
      final points = List.generate(6, (i) => dp(i.toDouble(), 100 + 5.0 * i));
      final model = ml.trainGrowthModel(points);
      // With near-perfect linear data predict should be close to the formula
      final expected = model.slope * 3 + model.intercept;
      expect(model.predict(3), closeTo(expected, 0.001));
    });
  });

  group('MLService - recommendSets', () {
    test('empty lastSession returns empty list', () {
      final recs = ml.recommendSets(lastSession: []);
      expect(recs, isEmpty);
    });

    test('reps below maxReps → add one rep, keep weight', () {
      final set = wset(weight: 60.0, reps: 10);
      final recs = ml.recommendSets(lastSession: [set], maxReps: 12);
      expect(recs.first.reps, 11);
      expect(recs.first.weight, closeTo(60.0, 0.001));
      expect(recs.first.confidence, 'high');
    });

    test('reps at maxReps → increase weight by 2.5 kg when weight < 40', () {
      final set = wset(weight: 30.0, reps: 12);
      final recs = ml.recommendSets(lastSession: [set], minReps: 6, maxReps: 12);
      expect(recs.first.weight, closeTo(32.5, 0.001));
      expect(recs.first.reps, 6);
    });

    test('reps at maxReps → increase weight by 5 kg when weight >= 40', () {
      final set = wset(weight: 80.0, reps: 12);
      final recs = ml.recommendSets(lastSession: [set], minReps: 6, maxReps: 12);
      expect(recs.first.weight, closeTo(85.0, 0.001));
      expect(recs.first.reps, 6);
    });

    test('plateau detected → holds weight and reps (medium confidence)', () {
      final set = wset(weight: 60.0, reps: 10);
      final plateauModel = GrowthModel(
        slope: -0.5,
        intercept: 600.0,
        r2: 0.8,
        lastTrained: DateTime.now(),
      );
      final recs = ml.recommendSets(
        lastSession: [set],
        growthModel: plateauModel,
        maxReps: 12,
      );
      expect(recs.first.weight, closeTo(60.0, 0.001));
      expect(recs.first.reps, 10);
      expect(recs.first.confidence, 'medium');
    });

    test('under-recovered muscle → maintenance recommendation (low confidence)',
        () {
      final set = wset(weight: 80.0, reps: 8);
      final recovery = MuscleRecoveryStatus(
        muscleGroupId: 'chest',
        recoveryFraction: 0.4, // 40% recovered
        timeSinceLastTrained: const Duration(hours: 24),
        estimatedTimeToFullRecovery: const Duration(hours: 72),
      );
      final recs = ml.recommendSets(
        lastSession: [set],
        recoveryScores: {'chest': recovery},
        primaryMuscleIds: ['chest'],
        maxReps: 12,
      );
      expect(recs.first.weight, closeTo(80.0, 0.001));
      expect(recs.first.reps, 8);
      expect(recs.first.confidence, 'low');
    });

    test('produces one recommendation per set in lastSession', () {
      final sets = [wset(weight: 60.0, reps: 10), wset(weight: 60.0, reps: 9)];
      final recs = ml.recommendSets(lastSession: sets, maxReps: 12);
      expect(recs.length, 2);
    });
  });

  group('MLService - getDefaultRecommendations', () {
    test('returns the requested number of default recommendations', () {
      final recs = ml.getDefaultRecommendations(3);
      expect(recs.length, 3);
    });

    test('default recommendations have low confidence and zero weight', () {
      final recs = ml.getDefaultRecommendations(2);
      expect(recs.every((r) => r.confidence == 'low'), isTrue);
      expect(recs.every((r) => r.weight == 0), isTrue);
    });
  });

  group('MLService - predictTargetCompletion', () {
    test('returns null when slope is zero', () {
      final model = GrowthModel(
        slope: 0.0,
        intercept: 100.0,
        r2: 0.0,
        lastTrained: DateTime.now(),
      );
      final result = ml.predictTargetCompletion(
        currentValue: 100.0,
        targetValue: 200.0,
        growthModel: model,
      );
      expect(result, isNull);
    });

    test('returns null when slope is negative', () {
      final model = GrowthModel(
        slope: -1.0,
        intercept: 200.0,
        r2: 0.5,
        lastTrained: DateTime.now(),
      );
      final result = ml.predictTargetCompletion(
        currentValue: 100.0,
        targetValue: 200.0,
        growthModel: model,
      );
      expect(result, isNull);
    });

    test('returns a future date when slope > 0 and target > current', () {
      final model = GrowthModel(
        slope: 5.0,
        intercept: 100.0,
        r2: 0.9,
        lastTrained: DateTime.now(),
      );
      final result = ml.predictTargetCompletion(
        currentValue: 100.0,
        targetValue: 200.0,
        growthModel: model,
      );
      expect(result, isNotNull);
      expect(result!.isAfter(DateTime.now()), isTrue);
    });

    test('returns now (not null) when current already meets target', () {
      final model = GrowthModel(
        slope: 5.0,
        intercept: 100.0,
        r2: 0.9,
        lastTrained: DateTime.now(),
      );
      final result = ml.predictTargetCompletion(
        currentValue: 200.0,
        targetValue: 200.0,
        growthModel: model,
      );
      expect(result, isNotNull);
    });
  });

  group('MLService - computeMuscleRecoveryScores', () {
    final chestExercise = makeExercise('bench_press', 'chest');
    final exerciseMap = {'bench_press': chestExercise};

    test('returns empty map when sessions is empty', () {
      final scores = ml.computeMuscleRecoveryScores([], exerciseMap);
      expect(scores, isEmpty);
    });

    test('muscle trained just now has low recoveryFraction', () {
      final now = DateTime.now();
      final session = makeSession(
        id: 's1',
        date: now,
        exerciseId: 'bench_press',
        muscleId: 'chest',
      );
      final scores = ml.computeMuscleRecoveryScores(
        [session],
        exerciseMap,
        asOf: now,
      );
      expect(scores['chest'], isNotNull);
      // At t=0, recovery = 1 - exp(0) = 0
      expect(scores['chest']!.recoveryFraction, closeTo(0.0, 0.05));
    });

    test('muscle trained 7 days ago is near fully recovered', () {
      final asOf = DateTime.now();
      final sevenDaysAgo = asOf.subtract(const Duration(days: 7));
      final session = makeSession(
        id: 's1',
        date: sevenDaysAgo,
        exerciseId: 'bench_press',
        muscleId: 'chest',
      );
      final scores = ml.computeMuscleRecoveryScores(
        [session],
        exerciseMap,
        asOf: asOf,
      );
      // chest τ=48h; 168h elapsed → 1 - exp(-168/48) ≈ 0.97
      expect(scores['chest']!.recoveryFraction, greaterThan(0.9));
    });

    test('exercises absent from exerciseMap produce no recovery entry', () {
      final session = makeSession(
        id: 's1',
        date: DateTime.now().subtract(const Duration(hours: 12)),
        exerciseId: 'unknown_exercise',
        muscleId: 'chest',
      );
      final scores = ml.computeMuscleRecoveryScores(
        [session],
        {}, // empty map — exercise not found
      );
      expect(scores, isEmpty);
    });

    test('isRecovered is false for a muscle trained very recently', () {
      final now = DateTime.now();
      final session = makeSession(
        id: 's1',
        date: now,
        exerciseId: 'bench_press',
        muscleId: 'chest',
      );
      final scores = ml.computeMuscleRecoveryScores(
        [session],
        exerciseMap,
        asOf: now,
      );
      // recoveryFraction ≈ 0 → well below the 95% isRecovered threshold
      expect(scores['chest']!.isRecovered, isFalse);
    });
  });
}
