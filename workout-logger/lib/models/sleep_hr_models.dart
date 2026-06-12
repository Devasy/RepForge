/// Data models for the Sleep HR chart feature.
///
/// These are computed at runtime from Health Connect HR + sleep-stage data
/// and are never persisted. If the snapshot is null the compact card hides.
library;

/// One 10-minute window of overnight HR data, colour-coded by sleep stage.
class SleepHrSegment {
  final DateTime windowStart;

  /// BPM floor of all samples in this window.
  final int minBpm;

  /// BPM ceiling of all samples in this window.
  final int maxBpm;

  /// Mean BPM across all samples in this window.
  final double avgBpm;

  /// Dominant sleep stage: 'deep' | 'rem' | 'light' | 'awake'.
  final String stage;

  const SleepHrSegment({
    required this.windowStart,
    required this.minBpm,
    required this.maxBpm,
    required this.avgBpm,
    required this.stage,
  });
}

/// Aggregate HR statistics for one sleep stage.
class SleepStageStats {
  /// 'deep' | 'rem' | 'light' | 'awake'
  final String stage;
  final int minBpm;
  final int p25Bpm;
  final double avgBpm;
  final int p75Bpm;
  final int maxBpm;
  final int sampleCount;

  const SleepStageStats({
    required this.stage,
    required this.minBpm,
    required this.p25Bpm,
    required this.avgBpm,
    required this.p75Bpm,
    required this.maxBpm,
    required this.sampleCount,
  });
}

/// Complete overnight HR picture — carried by ReadinessManager and consumed
/// by SleepHrCard (compact) and SleepHrSheet (full detail).
class SleepHrSnapshot {
  final DateTime sleepStart;
  final DateTime sleepEnd;

  /// 5th-percentile — overnight HR floor.
  final int p5Bpm;

  /// 95th-percentile of all overnight HR samples — used as an RHR proxy.
  final int p95Bpm;

  /// 10-minute segments ordered chronologically.
  final List<SleepHrSegment> segments;

  /// One entry per stage present (deep / rem / light / awake).
  final List<SleepStageStats> stageStats;

  const SleepHrSnapshot({
    required this.sleepStart,
    required this.sleepEnd,
    required this.p5Bpm,
    required this.p95Bpm,
    required this.segments,
    required this.stageStats,
  });

  SleepStageStats? statsFor(String stage) =>
      stageStats.where((s) => s.stage == stage).firstOrNull;
}
