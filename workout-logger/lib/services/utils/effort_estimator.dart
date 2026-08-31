// Effort Estimator (no per-set user input)
//
// Estimates a 0-10 RPE (rate of perceived exertion) for a set from data
// already logged, so the recommendation engine can distinguish an easy top
// set from a grinder without ever asking the user mid-set. Four additive
// terms on top of an RPE-8 anchor (double progression already assumes
// near-failure working sets):
//
//   1. Trend deviation   — actual volume vs. the growth model's prediction.
//   2. Session decline   — volume dropping across sets of the same exercise
//                           today (dropset/fatigue signal).
//   3. Rest/tempo drift  — longer-than-usual rest or slower reps vs. this
//                           exercise's own sets earlier today.
//   4. Heart rate (opt.) — only when pre-resolved HR data is supplied by the
//                           caller; purely additive, never required. This
//                           class does no I/O itself — see [HrEffortSignal].
//
// Every estimate carries a confidence score capped below what a real
// user-reported RPE would get, so low-confidence estimates should only
// annotate reasoning text, never flip a recommendation branch on their own.

import '../../models/models.dart';

/// Pre-resolved heart-rate signal for one set, already read from Health
/// Connect by the caller. [EffortEstimator] never fetches HR itself — the
/// in-workout recommendation path must stay synchronous/offline, so live HR
/// wiring (if added) has to happen upstream of this pure function.
class HrEffortSignal {
  /// Peak bpm observed during this set's window.
  final double setPeakBpm;

  /// Number of samples that window contained (gates how much to trust it).
  final int setSampleCount;

  /// Lowest bpm observed anywhere in today's session so far.
  final double sessionFloorBpm;

  /// Highest bpm observed anywhere in today's session so far.
  final double sessionPeakBpm;

  const HrEffortSignal({
    required this.setPeakBpm,
    required this.setSampleCount,
    required this.sessionFloorBpm,
    required this.sessionPeakBpm,
  });
}

class EffortEstimator {
  const EffortEstimator();

  static const double anchorRpe = 8.0;
  static const double minRpe = 5.0;
  static const double maxRpe = 10.0;

  // Term 1: trend deviation. Reuses the same trustworthy-fit gate as the
  // growth-trend recommendation rules (see progression_rules.dart).
  static const double _minR2ForTrendSignal = 0.2;
  static const double _trendDeviationWeight = 0.8;

  // Term 2: intra-session decline. Deadband absorbs normal set-to-set
  // variance; only a real drop-off counts.
  static const double _declineDeadband = 0.05;
  static const double _declineWeight = 3.0;
  static const double _maxDeclineFraction = 0.5;

  // Term 3: rest/tempo drift vs. this exercise's own sets earlier today.
  static const double _restGapWeight = 0.6;
  static const double _tempoWeight = 0.5;

  // Term 4: heart rate (optional).
  static const double _hrWeight = 1.0;
  static const double _hrBaselineFraction = 0.8;
  static const double _hrSpanFraction = 0.2;
  static const int minHrSamplesForSignal = 3;

  // Confidence ladder — base plus bonuses, capped below a real user-reported
  // value's confidence of 1.0.
  static const double _baseConfidence = 0.35;
  static const double _trendGateConfidenceBonus = 0.20;
  static const double _sufficientSetsConfidenceBonus = 0.20;
  static const double _hrConfidenceBonus = 0.15;
  static const double _historyConfidenceBonus = 0.10;
  static const double maxEstimatedConfidence = 0.85;
  static const int _minSetsForConfidenceBonus = 3;
  static const int _minSessionsForConfidenceBonus = 6;

  /// Estimates RPE for [set].
  ///
  /// [priorSetsThisExerciseToday] must be this exercise's other sets already
  /// logged earlier in today's in-progress session, oldest-first, excluding
  /// [set] itself — used for the decline and rest/tempo terms.
  /// [growthModel]/[growthModelX] back the trend-deviation term (skipped
  /// when either is absent or the fit isn't trustworthy).
  /// [calibrationOffset] is the rolling once-per-workout-chip adjustment to
  /// the RPE-8 anchor (see [WorkoutSession.sessionEffort]).
  /// [sessionHistoryCount] is how many past sessions exist for this exercise
  /// (confidence only — more history makes the trend term more trustworthy).
  /// [hrSignal] is optional and purely additive; omit when HR data isn't
  /// available.
  EffortEstimate estimate({
    required WorkoutSet set,
    List<WorkoutSet> priorSetsThisExerciseToday = const [],
    GrowthModel? growthModel,
    double? growthModelX,
    double calibrationOffset = 0.0,
    int sessionHistoryCount = 0,
    HrEffortSignal? hrSignal,
  }) {
    var rpe = anchorRpe + calibrationOffset;
    var confidence = _baseConfidence;
    var source = EffortSource.estimatedHrless;

    // Term 1: trend deviation.
    if (growthModel != null &&
        growthModel.r2 > _minR2ForTrendSignal &&
        growthModelX != null) {
      final actualVolume = priorSetsThisExerciseToday.fold(
            0.0,
            (sum, s) => sum + s.volume,
          ) +
          set.volume;
      final predicted = growthModel.predict(growthModelX);
      final scale =
          growthModel.stdError > 0 ? growthModel.stdError : (predicted * 0.05).abs();
      if (scale > 0) {
        final z = ((actualVolume - predicted) / scale).clamp(-2.0, 2.0);
        rpe += _trendDeviationWeight * -z;
        confidence += _trendGateConfidenceBonus;
      }
    }

    // Term 2: intra-session decline (needs a baseline set today).
    if (priorSetsThisExerciseToday.isNotEmpty) {
      final firstVolume = priorSetsThisExerciseToday.first.volume;
      if (firstVolume > 0) {
        final declineFrac = 1 - (set.volume / firstVolume);
        rpe += _declineWeight *
            (declineFrac - _declineDeadband).clamp(0.0, _maxDeclineFraction);
      }
    }

    // Term 3: rest/tempo drift vs. the median of this exercise's earlier
    // sets today (needs ≥2 prior sets to establish a median baseline).
    if (priorSetsThisExerciseToday.length >= 2) {
      final gaps = <double>[
        for (var i = 1; i < priorSetsThisExerciseToday.length; i++)
          priorSetsThisExerciseToday[i]
              .timestamp
              .difference(priorSetsThisExerciseToday[i - 1].timestamp)
              .inSeconds
              .toDouble(),
      ];
      final medianGap = _median(gaps);
      final currentGap = set.timestamp
          .difference(priorSetsThisExerciseToday.last.timestamp)
          .inSeconds
          .toDouble();
      if (medianGap > 0 && currentGap > 0) {
        rpe += _restGapWeight * (currentGap / medianGap - 1).clamp(0.0, 1.0);
      }

      final tempos = <double>[
        for (final s in priorSetsThisExerciseToday)
          if (s.timeTaken != null && s.reps > 0) s.timeTaken! / s.reps,
      ];
      if (tempos.isNotEmpty && set.timeTaken != null && set.reps > 0) {
        final medianTempo = _median(tempos);
        final currentTempo = set.timeTaken! / set.reps;
        if (medianTempo > 0) {
          rpe += _tempoWeight *
              (currentTempo / medianTempo - 1).clamp(0.0, 1.0);
        }
      }
    }

    // Term 4: heart rate (optional, purely additive).
    if (hrSignal != null &&
        hrSignal.setSampleCount >= minHrSamplesForSignal &&
        hrSignal.sessionPeakBpm > hrSignal.sessionFloorBpm) {
      final hrFrac = (hrSignal.setPeakBpm - hrSignal.sessionFloorBpm) /
          (hrSignal.sessionPeakBpm - hrSignal.sessionFloorBpm);
      final term =
          ((hrFrac - _hrBaselineFraction) / _hrSpanFraction).clamp(-1.0, 1.0);
      rpe += _hrWeight * term;
      confidence += _hrConfidenceBonus;
      source = EffortSource.estimatedWithHr;
    }

    if (priorSetsThisExerciseToday.length + 1 >= _minSetsForConfidenceBonus) {
      confidence += _sufficientSetsConfidenceBonus;
    }
    if (sessionHistoryCount >= _minSessionsForConfidenceBonus) {
      confidence += _historyConfidenceBonus;
    }

    return EffortEstimate(
      rpe: rpe.clamp(minRpe, maxRpe),
      source: source,
      confidence: confidence.clamp(0.0, maxEstimatedConfidence),
    );
  }

  static double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
