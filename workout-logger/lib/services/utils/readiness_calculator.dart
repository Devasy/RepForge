// Readiness Calculator (pure, no I/O)
//
// Scores today's training readiness against the user's own rolling baseline.
// Each component (sleep, resting HR, HRV) is scored 0–100 independently and
// only penalizes adverse deviation — being at or better than baseline is 100.
// The overall score is a weighted average renormalized over the components
// that are actually available, so sleep-only users get a first-class score.

import '../../models/models.dart';

class ReadinessCalculator {
  const ReadinessCalculator();

  /// Minimum baseline samples before a component participates in scoring.
  static const int minBaselineSamples = 5;

  /// Component weights, renormalized over available components.
  static const double sleepWeight = 0.5;
  static const double rhrWeight = 0.3;
  static const double hrvWeight = 0.2;

  /// Sleep under this many minutes is capped at [shortSleepMaxScore]
  /// regardless of the user's baseline (guards chronically short baselines).
  static const int shortSleepMinutes = 300;
  static const int shortSleepMaxScore = 40;

  static const int highBandThreshold = 75;
  static const int moderateBandThreshold = 50;

  /// Picks "last night's" sleep: the longest period overlapping the window
  /// yesterday 18:00 → today 12:00 local. Returns null when nothing overlaps.
  SleepPeriod? lastNightSleep(DateTime today, List<SleepPeriod> periods) {
    final day = DateTime(today.year, today.month, today.day);
    final windowStart = day.subtract(const Duration(hours: 6)); // 18:00 prev day
    final windowEnd = day.add(const Duration(hours: 12));

    SleepPeriod? longest;
    for (final p in periods) {
      if (!p.end.isAfter(windowStart) || !p.start.isBefore(windowEnd)) continue;
      if (longest == null || p.minutes > longest.minutes) longest = p;
    }
    return longest;
  }

  ReadinessSnapshot compute({
    required DateTime today,
    required ReadinessBaseline baseline,
    int? lastNightSleepMinutes,
    double? todayRestingHr,
    double? todayHrvMs,
  }) {
    final sleepBaseline =
        baseline.sleepNights >= minBaselineSamples ? baseline.avgSleepMinutes : null;
    final rhrBaseline =
        baseline.rhrDays >= minBaselineSamples ? baseline.avgRestingHr : null;
    final hrvBaseline =
        baseline.hrvDays >= minBaselineSamples ? baseline.avgHrvMs : null;

    final sleepScore = _sleepScore(lastNightSleepMinutes, sleepBaseline);
    final rhrScore = _rhrScore(todayRestingHr, rhrBaseline);
    final hrvScore = _hrvScore(todayHrvMs, hrvBaseline);

    int? score;
    ReadinessBand? band;
    var weighted = 0.0;
    var totalWeight = 0.0;
    if (sleepScore != null) {
      weighted += sleepScore * sleepWeight;
      totalWeight += sleepWeight;
    }
    if (rhrScore != null) {
      weighted += rhrScore * rhrWeight;
      totalWeight += rhrWeight;
    }
    if (hrvScore != null) {
      weighted += hrvScore * hrvWeight;
      totalWeight += hrvWeight;
    }
    if (totalWeight > 0) {
      score = (weighted / totalWeight).round().clamp(0, 100);
      band = score >= highBandThreshold
          ? ReadinessBand.high
          : score >= moderateBandThreshold
              ? ReadinessBand.moderate
              : ReadinessBand.low;
    }

    return ReadinessSnapshot(
      dateKey: dateKey(today),
      score: score,
      band: band,
      sleepMinutes: sleepScore != null ? lastNightSleepMinutes : null,
      sleepBaselineMinutes: sleepScore != null ? sleepBaseline : null,
      sleepScore: sleepScore,
      restingHr: rhrScore != null ? todayRestingHr : null,
      rhrBaseline: rhrScore != null ? rhrBaseline : null,
      rhrScore: rhrScore,
      hrvMs: hrvScore != null ? todayHrvMs : null,
      hrvBaseline: hrvScore != null ? hrvBaseline : null,
      hrvScore: hrvScore,
    );
  }

  // Every 10% of sleep below the personal average costs 20 points.
  int? _sleepScore(int? minutes, double? avgMinutes) {
    if (minutes == null || avgMinutes == null || avgMinutes <= 0) return null;
    final ratio = minutes / avgMinutes;
    var score = (100 - _adverse(1 - ratio) * 200).round().clamp(0, 100);
    if (minutes < shortSleepMinutes && score > shortSleepMaxScore) {
      score = shortSleepMaxScore;
    }
    return score;
  }

  // Elevated resting HR is the penalty: +10% over baseline scores 50.
  int? _rhrScore(double? rhr, double? avgRhr) {
    if (rhr == null || avgRhr == null || avgRhr <= 0) return null;
    final deviation = (rhr - avgRhr) / avgRhr;
    return (100 - _adverse(deviation) * 500).round().clamp(0, 100);
  }

  // Suppressed HRV is the penalty: −20% under baseline scores 50.
  int? _hrvScore(double? hrv, double? avgHrv) {
    if (hrv == null || avgHrv == null || avgHrv <= 0) return null;
    final ratio = hrv / avgHrv;
    return (100 - _adverse(1 - ratio) * 250).round().clamp(0, 100);
  }

  double _adverse(double deviation) => deviation > 0 ? deviation : 0;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
