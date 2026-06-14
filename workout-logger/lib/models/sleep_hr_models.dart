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

// ─────────────────────────────────────────────────────────────────────────────
// History & granularity models — added for the Sleep/HR detail screens.
// Like the snapshots above, these are computed at runtime from Health Connect
// and are not persisted (the heavy per-day HR results may be cached as JSON,
// but that is the manager's concern, not a contract here).
// ─────────────────────────────────────────────────────────────────────────────

/// Granularity for the Sleep / Heart-rate detail screens.
enum HealthGranularity { day, week, month, year }

extension HealthGranularityX on HealthGranularity {
  /// Short toggle label.
  String get label => switch (this) {
        HealthGranularity.day => 'Day',
        HealthGranularity.week => 'Week',
        HealthGranularity.month => 'Month',
        HealthGranularity.year => 'Year',
      };
}

/// One ~30-minute window of all-day HR (min / max / avg).
class HrBucket {
  final DateTime windowStart;
  final int minBpm;
  final int maxBpm;
  final double avgBpm;

  const HrBucket({
    required this.windowStart,
    required this.minBpm,
    required this.maxBpm,
    required this.avgBpm,
  });

  Map<String, dynamic> toJson() => {
        't': windowStart.toIso8601String(),
        'mn': minBpm,
        'mx': maxBpm,
        'av': avgBpm,
      };

  factory HrBucket.fromJson(Map<String, dynamic> j) => HrBucket(
        windowStart: DateTime.parse(j['t'] as String),
        minBpm: (j['mn'] as num).toInt(),
        maxBpm: (j['mx'] as num).toInt(),
        avgBpm: (j['av'] as num).toDouble(),
      );
}

/// Complete all-day HR picture for one calendar day — backs the Heart-rate
/// card (compact) and the Day tab of HeartRateDetailScreen.
class HrDaySnapshot {
  final DateTime day;

  /// Resting HR for the day (RHR record if present, else morning-min fallback).
  final int? restingBpm;
  final int minBpm;
  final int maxBpm;
  final double avgBpm;

  /// ~30-minute buckets ordered chronologically.
  final List<HrBucket> buckets;

  const HrDaySnapshot({
    required this.day,
    required this.restingBpm,
    required this.minBpm,
    required this.maxBpm,
    required this.avgBpm,
    required this.buckets,
  });

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'rest': restingBpm,
        'mn': minBpm,
        'mx': maxBpm,
        'av': avgBpm,
        'b': buckets.map((b) => b.toJson()).toList(),
      };

  factory HrDaySnapshot.fromJson(Map<String, dynamic> j) => HrDaySnapshot(
        day: DateTime.parse(j['day'] as String),
        restingBpm: (j['rest'] as num?)?.toInt(),
        minBpm: (j['mn'] as num).toInt(),
        maxBpm: (j['mx'] as num).toInt(),
        avgBpm: (j['av'] as num).toDouble(),
        buckets: (j['b'] as List)
            .map((e) => HrBucket.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One aggregated sleep bar (a night, or a month in the year view).
class SleepDayBar {
  final DateTime date;
  final int totalMinutes;
  final int deepMin;
  final int remMin;
  final int lightMin;
  final int awakeMin;

  const SleepDayBar({
    required this.date,
    required this.totalMinutes,
    required this.deepMin,
    required this.remMin,
    required this.lightMin,
    required this.awakeMin,
  });
}

/// One aggregated HR range bar (a day, or a month in the year view).
class HrRangeBar {
  final DateTime date;
  final String label;
  final int minBpm;
  final int maxBpm;
  final double avgBpm;
  final int? restingBpm;

  const HrRangeBar({
    required this.date,
    required this.label,
    required this.minBpm,
    required this.maxBpm,
    required this.avgBpm,
    required this.restingBpm,
  });
}
