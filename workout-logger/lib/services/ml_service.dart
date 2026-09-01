import 'dart:math';
import '../models/models.dart';
import 'interfaces/ml_service_interface.dart';
import 'strategies/growth_curve_fitter.dart';
import 'strategies/progression_rules.dart';
import 'utils/recovery_calculator.dart';

export 'interfaces/ml_service_interface.dart' show DataPoint, MuscleRecoveryStatus;
export 'strategies/growth_curve_fitter.dart' show IGrowthCurveFitter, GrowthCurveFitter;
export 'strategies/progression_rules.dart'
    show ProgressionContext, ProgressionRule, ProgressionRuleFactory;
export 'utils/recovery_calculator.dart' show RecoveryCalculator;

/// Growth modelling + double-progression recommendations + per-muscle
/// recovery scoring.
///
/// Growth-curve fitting and target-date projection are delegated to
/// [IGrowthCurveFitter] (see `strategies/growth_curve_fitter.dart`) and
/// recovery scoring to [RecoveryCalculator] (see `utils/recovery_calculator.dart`),
/// so this class only owns data extraction and the recommendation heuristics.
class MLService implements IMLService {
  final IGrowthCurveFitter _curveFitter;
  final RecoveryCalculator _recoveryCalculator;

  MLService({
    IGrowthCurveFitter? curveFitter,
    RecoveryCalculator? recoveryCalculator,
  })  : _curveFitter = curveFitter ?? GrowthCurveFitter(),
        _recoveryCalculator = recoveryCalculator ?? const RecoveryCalculator();

  // ==================== GROWTH MODEL ====================

  @override
  GrowthModel trainGrowthModel(List<DataPoint> dataPoints) =>
      _curveFitter.fit(dataPoints);

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
      final volumes = _recoveryCalculator.muscleVolumes(session, exerciseMap);
      final vol = volumes[muscleGroupId];
      if (vol == null || vol == 0) continue;
      firstDate ??= session.date;
      final days = session.date.difference(firstDate).inDays.toDouble();
      dataPoints.add(DataPoint(x: days, y: vol));
    }
    return dataPoints;
  }

  // ==================== RECOVERY ====================

  @override
  Map<String, MuscleRecoveryStatus> computeMuscleRecoveryScores(
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap, {
    DateTime? asOf,
  }) =>
      _recoveryCalculator.computeMuscleRecoveryScores(
        sessions,
        exerciseMap,
        asOf: asOf,
      );

  @override
  Map<String, DateTime> lastTrainedPerMuscle(
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap,
  ) =>
      _recoveryCalculator.lastTrainedPerMuscle(sessions, exerciseMap);

  @override
  Map<String, MuscleRecoveryStatus> recoveryScoresFrom(
    Map<String, DateTime> lastTrained, {
    DateTime? asOf,
  }) =>
      _recoveryCalculator.recoveryScoresFrom(lastTrained, asOf: asOf);

  // ==================== RECOMMENDATIONS ====================

  // Weekly relative growth thresholds (% of current volume per week).
  // Below _plateauWeeklyPct the curve is effectively flat; below
  // _declineWeeklyPct volume is genuinely regressing and a deload pays off.
  static const _plateauWeeklyPct = 0.5;
  static const _declineWeeklyPct = -2.0;
  static const _minR2ForTrendSignal = 0.2;

  // Deload detection thresholds: the last session counts as a deload when its
  // load drops below these fractions of the session before it.
  static const _deloadWeightThreshold = 0.85;
  static const _deloadVolumeThreshold = 0.70;
  // How recent the last session must be for a detected deload to still count
  // as "active" — see the isRecent comment below.
  static const _deloadRecencyWindowDays = 21;

  /// Double-progression with trend-, recovery-, readiness-, and
  /// same-session-fatigue-aware modulation.
  ///
  /// Priority order:
  ///   1. Under-recovered primary muscle → maintenance (hold weight & reps).
  ///   2. Post-deload recovery → re-anchor on the pre-deload baseline.
  ///   3. Low whole-day readiness → maintenance.
  ///   4. Heavy same-session fatigue (`sessionFatigueFactor` ≥ 1.0) → maintenance;
  ///      partial fatigue instead scales the weight-progression increment.
  ///   5. Decline (weekly growth < −2 %, trustworthy fit) → 10 % deload.
  ///   6. Plateau (weekly growth < 0.5 %, trustworthy fit) → maintenance.
  ///   7. reps ≥ maxReps → bump weight (fatigue-scaled), reset to minReps.
  ///   8. Otherwise → add 1 rep, hold weight.
  ///
  /// Trend checks use [GrowthModel.weeklyGrowthPercent] — growth relative to
  /// the lifter's current volume — so the same thresholds work for a 60 kg
  /// novice bench and a 10 t weekly squat volume.
  ///
  /// [sessionFatigueFactor] is a pre-computed 0.0–1.0 dampening factor from
  /// same-session earlier training (see `SessionFatigueAccumulator` —
  /// deliberately *not* attributed to specific muscles here: an exercise's
  /// hand-authored `muscleActivations` percentages proved untrustworthy for
  /// this — e.g. Seated Cable Row's own top muscle is "back" while Lat
  /// Pulldown/Pull-ups' is "lats", separate ids in this app's taxonomy, so
  /// per-muscle attribution silently missed real overlap between them).
  @override
  List<SetRecommendation> recommendSets({
    required List<WorkoutSet> lastSession,
    List<List<WorkoutSet>>? pastSessions,
    GrowthModel? growthModel,
    int minReps = 6,
    int maxReps = 12,
    Map<String, MuscleRecoveryStatus>? recoveryScores,
    List<String>? primaryMuscleIds,
    ReadinessBand? readinessBand,
    double sessionFatigueFactor = 0.0,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    if (lastSession.isEmpty && (pastSessions == null || pastSessions.isEmpty)) {
      return [];
    }

    // Determine target reference sets and deload status based on past 3 sessions trend
    List<WorkoutSet> refSets = lastSession.isNotEmpty
        ? lastSession
        : pastSessions?.firstWhere(
              (session) => session.isNotEmpty,
              orElse: () => const <WorkoutSet>[],
            ) ??
            const <WorkoutSet>[];
    bool isPostDeloadRecovery = false;

    if (pastSessions != null && pastSessions.length >= 2) {
      final s0 = pastSessions[0];
      final s1 = pastSessions[1];

      if (s0.isNotEmpty && s1.isNotEmpty) {
        // Use effective load (bodyweight − assist + extra for assisted-BW
        // sets), not raw set.weight, so assist changes on machines like
        // assisted dips/pull-ups aren't misread as a deload/progression.
        final w0 = s0.map((s) => s.effectiveWeight).reduce(max);
        final w1 = s1.map((s) => s.effectiveWeight).reduce(max);
        final v0 = s0.fold(0.0, (sum, s) => sum + s.volume);
        final v1 = s1.fold(0.0, (sum, s) => sum + s.volume);

        // Only treat this as "recovering from a deload" if the most recent
        // session (s0) is actually recent — otherwise an old, unrelated dip
        // between two stale sessions after a long break would be
        // misread as an active deload to recover from.
        final mostRecentTimestamp =
            s0.map((s) => s.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
        // Compare the full duration, not Duration.inDays: inDays truncates, so
        // a session 21 days and 23 hours old would still read as 21 and stay
        // inside the window.
        final isRecent = !now.isAfter(mostRecentTimestamp
            .add(const Duration(days: _deloadRecencyWindowDays)));

        // If the last session (s0) was a deload relative to the one before it
        if (isRecent &&
            ((w1 > 0 && w0 < w1 * _deloadWeightThreshold) ||
                (v1 > 0 && v0 < v1 * _deloadVolumeThreshold))) {
          refSets = s1;
          isPostDeloadRecovery = true;
        }
      }
    }

    if (refSets.isEmpty) refSets = lastSession;
    if (refSets.isEmpty) return [];

    final trendIsTrustworthy =
        growthModel != null && growthModel.r2 > _minR2ForTrendSignal;
    final weeklyPct = trendIsTrustworthy ? growthModel.weeklyGrowthPercent : null;
    final isDeclining = weeklyPct != null && weeklyPct < _declineWeeklyPct;
    final isPlateau =
        weeklyPct != null && !isDeclining && weeklyPct < _plateauWeeklyPct;

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

    final isLowReadiness = readinessBand == ReadinessBand.low;

    return refSets
        .map((set) => ProgressionRuleFactory.apply(ProgressionContext(
              set: set,
              minReps: minReps,
              maxReps: maxReps,
              isPlateau: isPlateau,
              isDeclining: isDeclining,
              isUnderRecovered: isUnderRecovered,
              recoveryPercent: worstRecovery,
              isPostDeloadRecovery: isPostDeloadRecovery,
              isLowReadiness: isLowReadiness,
              sessionFatigueFactor: sessionFatigueFactor,
            )))
        .toList();
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

  @override
  DateTime? predictTargetCompletion({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
  }) =>
      _curveFitter.predictTargetCompletion(
        currentValue: currentValue,
        targetValue: targetValue,
        growthModel: growthModel,
      );
}
