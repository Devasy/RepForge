import 'dart:math';
import '../models/models.dart';
import 'interfaces/ml_service_interface.dart';

export 'interfaces/ml_service_interface.dart' show DataPoint, MuscleRecoveryStatus;

/// Growth modelling + double-progression recommendations + per-muscle
/// recovery scoring.
///
/// Growth model: exponentially-weighted least squares fit of two candidate
/// curves — linear and logarithmic (saturating) — each refined with one
/// robust (Tukey bisquare) re-weighting pass so single outlier sessions
/// (deloads, cut-short workouts) don't tilt the trend. The better-fitting
/// curve wins; the logarithmic form captures the diminishing returns real
/// muscle growth follows, which a straight line systematically overshoots.
class MLService implements IMLService {
  // Decay constant for recency weights. At λ=0.15, a session 10 sessions ago
  // carries exp(−1.5) ≈ 22 % of the weight of the most recent session.
  static const _lambda = 0.15;

  // Logarithmic candidate is considered only with enough history for
  // curvature to be identifiable; over short spans log ≈ linear.
  static const _minPointsForLogCurve = 6;
  static const _minSpanDaysForLogCurve = 14.0;

  // The log curve must beat linear by this fraction of weighted RSS to win,
  // preventing flip-flopping between near-identical fits.
  static const _logSelectionMargin = 0.02;

  // Robust pass: points beyond c·σ̂ get fully rejected by Tukey's bisquare.
  static const _tukeyC = 4.685;
  static const _minPointsForRobustPass = 5;

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

  // ==================== GROWTH MODEL ====================

  @override
  GrowthModel trainGrowthModel(List<DataPoint> dataPoints) {
    return MLService.trainGrowthModelStatic(dataPoints);
  }

  /// Fits linear and logarithmic candidates with exponential recency weights
  /// (weight for point i of n: exp(−λ·(n−1−i))) plus one robust re-weighting
  /// pass each, then selects the better curve by weighted residual error.
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
        lastX: dataPoints.first.x,
      );
    }

    final n = dataPoints.length;
    final recency = List.generate(n, (i) => exp(-_lambda * (n - 1 - i)));
    final xs = dataPoints.map((p) => p.x).toList();
    final ys = dataPoints.map((p) => p.y).toList();
    final lastX = xs.reduce(max);
    final spanDays = lastX - xs.reduce(min);

    final linear = _robustWeightedFit(xs, ys, recency);

    _Fit? logFit;
    if (n >= _minPointsForLogCurve && spanDays >= _minSpanDaysForLogCurve) {
      final logXs = xs.map((x) => log(1 + max(0.0, x))).toList();
      logFit = _robustWeightedFit(logXs, ys, recency);
    }

    final useLog = logFit != null &&
        logFit.rss < linear.rss * (1 - _logSelectionMargin);
    final fit = useLog ? logFit : linear;
    final curve = useLog ? GrowthCurve.logarithmic : GrowthCurve.linear;

    // Instantaneous daily rate at the newest point: d/dx [a + b·ln(1+x)].
    final slope = useLog ? fit.slope / (1 + lastX) : fit.slope;

    return GrowthModel(
      slope: slope,
      intercept: fit.intercept,
      r2: fit.r2.clamp(0.0, 1.0),
      lastTrained: DateTime.now(),
      curve: curve,
      coefficient: fit.slope,
      lastX: lastX,
      stdError: fit.stdError,
    );
  }

  /// Weighted least squares with one Tukey-bisquare re-weighting pass.
  ///
  /// The robust pass estimates residual scale via the weighted MAD, then
  /// refits with outliers down-weighted by (1 − (r/cσ̂)²)², so a single
  /// deload or cut-short session cannot tilt the trend. Skipped for tiny
  /// samples or when residuals are too uniform to identify outliers.
  static _Fit _robustWeightedFit(
    List<double> xs,
    List<double> ys,
    List<double> recency,
  ) {
    var fit = _weightedLeastSquares(xs, ys, recency);

    if (xs.length < _minPointsForRobustPass) return fit;

    final residuals = [
      for (var i = 0; i < xs.length; i++)
        (ys[i] - (fit.intercept + fit.slope * xs[i])).abs(),
    ];
    final mad = _median(residuals);
    if (mad <= 0) return fit;
    final scale = 1.4826 * mad; // MAD → σ̂ for normal residuals

    final robust = <double>[];
    for (var i = 0; i < xs.length; i++) {
      final u = residuals[i] / (_tukeyC * scale);
      final tukey = u >= 1 ? 0.0 : pow(1 - u * u, 2).toDouble();
      robust.add(recency[i] * tukey);
    }
    // Refit only if the pass actually rejected/damped something and enough
    // effective weight survives to keep the fit identifiable.
    final kept = robust.where((w) => w > 0).length;
    if (kept < 3) return fit;
    final refit = _weightedLeastSquares(xs, ys, robust);
    return refit.degenerate ? fit : refit;
  }

  static _Fit _weightedLeastSquares(
    List<double> xs,
    List<double> ys,
    List<double> weights,
  ) {
    final n = xs.length;
    final wSum = weights.fold(0.0, (s, w) => s + w);

    double wSumX = 0, wSumY = 0, wSumXY = 0, wSumX2 = 0;
    for (var i = 0; i < n; i++) {
      final w = weights[i];
      wSumX += w * xs[i];
      wSumY += w * ys[i];
      wSumXY += w * xs[i] * ys[i];
      wSumX2 += w * xs[i] * xs[i];
    }

    final denom = wSum * wSumX2 - wSumX * wSumX;
    if (denom.abs() < 1e-12 || wSum <= 0) {
      final mean = wSum > 0 ? wSumY / wSum : 0.0;
      return _Fit(
        slope: 0,
        intercept: mean,
        r2: 0,
        rss: double.infinity,
        stdError: 0,
        degenerate: true,
      );
    }

    final slope = (wSum * wSumXY - wSumX * wSumY) / denom;
    final intercept = (wSumY - slope * wSumX) / wSum;

    final yBar = wSumY / wSum;
    double ssTotal = 0, ssResidual = 0, wSqSum = 0;
    for (var i = 0; i < n; i++) {
      final w = weights[i];
      final predicted = slope * xs[i] + intercept;
      ssTotal += w * pow(ys[i] - yBar, 2);
      ssResidual += w * pow(ys[i] - predicted, 2);
      wSqSum += w * w;
    }

    // Weighted mean squared residual, dof-corrected via the Kish effective
    // sample size (recency weights make n optimistic).
    final nEff = wSqSum > 0 ? (wSum * wSum) / wSqSum : 0.0;
    final dof = max(1.0, nEff - 2);
    final stdError = sqrt(max(0.0, ssResidual / wSum) * (nEff / dof));

    return _Fit(
      slope: slope,
      intercept: intercept,
      r2: ssTotal > 0 ? (1 - ssResidual / ssTotal).toDouble() : 0.0,
      rss: ssResidual,
      stdError: stdError,
      degenerate: false,
    );
  }

  static double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
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

  // Weekly relative growth thresholds (% of current volume per week).
  // Below _plateauWeeklyPct the curve is effectively flat; below
  // _declineWeeklyPct volume is genuinely regressing and a deload pays off.
  static const _plateauWeeklyPct = 0.5;
  static const _declineWeeklyPct = -2.0;
  static const _minR2ForTrendSignal = 0.2;

  /// Double-progression with trend- and recovery-aware modulation.
  ///
  /// Priority order:
  ///   1. Under-recovered primary muscle → maintenance (hold weight & reps).
  ///   2. Decline (weekly growth < −2 %, trustworthy fit) → 10 % deload.
  ///   3. Plateau (weekly growth < 0.5 %, trustworthy fit) → maintenance.
  ///   4. reps ≥ maxReps → bump weight, reset to minReps.
  ///   5. Otherwise → add 1 rep, hold weight.
  ///
  /// Trend checks use [GrowthModel.weeklyGrowthPercent] — growth relative to
  /// the lifter's current volume — so the same thresholds work for a 60 kg
  /// novice bench and a 10 t weekly squat volume.
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

    return lastSession
        .map((set) => _doubleProgression(
              set: set,
              minReps: minReps,
              maxReps: maxReps,
              isPlateau: isPlateau,
              isDeclining: isDeclining,
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
    required bool isDeclining,
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

    if (isDeclining) {
      // Round the deload to the plate increment users can actually load.
      final deloaded = max(0.0, ((set.weight * 0.9) / 2.5).round() * 2.5);
      return SetRecommendation(
        weight: deloaded,
        reps: set.reps,
        confidence: 'medium',
        reasoning:
            'Volume trending down — deload ~10% for a session or two, then rebuild',
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

  // Predictions further out than this are noise, not information.
  static const _maxPredictionDays = 365 * 2;

  /// Projects the fitted curve forward to the target (x = days).
  ///
  /// Linear fits extrapolate at the constant rate; logarithmic fits invert
  /// the curve, so the flattening trajectory honestly pushes the date out
  /// instead of promising linear gains forever. Predictions beyond two years
  /// return null — too uncertain to show.
  @override
  DateTime? predictTargetCompletion({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
    double sessionsPerWeek = 3.0,
  }) {
    if (currentValue >= targetValue) return DateTime.now();
    if (growthModel.slope <= 0) return null;

    final double daysFromNow;
    switch (growthModel.curve) {
      case GrowthCurve.linear:
        daysFromNow = (targetValue - currentValue) / growthModel.slope;
      case GrowthCurve.logarithmic:
        // Map the live current value and the target through the curve's
        // inverse x(y) = exp((y−a)/b) − 1 and take the day difference, so
        // drift between the live value and the fitted curve cancels out.
        final b = growthModel.coefficient;
        if (b <= 0) return null;
        final xTarget = exp((targetValue - growthModel.intercept) / b) - 1;
        final xCurrent = exp((currentValue - growthModel.intercept) / b) - 1;
        daysFromNow = xTarget - xCurrent;
    }

    if (daysFromNow <= 0) return DateTime.now();
    if (!daysFromNow.isFinite || daysFromNow > _maxPredictionDays) return null;
    return DateTime.now().add(Duration(days: daysFromNow.ceil()));
  }

  /// Confidence interval around the predicted completion date.
  ///
  /// Width comes from the model's residual standard error converted to days
  /// at the current growth rate (± how long the typical session-to-session
  /// scatter could shift the crossing point), falling back to an R²-scaled
  /// margin for legacy models without a stored error.
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
    final int uncertainty;
    if (growthModel.stdError > 0 && growthModel.slope > 0) {
      uncertainty = (growthModel.stdError / growthModel.slope)
          .ceil()
          .clamp(0, max(1, daysToTarget));
    } else {
      uncertainty = ((1 - growthModel.r2) * daysToTarget * 0.5).ceil();
    }
    return (
      optimistic: expected.subtract(Duration(days: uncertainty)),
      expected: expected,
      pessimistic: expected.add(Duration(days: uncertainty)),
    );
  }
}

/// Internal weighted-least-squares result for one candidate curve.
class _Fit {
  final double slope;
  final double intercept;
  final double r2;
  final double rss; // weighted residual sum of squares (selection criterion)
  final double stdError;
  final bool degenerate;

  const _Fit({
    required this.slope,
    required this.intercept,
    required this.r2,
    required this.rss,
    required this.stdError,
    required this.degenerate,
  });
}
