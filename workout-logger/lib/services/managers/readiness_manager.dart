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
import '../utils/sleep_hr_builder.dart';

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
  HrDaySnapshot? _hrDaySnapshot;

  SleepHrSnapshot? get sleepHrSnapshot => _sleepHrSnapshot;

  /// Today's all-day HR snapshot — backs the dashboard Heart-rate card.
  /// Built best-effort during [refresh]; null when no HR data/permission.
  HrDaySnapshot? get hrDaySnapshot => _hrDaySnapshot;

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
          // Still build the HR snapshots if we don't have them yet.
          if (_sleepHrSnapshot == null || _hrDaySnapshot == null) {
            _sleepHrSnapshot ??= await _buildSleepHrSnapshot(now, granted);
            _hrDaySnapshot ??= await _buildHrDaySnapshot(now, granted);
            notifyListeners();
          }
          return;
        }
      }

      final sleepMinutes = await _lastNightSleepMinutes(now, granted);
      final restingHr = await _todayRestingHr(now, granted);
      final hrv = await _todayHrv(now, granted);

      // Build HR snapshots (best-effort; failure must not affect score).
      try {
        _sleepHrSnapshot = await _buildSleepHrSnapshot(now, granted);
      } catch (e) {
        debugPrint('[Readiness] _buildSleepHrSnapshot failed (non-fatal): $e');
        _sleepHrSnapshot = null;
      }
      try {
        _hrDaySnapshot = await _buildHrDaySnapshot(now, granted);
      } catch (e) {
        debugPrint('[Readiness] _buildHrDaySnapshot failed (non-fatal): $e');
        _hrDaySnapshot = null;
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

  /// Builds last night's overnight HR snapshot for the Sleep HR chart,
  /// falling back to the night before when the watch hasn't synced yet.
  Future<SleepHrSnapshot?> _buildSleepHrSnapshot(
    DateTime now,
    Set<HealthReadType> granted,
  ) =>
      buildSleepHrSnapshot(_hc, now, granted, fallbackToPriorNight: true);

  /// Builds today's all-day HR snapshot for the Heart-rate card.
  Future<HrDaySnapshot?> _buildHrDaySnapshot(
    DateTime now,
    Set<HealthReadType> granted,
  ) =>
      buildHrDaySnapshot(_hc, now, granted);

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
