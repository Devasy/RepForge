import '../../models/models.dart';

/// Data point for ML training.
class DataPoint {
  final double x; // Days since first session (time-based)
  final double y; // Volume or performance metric

  DataPoint({required this.x, required this.y});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataPoint &&
        other.runtimeType == runtimeType &&
        other.x == x &&
        other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

/// Per-muscle recovery state estimated by the exponential decay model.
class MuscleRecoveryStatus {
  final String muscleGroupId;

  /// 0.0 = just trained (fully fatigued), 1.0 = fully recovered.
  final double recoveryFraction;

  final Duration timeSinceLastTrained;

  /// How long until the muscle reaches ~95 % recovery (null = already there).
  final Duration? estimatedTimeToFullRecovery;

  const MuscleRecoveryStatus({
    required this.muscleGroupId,
    required this.recoveryFraction,
    required this.timeSinceLastTrained,
    this.estimatedTimeToFullRecovery,
  });

  /// ≥ 90 % — safe to train hard.
  bool get isRecovered => recoveryFraction >= 0.90;

  /// < 70 % — still meaningfully fatigued; back off load.
  bool get isUnderRecovered => recoveryFraction < 0.70;

  int get recoveryPercent => (recoveryFraction * 100).round();
}

/// Abstract interface for ML operations.
abstract class IMLService {
  /// Train a growth model using data points.
  GrowthModel trainGrowthModel(List<DataPoint> dataPoints);

  /// Extract per-exercise data points (x = days since first session, y = volume).
  List<DataPoint> extractExerciseDataPoints(
    String exerciseId,
    List<WorkoutSession> sessions,
  );

  /// Extract per-muscle aggregate data points for the growth model.
  /// y = sum of exercise volumes weighted by [MuscleActivation.activationPercentage].
  List<DataPoint> extractMuscleDataPoints(
    String muscleGroupId,
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap,
  );

  /// Compute recovery status for every muscle group that appears in [sessions].
  /// Uses an exponential decay model: recovery = 1 − exp(−t / τ).
  Map<String, MuscleRecoveryStatus> computeMuscleRecoveryScores(
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap, {
    DateTime? asOf,
  });

  /// Get recommended sets based on last session, recent-session trend, and growth model.
  /// [pastSessions], if provided, only has its first two entries read for
  /// deload/recovery detection: index 0 is the latest prior session, index 1
  /// is the session immediately before that. Any further entries are ignored.
  /// [minReps]/[maxReps] define the double-progression rep range.
  /// Pass [recoveryScores] + [primaryMuscleIds] for recovery-aware advice.
  List<SetRecommendation> recommendSets({
    required List<WorkoutSet> lastSession,
    List<List<WorkoutSet>>? pastSessions,
    GrowthModel? growthModel,
    int minReps = 6,
    int maxReps = 12,
    Map<String, MuscleRecoveryStatus>? recoveryScores,
    List<String>? primaryMuscleIds,
  });

  /// Get default recommendations when no history exists.
  List<SetRecommendation> getDefaultRecommendations(int setCount);

  /// Predict when a target will be completed based on growth model.
  DateTime? predictTargetCompletion({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
  });
}
