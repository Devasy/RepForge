// Readiness Manager (Single Responsibility Principle)
//
// Owns the daily readiness slice of state: reads sleep/heart data from
// Health Connect, maintains a rolling 14-day personal baseline (recomputed
// at most once per day), scores today via ReadinessCalculator, and caches
// the result in settings storage so the home screen renders instantly.
//
// Failure policy: this feature is strictly additive — every error path
// degrades to ReadinessStatus.noData and never throws or blocks app init.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../../models/sleep_hr_models.dart';
import '../interfaces/health_connect_service_interface.dart';
import '../interfaces/readiness_manager_interface.dart';
import '../interfaces/storage_service_interface.dart';
import '../settings_provider.dart';
import '../utils/readiness_calculator.dart';

class ReadinessManager extends ChangeNotifier implements IReadinessManager {
  final IHealthConnectService _hc;
  final IStorageService _storage;
  final SettingsProvider _settings;
  final ReadinessCalculator _calculator;

  static const _snapshotKey = 'readiness.snapshot';
  static const _baselineKey = 'readiness.baseline';
  static const _snapshotTtl = Duration(minutes: 30);
  static const _baselineDays = 14;

  ReadinessStatus _status = ReadinessStatus.idle;
  ReadinessSnapshot? _snapshot;
  SleepHrSnapshot? _sleepHrSnapshot;

  SleepHrSnapshot? get sleepHrSnapshot => _sleepHrSnapshot;

  // Debug-only: human-readable trace of the last refresh() execution.
  // Empty until refresh() runs for the first time.
  String _debugTrace = '';
  String get debugTrace => _debugTrace;

  ReadinessManager(
    this._hc,
    this._storage,
    this._settings, {
    ReadinessCalculator calculator = const ReadinessCalculator(),
  }) : _calculator = calculator;

  @override
  ReadinessStatus get status => _status;

  @override
  ReadinessSnapshot? get snapshot => _snapshot;

  @override
  Future<void> refresh({bool force = false}) async {
    if (!_settings.readinessEnabled) {
      _debugTrace = 'readinessEnabled=false — refresh skipped';
      return;
    }

    try {
      final now = DateTime.now();
      final todayKey = ReadinessCalculator.dateKey(now);
      debugPrint('[Readiness] refresh: todayKey=$todayKey force=$force');

      // Fetch permissions first — needed on both the cached and live paths.
      final granted = await _hc.grantedReadTypes();
      debugPrint('[Readiness] refresh: granted=$granted');
      if (granted.isEmpty) {
        debugPrint('[Readiness] refresh: no permissions → noData');
        _debugTrace = 'NO PERMISSIONS granted\n'
            'Open Health Connect → App permissions → RepForge\n'
            'and allow Sleep and Heart rate.';
        _setNoData();
        return;
      }

      final cached = await _loadSnapshot();
      if (cached != null && cached.dateKey == todayKey) {
        // Same-day cache renders immediately; skip the re-fetch inside TTL.
        _snapshot = cached;
        _status = ReadinessStatus.ready;
        notifyListeners();
        debugPrint('[Readiness] refresh: serving cached snapshot score=${cached.score}');
        if (!force && now.difference(cached.computedAt) < _snapshotTtl) {
          _debugTrace = 'Serving cached snapshot (within ${_snapshotTtl.inMinutes}min TTL)\n'
              'score=${cached.score} band=${cached.band}\n'
              'computedAt=${cached.computedAt.toLocal()}';
          // Still build the sleep HR snapshot if we don't have one yet.
          if (_sleepHrSnapshot == null) {
            _sleepHrSnapshot = await _buildSleepHrSnapshot(now, granted);
            if (_sleepHrSnapshot != null) notifyListeners();
          }
          return;
        }
      }

      final sleepMinutes = await _lastNightSleepMinutes(now, granted);
      final restingHr = await _todayRestingHr(now, granted);
      final hrv = await _todayHrv(now, granted);

      // Build overnight HR snapshot (best-effort; failure must not affect score).
      try {
        _sleepHrSnapshot = await _buildSleepHrSnapshot(now, granted);
      } catch (e) {
        debugPrint('[Readiness] _buildSleepHrSnapshot failed (non-fatal): $e');
        _sleepHrSnapshot = null;
      }
      debugPrint('[Readiness] refresh: today → sleepMinutes=$sleepMinutes restingHr=$restingHr hrv=$hrv');

      final baseline = await _baselineFor(todayKey, now, granted);
      debugPrint('[Readiness] refresh: baseline → '
          'avgSleep=${baseline.avgSleepMinutes?.toStringAsFixed(0)} (${baseline.sleepNights} nights) '
          'avgRhr=${baseline.avgRestingHr?.toStringAsFixed(1)} (${baseline.rhrDays} days) '
          'avgHrv=${baseline.avgHrvMs?.toStringAsFixed(1)} (${baseline.hrvDays} days)');

      final snapshot = _calculator.compute(
        today: now,
        baseline: baseline,
        lastNightSleepMinutes: sleepMinutes,
        todayRestingHr: restingHr,
        todayHrvMs: hrv,
      );
      debugPrint('[Readiness] refresh: snapshot score=${snapshot.score} band=${snapshot.band} '
          'sleepScore=${snapshot.sleepScore} rhrScore=${snapshot.rhrScore} hrvScore=${snapshot.hrvScore}');

      // Build human-readable trace for the in-app debug panel.
      final need = ReadinessCalculator.minBaselineSamples;
      final buf = StringBuffer();
      buf.writeln('Granted: ${granted.map((e) => e.name).join(', ')}');
      buf.writeln('');
      buf.writeln('TODAY:');
      buf.writeln('  sleep  : ${sleepMinutes != null ? "${sleepMinutes}min" : "—  (no data)"}'
          '${!granted.contains(HealthReadType.sleep) ? " [no perm]" : ""}');
      buf.writeln('  RHR    : ${restingHr != null ? "${restingHr.toStringAsFixed(1)} bpm" : "—  (no data)"}'
          '${!granted.contains(HealthReadType.restingHeartRate) ? " [no perm]" : ""}');
      buf.writeln('  HRV    : ${hrv != null ? "${hrv.toStringAsFixed(1)} ms" : "—  (no data)"}'
          '${!granted.contains(HealthReadType.hrv) ? " [no perm]" : ""}');
      buf.writeln('');
      buf.writeln('BASELINE (14d, need ≥$need samples):');
      buf.writeln('  sleep  : ${baseline.avgSleepMinutes?.toStringAsFixed(0) ?? "—"}min'
          ' · ${baseline.sleepNights} nights'
          ' ${baseline.sleepNights >= need ? "✓" : "⚠ need $need"}');
      buf.writeln('  RHR    : ${baseline.avgRestingHr?.toStringAsFixed(1) ?? "—"} bpm'
          ' · ${baseline.rhrDays} days'
          ' ${baseline.rhrDays >= need ? "✓" : "⚠ need $need"}');
      buf.writeln('  HRV    : ${baseline.avgHrvMs?.toStringAsFixed(1) ?? "—"} ms'
          ' · ${baseline.hrvDays} days'
          ' ${baseline.hrvDays >= need ? "✓" : "⚠ need $need"}');
      buf.writeln('');
      buf.writeln('SLEEP HR:');
      if (_sleepHrSnapshot != null) {
        final sh = _sleepHrSnapshot!;
        buf.writeln('  segments=${sh.segments.length}  p95=${sh.p95Bpm}bpm'
            '  stages=${sh.stageStats.map((s) => s.stage).join(",")}');
      } else {
        buf.writeln('  — no snapshot (need heartRate perm + sleep data)');
      }
      buf.writeln('');
      buf.writeln('SCORES:');
      buf.writeln('  sleep=${snapshot.sleepScore ?? "—"}  rhr=${snapshot.rhrScore ?? "—"}  hrv=${snapshot.hrvScore ?? "—"}');
      buf.writeln('  overall=${snapshot.score ?? "null"}  band=${snapshot.band?.name ?? "—"}');
      if (snapshot.score == null) {
        buf.writeln('');
        buf.writeln('⚠ Score null: a component needs both today\'s data');
        buf.writeln('  AND ≥$need baseline days to contribute.');
      }
      _debugTrace = buf.toString().trimRight();

      if (snapshot.score == null) {
        debugPrint('[Readiness] refresh: score null → noData '
            '(need ${ReadinessCalculator.minBaselineSamples}+ baseline days; '
            'have sleep=${baseline.sleepNights} rhr=${baseline.rhrDays} hrv=${baseline.hrvDays})');
        _setNoData();
        return;
      }

      _snapshot = snapshot;
      _status = ReadinessStatus.ready;
      await _storage.saveSetting(_snapshotKey, jsonEncode(snapshot.toJson()));
      notifyListeners();
    } catch (e) {
      debugPrint('[Readiness] refresh failed: $e');
      _debugTrace = 'refresh() threw: $e';
      _setNoData();
    }
  }

  /// Builds an overnight HR snapshot for the Sleep HR chart.
  /// Returns null when HR permission is missing or no samples exist.
  Future<SleepHrSnapshot?> _buildSleepHrSnapshot(
    DateTime now,
    Set<HealthReadType> granted,
  ) async {
    if (!granted.contains(HealthReadType.heartRate)) return null;
    if (!granted.contains(HealthReadType.sleep)) return null;

    final day = DateTime(now.year, now.month, now.day);

    // Try last night first; fall back to the night before if no data yet
    // (covers mornings where the watch hasn't synced yet).
    List<SleepPeriod> periods = [];
    DateTime windowStart = day.subtract(const Duration(hours: 6));
    DateTime windowEnd = day.add(const Duration(hours: 12));

    periods = await _hc.readSleepSessions(windowStart, windowEnd);
    if (periods.isEmpty) {
      windowStart = windowStart.subtract(const Duration(days: 1));
      windowEnd = windowEnd.subtract(const Duration(days: 1));
      periods = await _hc.readSleepSessions(windowStart, windowEnd);
      debugPrint('[Readiness] sleepHR: no data for last night — fell back to night before');
    }
    if (periods.isEmpty) return null;

    // Use the earliest start and latest end across all records.
    final sleepStart = periods.map((p) => p.start).reduce((a, b) => a.isBefore(b) ? a : b);
    final sleepEnd = periods.map((p) => p.end).reduce((a, b) => a.isAfter(b) ? a : b);

    // Read HR samples covering the full sleep window (+ 15 min buffer).
    final samples = await _hc.readHeartRateSamples(
      sleepStart.subtract(const Duration(minutes: 15)),
      sleepEnd.add(const Duration(minutes: 15)),
    );
    if (samples.isEmpty) return null;

    // Flatten all stage intervals from all periods into one sorted list.
    final allIntervals = periods
        .expand((p) => p.stageTimeline)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    // Assign each HR sample a stage by matching against intervals.
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

    // Build ordered SleepHrSegment list (skip buckets with < 2 samples).
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

    // P95 across all samples.
    final allBpms = samples.map((s) => s.value.round()).toList()..sort();
    final p5Bpm  = allBpms[(allBpms.length * 0.05).floor().clamp(0, allBpms.length - 1)];
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

  void _setNoData() {
    _snapshot = null;
    _status = ReadinessStatus.noData;
    notifyListeners();
  }

  Future<ReadinessSnapshot?> _loadSnapshot() async {
    try {
      final raw = await _storage.getSetting(_snapshotKey);
      if (raw == null) return null;
      return ReadinessSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the cached baseline when it was already computed today,
  /// otherwise rebuilds it from the trailing [_baselineDays] window
  /// (excluding last night / today, which are what we score).
  Future<ReadinessBaseline> _baselineFor(
    String todayKey,
    DateTime now,
    Set<HealthReadType> granted,
  ) async {
    try {
      final raw = await _storage.getSetting(_baselineKey);
      if (raw != null) {
        final cached =
            ReadinessBaseline.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (cached.dateKey == todayKey) return cached;
      }
    } catch (_) {
      // Corrupt cache — fall through to recompute.
    }

    final day = DateTime(now.year, now.month, now.day);
    final windowStart = day.subtract(const Duration(days: _baselineDays));

    double? avgSleep;
    var sleepNights = 0;
    if (granted.contains(HealthReadType.sleep)) {
      // End the window at yesterday 18:00 so last night isn't in its own baseline.
      final periods = await _hc.readSleepSessions(
        windowStart,
        day.subtract(const Duration(hours: 6)),
      );
      final nightly = _nightlySleepMinutes(periods);
      sleepNights = nightly.length;
      if (sleepNights > 0) {
        avgSleep = nightly.reduce((a, b) => a + b) / sleepNights;
      }
    }

    double? avgRhr;
    var rhrDays = 0;
    if (granted.contains(HealthReadType.restingHeartRate)) {
      final samples = await _hc.readRestingHeartRate(windowStart, day);
      final daily = _dailyAverages(samples);
      rhrDays = daily.length;
      if (rhrDays > 0) avgRhr = daily.reduce((a, b) => a + b) / rhrDays;
    }

    double? avgHrv;
    var hrvDays = 0;
    if (granted.contains(HealthReadType.hrv)) {
      final samples = await _hc.readHrvRmssd(windowStart, day);
      final daily = _dailyAverages(samples);
      hrvDays = daily.length;
      if (hrvDays > 0) avgHrv = daily.reduce((a, b) => a + b) / hrvDays;
    }

    final baseline = ReadinessBaseline(
      dateKey: todayKey,
      avgSleepMinutes: avgSleep,
      sleepNights: sleepNights,
      avgRestingHr: avgRhr,
      rhrDays: rhrDays,
      avgHrvMs: avgHrv,
      hrvDays: hrvDays,
    );
    await _storage.saveSetting(_baselineKey, jsonEncode(baseline.toJson()));
    return baseline;
  }

  /// Total minutes per night, bucketed by the day the session ENDS on.
  ///
  /// Health Connect (Pixel Watch, etc.) writes multiple records per night —
  /// one per sleep stage or one per awakening gap. Summing gives the real
  /// nightly total; taking max severely under-counts fragmented recordings.
  List<double> _nightlySleepMinutes(List<SleepPeriod> periods) {
    final byNight = <String, int>{};
    for (final p in periods) {
      final key = ReadinessCalculator.dateKey(p.end);
      byNight[key] = (byNight[key] ?? 0) + p.minutes;
    }
    return byNight.values.map((m) => m.toDouble()).toList();
  }

  /// One average per calendar day a sample exists on.
  List<double> _dailyAverages(List<HealthSample> samples) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final s in samples) {
      final key = ReadinessCalculator.dateKey(s.time);
      sums[key] = (sums[key] ?? 0) + s.value;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return sums.entries.map((e) => e.value / counts[e.key]!).toList();
  }

  Future<int?> _lastNightSleepMinutes(
    DateTime now,
    Set<HealthReadType> granted,
  ) async {
    if (!granted.contains(HealthReadType.sleep)) return null;
    final day = DateTime(now.year, now.month, now.day);
    final periods = await _hc.readSleepSessions(
      day.subtract(const Duration(hours: 6)),
      day.add(const Duration(hours: 12)),
    );
    for (final p in periods) {
      final stageInfo = p.hasStages
          ? 'L=${p.lightMinutes} D=${p.deepMinutes} R=${p.remMinutes} A=${p.awakeMinutes}'
          : 'no stages';
      debugPrint('[Readiness]   period ${p.start.toLocal().hour}:${p.start.toLocal().minute.toString().padLeft(2, '0')}'
          '→${p.end.toLocal().hour}:${p.end.toLocal().minute.toString().padLeft(2, '0')}'
          ' actual=${p.minutes}min ($stageInfo)');
    }
    return _calculator.lastNightSleepMinutes(now, periods);
  }

  /// Latest resting-HR record in the past 24h; falls back to the minimum
  /// raw heart-rate sample between 02:00–10:00 today. The fallback is the
  /// only minute-level query and only runs when no RHR record exists.
  Future<double?> _todayRestingHr(
    DateTime now,
    Set<HealthReadType> granted,
  ) async {
    if (granted.contains(HealthReadType.restingHeartRate)) {
      final samples = await _hc.readRestingHeartRate(
        now.subtract(const Duration(hours: 24)),
        now,
      );
      if (samples.isNotEmpty) {
        samples.sort((a, b) => a.time.compareTo(b.time));
        return samples.last.value;
      }
    }
    if (granted.contains(HealthReadType.heartRate)) {
      final day = DateTime(now.year, now.month, now.day);
      final samples = await _hc.readHeartRateSamples(
        day.add(const Duration(hours: 2)),
        day.add(const Duration(hours: 10)),
      );
      if (samples.isNotEmpty) {
        return samples.map((s) => s.value).reduce((a, b) => a < b ? a : b);
      }
    }
    return null;
  }

  Future<double?> _todayHrv(DateTime now, Set<HealthReadType> granted) async {
    if (!granted.contains(HealthReadType.hrv)) return null;
    final samples = await _hc.readHrvRmssd(
      now.subtract(const Duration(hours: 48)),
      now,
    );
    debugPrint('[Readiness] HRV samples (48h): ${samples.length}');
    if (samples.isEmpty) return null;
    samples.sort((a, b) => a.time.compareTo(b.time));
    return samples.last.value;
  }
}
