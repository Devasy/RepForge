// Sleep-HR snapshot builder.
//
// Extracted from ReadinessManager so the overnight-HR snapshot can be built
// for ANY night, not just last night. ReadinessManager builds it for "today"
// (with a prior-night fallback for un-synced mornings); HealthHistoryManager
// builds it for arbitrary historical dates as the user navigates.
//
// Pure function over IHealthConnectService — no state, no caching here.

import 'package:flutter/foundation.dart';

import '../../models/sleep_hr_models.dart';
import '../interfaces/health_connect_service_interface.dart';

/// Builds an overnight HR snapshot for the night that ENDS on the morning of
/// [morning] (i.e. the local calendar day [morning]).
///
/// Returns null when HR/sleep permission is missing or no samples exist.
/// When [fallbackToPriorNight] is true and the target night has no sleep data,
/// it retries the night before (covers mornings where the watch hasn't synced).
Future<SleepHrSnapshot?> buildSleepHrSnapshot(
  IHealthConnectService hc,
  DateTime morning,
  Set<HealthReadType> granted, {
  bool fallbackToPriorNight = false,
}) async {
  if (!granted.contains(HealthReadType.heartRate)) return null;
  if (!granted.contains(HealthReadType.sleep)) return null;

  final day = DateTime(morning.year, morning.month, morning.day);

  var windowStart = day.subtract(const Duration(hours: 6));
  var windowEnd = day.add(const Duration(hours: 12));

  var periods = await hc.readSleepSessions(windowStart, windowEnd);
  if (periods.isEmpty && fallbackToPriorNight) {
    windowStart = windowStart.subtract(const Duration(days: 1));
    windowEnd = windowEnd.subtract(const Duration(days: 1));
    periods = await hc.readSleepSessions(windowStart, windowEnd);
    debugPrint('[SleepHr] no data for target night — fell back to night before');
  }
  if (periods.isEmpty) return null;

  // Use the earliest start and latest end across all records.
  final sleepStart = periods.map((p) => p.start).reduce((a, b) => a.isBefore(b) ? a : b);
  final sleepEnd = periods.map((p) => p.end).reduce((a, b) => a.isAfter(b) ? a : b);

  // Read HR samples covering the full sleep window (+ 15 min buffer).
  final samples = await hc.readHeartRateSamples(
    sleepStart.subtract(const Duration(minutes: 15)),
    sleepEnd.add(const Duration(minutes: 15)),
  );
  if (samples.isEmpty) return null;

  // Flatten all stage intervals from all periods into one sorted list.
  final allIntervals = periods
      .expand((p) => p.stageTimeline)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  String stageAt(DateTime t) {
    for (final iv in allIntervals) {
      if (!t.isBefore(iv.start) && t.isBefore(iv.end)) return iv.stage;
    }
    return 'awake';
  }

  // Bucket samples into 10-minute windows aligned to sleepStart.
  final segmentMap = <int, List<({int bpm, String stage})>>{};
  for (final s in samples) {
    final offsetMin = s.time.difference(sleepStart).inMinutes;
    if (offsetMin < 0) continue;
    final bucket = (offsetMin ~/ 10) * 10;
    segmentMap.putIfAbsent(bucket, () => []);
    segmentMap[bucket]!.add((bpm: s.value.round(), stage: stageAt(s.time)));
  }

  final segments = <SleepHrSegment>[];
  final sortedBuckets = segmentMap.keys.toList()..sort();
  for (final bucket in sortedBuckets) {
    final entries = segmentMap[bucket]!;
    if (entries.length < 2) continue;
    final bpms = entries.map((e) => e.bpm).toList()..sort();
    final stageCounts = <String, int>{};
    for (final e in entries) {
      stageCounts[e.stage] = (stageCounts[e.stage] ?? 0) + 1;
    }
    final dominantStage = stageCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    segments.add(SleepHrSegment(
      windowStart: sleepStart.add(Duration(minutes: bucket)),
      minBpm: bpms.first,
      maxBpm: bpms.last,
      avgBpm: bpms.reduce((a, b) => a + b) / bpms.length,
      stage: dominantStage,
    ));
  }
  if (segments.isEmpty) return null;

  // P5 / P95 across all samples.
  final allBpms = samples.map((s) => s.value.round()).toList()..sort();
  final p5Bpm = allBpms[(allBpms.length * 0.05).floor().clamp(0, allBpms.length - 1)];
  final p95Bpm = allBpms[(allBpms.length * 0.95).floor().clamp(0, allBpms.length - 1)];

  // Per-stage stats (min 3 samples required).
  final byStage = <String, List<int>>{};
  for (final s in samples) {
    final stage = stageAt(s.time);
    byStage.putIfAbsent(stage, () => []);
    byStage[stage]!.add(s.value.round());
  }
  final stageStats = <SleepStageStats>[];
  for (final entry in byStage.entries) {
    final bpms = entry.value..sort();
    if (bpms.length < 3) continue;
    stageStats.add(SleepStageStats(
      stage: entry.key,
      minBpm: bpms.first,
      p25Bpm: bpms[(bpms.length * 0.25).floor()],
      avgBpm: bpms.reduce((a, b) => a + b) / bpms.length,
      p75Bpm: bpms[(bpms.length * 0.75).floor()],
      maxBpm: bpms.last,
      sampleCount: bpms.length,
    ));
  }

  return SleepHrSnapshot(
    sleepStart: sleepStart,
    sleepEnd: sleepEnd,
    p5Bpm: p5Bpm,
    p95Bpm: p95Bpm,
    segments: segments,
    stageStats: stageStats,
  );
}

/// Builds an all-day HR snapshot for the local calendar day [day]: ~30-minute
/// min/max/avg buckets plus a resting-HR figure.
///
/// Returns null when HR permission is missing or no samples exist for the day.
/// Resting HR = latest restingHeartRate record that day, else the minimum
/// raw sample between 02:00–10:00 (same fallback ReadinessManager uses).
Future<HrDaySnapshot?> buildHrDaySnapshot(
  IHealthConnectService hc,
  DateTime day,
  Set<HealthReadType> granted, {
  Duration bucket = const Duration(minutes: 30),
}) async {
  if (!granted.contains(HealthReadType.heartRate)) return null;

  final start = DateTime(day.year, day.month, day.day);
  final end = start.add(const Duration(days: 1));

  final samples = await hc.readHeartRateSamples(start, end);
  if (samples.isEmpty) return null;

  final bucketMin = bucket.inMinutes;
  final byBucket = <int, List<int>>{};
  for (final s in samples) {
    final offset = s.time.difference(start).inMinutes;
    if (offset < 0 || offset >= 1440) continue;
    final key = (offset ~/ bucketMin) * bucketMin;
    byBucket.putIfAbsent(key, () => []).add(s.value.round());
  }

  final buckets = <HrBucket>[];
  for (final key in byBucket.keys.toList()..sort()) {
    final bpms = byBucket[key]!;
    buckets.add(HrBucket(
      windowStart: start.add(Duration(minutes: key)),
      minBpm: bpms.reduce((a, b) => a < b ? a : b),
      maxBpm: bpms.reduce((a, b) => a > b ? a : b),
      avgBpm: bpms.reduce((a, b) => a + b) / bpms.length,
    ));
  }
  if (buckets.isEmpty) return null;

  final allBpms = samples.map((s) => s.value.round()).toList();
  final minBpm = allBpms.reduce((a, b) => a < b ? a : b);
  final maxBpm = allBpms.reduce((a, b) => a > b ? a : b);
  final avgBpm = allBpms.reduce((a, b) => a + b) / allBpms.length;

  // Resting HR.
  int? restingBpm;
  if (granted.contains(HealthReadType.restingHeartRate)) {
    final rhr = await hc.readRestingHeartRate(start, end);
    if (rhr.isNotEmpty) {
      rhr.sort((a, b) => a.time.compareTo(b.time));
      restingBpm = rhr.last.value.round();
    }
  }
  restingBpm ??= () {
    final morning = samples.where((s) {
      final h = s.time.difference(start).inMinutes;
      return h >= 120 && h <= 600; // 02:00–10:00
    });
    if (morning.isEmpty) return null;
    return morning.map((s) => s.value).reduce((a, b) => a < b ? a : b).round();
  }();

  return HrDaySnapshot(
    day: start,
    restingBpm: restingBpm,
    minBpm: minBpm,
    maxBpm: maxBpm,
    avgBpm: avgBpm,
    buckets: buckets,
  );
}
