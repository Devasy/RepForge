// Data models for the per-workout heart-rate breakdown shown in the History
// session-details sheet. Computed at runtime from Health Connect HR samples +
// the session's set timestamps; never persisted.
library;

/// One point on the workout HR curve (~30-second bucket average).
class HrCurvePoint {
  final DateTime time;
  final double bpm;
  const HrCurvePoint({required this.time, required this.bpm});
}

/// HR recovery across one rest gap between two sets.
class RestRecovery {
  /// 1-based index of the set this rest follows (global across the session).
  final int afterSet;
  final DateTime restStart;
  final int durationSec;

  /// HR at the end of the preceding set (local peak).
  final int peakBpm;

  /// Lowest HR reached during the rest.
  final int troughBpm;

  /// peakBpm − troughBpm (positive means HR came down).
  final int recoveryBpm;

  /// True when the drop met the recovery threshold.
  final bool recovered;

  const RestRecovery({
    required this.afterSet,
    required this.restStart,
    required this.durationSec,
    required this.peakBpm,
    required this.troughBpm,
    required this.recoveryBpm,
    required this.recovered,
  });
}

/// Time span of one exercise within the session — drawn as a labelled flag /
/// section on the HR curve so you can see which part of the workout is which.
class ExerciseHrSpan {
  final String exerciseId;
  final DateTime start;
  final DateTime end;
  final int setCount;

  const ExerciseHrSpan({
    required this.exerciseId,
    required this.start,
    required this.end,
    required this.setCount,
  });
}

/// Complete HR picture for one recorded workout.
class WorkoutHrAnalysis {
  final DateTime start;
  final DateTime end;
  final int avgBpm;
  final int peakBpm;
  final int minBpm;

  /// Ordered curve points across the session.
  final List<HrCurvePoint> curve;

  /// Per-rest recovery. Empty when set timestamps aren't trustworthy
  /// ([hasRestAnalysis] is false) — the curve still renders.
  final List<RestRecovery> rests;

  /// Exercise sections across the session, ordered in time. Empty when set
  /// timestamps aren't trustworthy.
  final List<ExerciseHrSpan> exercises;

  /// Whether rest/section analysis was computed (set timestamps spanned the
  /// session).
  final bool hasRestAnalysis;

  const WorkoutHrAnalysis({
    required this.start,
    required this.end,
    required this.avgBpm,
    required this.peakBpm,
    required this.minBpm,
    required this.curve,
    required this.rests,
    required this.exercises,
    required this.hasRestAnalysis,
  });

  int get restsRecovered => rests.where((r) => r.recovered).length;
  int get restCount => rests.length;

  /// Mean recovery (bpm) across the rests that recovered; 0 when none did.
  int get avgRecoveryBpm {
    final ok = rests.where((r) => r.recovered).toList();
    if (ok.isEmpty) return 0;
    return (ok.fold<int>(0, (s, r) => s + r.recoveryBpm) / ok.length).round();
  }

  int get restsTooShort => rests.where((r) => !r.recovered).length;
}
