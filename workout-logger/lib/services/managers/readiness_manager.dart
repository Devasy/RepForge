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
    if (!_settings.readinessEnabled) return;

    try {
      final now = DateTime.now();
      final todayKey = ReadinessCalculator.dateKey(now);

      final cached = await _loadSnapshot();
      if (cached != null && cached.dateKey == todayKey) {
        // Same-day cache renders immediately; skip the re-fetch inside TTL.
        _snapshot = cached;
        _status = ReadinessStatus.ready;
        notifyListeners();
        if (!force && now.difference(cached.computedAt) < _snapshotTtl) return;
      }

      final granted = await _hc.grantedReadTypes();
      if (granted.isEmpty) {
        _setNoData();
        return;
      }

      final baseline = await _baselineFor(todayKey, now, granted);
      final snapshot = _calculator.compute(
        today: now,
        baseline: baseline,
        lastNightSleepMinutes: await _lastNightSleepMinutes(now, granted),
        todayRestingHr: await _todayRestingHr(now, granted),
        todayHrvMs: await _todayHrv(now, granted),
      );

      if (snapshot.score == null) {
        _setNoData();
        return;
      }

      _snapshot = snapshot;
      _status = ReadinessStatus.ready;
      await _storage.saveSetting(_snapshotKey, jsonEncode(snapshot.toJson()));
      notifyListeners();
    } catch (e) {
      debugPrint('ReadinessManager: refresh failed: $e');
      _setNoData();
    }
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

  /// One value per night: the longest sleep period attributed to the day it
  /// ends on, so split records don't count as separate nights.
  List<double> _nightlySleepMinutes(List<SleepPeriod> periods) {
    final byNight = <String, int>{};
    for (final p in periods) {
      final key = ReadinessCalculator.dateKey(p.end);
      final minutes = p.minutes;
      if (minutes > (byNight[key] ?? 0)) byNight[key] = minutes;
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
    return _calculator.lastNightSleep(now, periods)?.minutes;
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
      now.subtract(const Duration(hours: 24)),
      now,
    );
    if (samples.isEmpty) return null;
    samples.sort((a, b) => a.time.compareTo(b.time));
    return samples.last.value;
  }
}
