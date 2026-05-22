import 'dart:math';
import '../models/models.dart';
import 'interfaces/ml_service_interface.dart';

export 'interfaces/ml_service_interface.dart' show DataPoint, MuscleRecoveryStatus;

/// Exponentially-weighted linear regression + double-progression recommendations
/// + per-muscle recovery scoring.
class MLService implements IMLService {
  // Decay constant for recency weights. At λ=0.15, a session 10 sessions ago
  // carries exp(−1.5) ≈ 22 % of the weight of the most recent session.
  static const _lambda = 0.15;

  // Recovery time constants τ (hours) per muscle group.
  // Full recovery (~95 %) occurs at ≈ 3τ.
  static const _tauHours = <String, double>{
    'chest': 48.0,
    'back': 60.0,
    'lats': 60.0,
    'quads': 60.0,
    'hamstrings': 60.0,
    'glutes': 60.0,
    'legs': 60.0,
    'shoulders': 40.0,
    'traps': 40.0,
    'biceps': 36.0,
    'triceps': 36.0,
    'abs': 24.0,
    'core': 24.0,
    'calves': 24.0,
    'forearms': 24.0,
  };
  static const _defaultTauHours = 48.0;

  /// Per-muscle recovery time constants τ (hours), exposed so callers outside
  /// this service (e.g. the agent data mirror) can recompute the decay model
  /// `1 − exp(−t/τ)` themselves at query time.
  static Map<String, double> get recoveryTimeConstantsHours => _tauHours;

  /// τ used for muscle groups absent from [recoveryTimeConstantsHours].
  static double get defaultRecoveryTimeConstantHours => _defaultTauHours;

  // ==================== GROWTH MODEL ====================

  @override
  GrowthModel trainGrowthModel(List<DataPoint> dataPoints) {
    return MLService.trainGrowthModelStatic(dataPoints);
  }

  /// Exponentially-weighted least squares.
  /// Weight for point i (0-indexed, n total): exp(−λ · (n−1−i)).
  static GrowthModel trainGrowthModelStatic(List<DataPoint> dataPoints) {
    if (dataPoints.isEmpty) {
      return GrowthModel(slope: 0, intercept: 0, r2: 0, lastTrained: DateTime.now());
    }
    if (dataPoints.length == 1) {
      return GrowthModel(
        slope: 0,
        intercept: dataPoints.first.y,
        r2: 1,
        lastTrained: DateTime.now(),
      );
    }

    final n = dataPoints.length;
    final weights = List.generate(n, (i) => exp(-_lambda * (n - 1 - i)));
    final wSum = weights.fold(0.0, (s, w) => s + w);

    double wSumX = 0, wSumY = 0, wSumXY = 0, wSumX2 = 0;
    for (var i = 0; i < n; i++) {
      final w = weights[i];
      final x = dataPoints[i].x;
      final y = dataPoints[i].y;
      wSumX += w * x;
      wSumY += w * y;
      wSumXY += w * x * y;
      wSumX2 += w * x * x;
    }

    final denom = wSum * wSumX2 - wSumX * wSumX;
    if (denom == 0) {
      return GrowthModel(slope: 0, intercept: wSumY / wSum, r2: 0, lastTrained: DateTime.now());
    }

    final slope = (wSum * wSumXY - wSumX * wSumY) / denom;
    final intercept = (wSumY - slope * wSumX) / wSum;

    final yBar = wSumY / wSum;
    double ssTotal = 0, ssResidual = 0;
    for (var i = 0; i < n; i++) {
      final w = weights[i];
      final predicted = slope * dataPoints[i].x + intercept;
      ssTotal += w * pow(dataPoints[i].y - yBar, 2);
      ssResidual += w * pow(dataPoints[i].y - predicted, 2);
    }

    final r2 = ssTotal > 0 ? (1 - ssResidual / ssTotal).toDouble() : 0.0;
    return GrowthModel(
      slope: slope,
      intercept: intercept,
      r2: r2.clamp(0.0, 1.0),
      lastTrained: DateTime.now(),
    );
  }

  // ==================== DATA EXTRACTION ====================

  /// x = days since first session for this exercise, y = total volume.
  @override
  List<DataPoint> extractExerciseDataPoints(
    String exerciseId,
    List<WorkoutSession> sessions,
  ) {
    final dataPoints = <DataPoint>[];
    final sorted = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    DateTime? firstDate;
    for (final session in sorted) {
      for (final log in session.exercises) {
        if (log.exerciseId == exerciseId) {
          firstDate ??= session.date;
          final days = session.date.difference(firstDate).inDays.toDouble();
          dataPoints.add(DataPoint(x: days, y: log.totalVolume));
          break;
        }
      }
    }
    return dataPoints;
  }

  /// x = days since first session training this muscle,
  /// y = effective volume = sum(exerciseVolume × activationPercentage / 100).
  @override
  List<DataPoint> extractMuscleDataPoints(
    String muscleGroupId,
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap,
  ) {
    final sorted = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    final dataPoints = <DataPoint>[];
    DateTime? firstDate;

    for (final session in sorted) {
      final volumes = _muscleVolumes(session, exerciseMap);
      final vol = volumes[muscleGroupId];
      if (vol == null || vol == 0) continue;
      firstDate ??= session.date;
      final days = session.date.difference(firstDate).inDays.toDouble();
      dataPoints.add(DataPoint(x: days, y: vol));
    }
    return dataPoints;
  }

  // ==================== RECOVERY ====================

  /// Compute recovery scores for every muscle group trained in [sessions].
  ///
  /// Model: recovery(t) = 1 − exp(−t / τ)
  ///   t   = hours since last session that trained this muscle
  ///   τ   = muscle-specific time constant (see [_tauHours])
  ///
  /// Full recovery (≥ 95 %) occurs around t = 3τ.
  @override
  Map<String, MuscleRecoveryStatus> computeMuscleRecoveryScores(
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final sorted = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Walk sessions forward — each one updates the "last trained" record.
    final lastTrained = <String, DateTime>{};
    for (final session in sorted) {
      for (final muscleId in _muscleVolumes(session, exerciseMap).keys) {
        lastTrained[muscleId] = session.date;
      }
    }

    final result = <String, MuscleRecoveryStatus>{};
    for (final entry in lastTrained.entries) {
      final muscleId = entry.key;
      final tau = _tauHours[muscleId] ?? _defaultTauHours;
      final hours = now.difference(entry.value).inMinutes / 60.0;
      final fraction = (1.0 - exp(-hours / tau)).clamp(0.0, 1.0);
      // 95 % recovery ≈ 3τ; remaining = 3τ − elapsed.
      final hoursRemaining = tau * 3 - hours;

      result[muscleId] = MuscleRecoveryStatus(
        muscleGroupId: muscleId,
        recoveryFraction: fraction,
        timeSinceLastTrained: Duration(minutes: (hours * 60).round()),
        estimatedTimeToFullRecovery: hoursRemaining > 0
            ? Duration(minutes: (hoursRemaining * 60).round())
            : null,
      );
    }
    return result;
  }

  /// Effective volume per muscle group for one session.
  static Map<String, double> _muscleVolumes(
    WorkoutSession session,
    Map<String, Exercise> exerciseMap,
  ) {
    final volumes = <String, double>{};
    for (final log in session.exercises) {
      final exercise = exerciseMap[log.exerciseId];
      if (exercise == null) continue;
      final total = log.totalVolume;
      for (final activation in exercise.muscleActivations) {
        volumes[activation.muscleGroupId] =
            (volumes[activation.muscleGroupId] ?? 0.0) +
                total * activation.activationPercentage / 100.0;
      }
    }
    return volumes;
  }

  // ==================== RECOMMENDATIONS ====================

  /// Double-progression with optional recovery awareness.
  ///
  /// Priority order:
  ///   1. Under-recovered primary muscle → maintenance (hold weight & reps).
  ///   2. Plateau (model slope ≤ 0, R² > 0.25) → maintenance.
  ///   3. reps ≥ maxReps → bump weight, reset to minReps.
  ///   4. Otherwise → add 1 rep, hold weight.
  @override
  List<SetRecommendation> recommendSets({
    required List<WorkoutSet> lastSession,
    GrowthModel? growthModel,
    int minReps = 6,
    int maxReps = 12,
    Map<String, MuscleRecoveryStatus>? recoveryScores,
    List<String>? primaryMuscleIds,
  }) {
    if (lastSession.isEmpty) return [];

    final isPlateau = growthModel != null &&
        growthModel.slope <= 0 &&
        growthModel.r2 > 0.25;

    final isUnderRecovered = primaryMuscleIds != null &&
        recoveryScores != null &&
        primaryMuscleIds.any((m) => recoveryScores[m]?.isUnderRecovered ?? false);

    final worstRecovery = isUnderRecovered
        ? primaryMuscleIds
            .map((m) => recoveryScores[m])
            .whereType<MuscleRecoveryStatus>()
            .map((s) => s.recoveryPercent)
            .fold(100, (a, b) => a < b ? a : b)
        : null;

    return lastSession
        .map((set) => _doubleProgression(
              set: set,
              minReps: minReps,
              maxReps: maxReps,
              isPlateau: isPlateau,
              isUnderRecovered: isUnderRecovered,
              recoveryPercent: worstRecovery,
            ))
        .toList();
  }

  static SetRecommendation _doubleProgression({
    required WorkoutSet set,
    required int minReps,
    required int maxReps,
    required bool isPlateau,
    required bool isUnderRecovered,
    int? recoveryPercent,
  }) {
    if (isUnderRecovered) {
      return SetRecommendation(
        weight: set.weight,
        reps: set.reps,
        confidence: 'low',
        reasoning:
            'Muscle only $recoveryPercent% recovered — maintain load, skip progression',
      );
    }

    if (isPlateau) {
      return SetRecommendation(
        weight: set.weight,
        reps: set.reps,
        confidence: 'medium',
        reasoning: 'Plateau detected — maintain load and focus on form quality',
      );
    }

    if (set.reps >= maxReps) {
      final increment = set.weight < 40 ? 2.5 : 5.0;
      return SetRecommendation(
        weight: set.weight + increment,
        reps: minReps,
        confidence: 'high',
        reasoning: 'Rep target hit — add ${increment}kg and reset to $minReps reps',
      );
    }

    return SetRecommendation(
      weight: set.weight,
      reps: set.reps + 1,
      confidence: 'high',
      reasoning: 'Add 1 rep (${set.reps + 1}/$maxReps) — progressive overload',
    );
  }

  /// Fill in default recommendations when no history exists.
  @override
  List<SetRecommendation> getDefaultRecommendations(int setCount) {
    return List.generate(
      setCount,
      (_) => SetRecommendation(
        weight: 0,
        reps: 10,
        confidence: 'low',
        reasoning: 'No previous data — adjust based on feel',
      ),
    );
  }

  // ==================== TARGET PREDICTIONS ====================

  /// Slope is volume/day (x = days since first session).
  @override
  DateTime? predictTargetCompletion({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
    double sessionsPerWeek = 3.0,
  }) {
    if (currentValue >= targetValue) return DateTime.now();
    if (growthModel.slope <= 0) return null;
    final days = ((targetValue - currentValue) / growthModel.slope).ceil();
    return DateTime.now().add(Duration(days: days));
  }

  /// Confidence interval around the predicted completion date.
  static ({DateTime optimistic, DateTime expected, DateTime pessimistic})?
      predictTargetWithConfidence({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
    double sessionsPerWeek = 3.0,
  }) {
    final expected = MLService().predictTargetCompletion(
      currentValue: currentValue,
      targetValue: targetValue,
      growthModel: growthModel,
      sessionsPerWeek: sessionsPerWeek,
    );
    if (expected == null) return null;

    final daysToTarget = expected.difference(DateTime.now()).inDays;
    final uncertainty = ((1 - growthModel.r2) * daysToTarget * 0.5).ceil();
    return (
      optimistic: expected.subtract(Duration(days: uncertainty)),
      expected: expected,
      pessimistic: expected.add(Duration(days: uncertainty)),
    );
  }
}
