// Health History Manager
//
// Serves arbitrary-range sleep & heart-rate data for the detail screens.
// Stateless w.r.t. UI (not a ChangeNotifier) — screens drive it via
// FutureBuilder. The Health Connect service already reads any date range;
// this manager owns the windowing, bucketing and light caching on top.
//
// Performance: Day/Week use full HR samples (heavy, cached per immutable past
// day). Month/Year use restingHeartRate records (one/day, light) so a year
// never fans out into 365 sample queries.

import 'dart:convert';

import '../../models/models.dart';
import '../../models/sleep_hr_models.dart';
import '../../models/workout_hr_models.dart';
import '../interfaces/health_connect_service_interface.dart';
import '../interfaces/storage_service_interface.dart';
import '../utils/sleep_hr_builder.dart';
import '../utils/workout_hr_builder.dart';

class HealthHistoryManager {
  final IHealthConnectService _hc;
  final IStorageService _storage;

  HealthHistoryManager(this._hc, this._storage);

  // ── Date helpers ────────────────────────────────────────────────────────────

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The [start, end) window covered by [g] anchored at [anchor].
  /// Day → that day. Week → 7 days ending on anchor. Month/Year → calendar unit.
  static ({DateTime start, DateTime end}) rangeFor(
    DateTime anchor,
    HealthGranularity g,
  ) {
    final day = _midnight(anchor);
    switch (g) {
      case HealthGranularity.day:
        return (start: day, end: day.add(const Duration(days: 1)));
      case HealthGranularity.week:
        final start = day.subtract(const Duration(days: 6));
        return (start: start, end: day.add(const Duration(days: 1)));
      case HealthGranularity.month:
        final start = DateTime(day.year, day.month, 1);
        final end = DateTime(day.year, day.month + 1, 1);
        return (start: start, end: end);
      case HealthGranularity.year:
        return (start: DateTime(day.year, 1, 1), end: DateTime(day.year + 1, 1, 1));
    }
  }

  /// Steps the anchor by one unit of [g] in [dir] (+1 forward, -1 back).
  static DateTime stepBy(DateTime anchor, HealthGranularity g, int dir) {
    final day = _midnight(anchor);
    switch (g) {
      case HealthGranularity.day:
        return day.add(Duration(days: dir));
      case HealthGranularity.week:
        return day.add(Duration(days: 7 * dir));
      case HealthGranularity.month:
        return DateTime(day.year, day.month + dir, day.day);
      case HealthGranularity.year:
        return DateTime(day.year + dir, day.month, day.day);
    }
  }

  Future<Set<HealthReadType>> _granted() => _hc.grantedReadTypes();

  /// HR breakdown for one recorded workout: curve, peak/avg/min, exercise
  /// sections, and per-rest HR recovery. Null when no HR data covers the window.
  Future<WorkoutHrAnalysis?> workoutHr(WorkoutSession session) async {
    final granted = await _granted();
    return buildWorkoutHrAnalysis(_hc, session, granted);
  }

  // ── Day detail ──────────────────────────────────────────────────────────────

  /// Overnight HR snapshot for the night ending the morning of [morning].
  Future<SleepHrSnapshot?> sleepNight(DateTime morning) async {
    final granted = await _granted();
    return buildSleepHrSnapshot(_hc, morning, granted);
  }

  /// All-day HR snapshot for [day]. Immutable past days are cached permanently;
  /// today is always rebuilt (data is still accumulating).
  Future<HrDaySnapshot?> hrDay(DateTime day) async {
    final d = _midnight(day);
    final isPast = d.isBefore(_midnight(DateTime.now()));
    final cacheKey = 'hr.day.${dateKey(d)}';

    if (isPast) {
      final cached = await _readCachedHrDay(cacheKey);
      if (cached != null) return cached;
    }

    final granted = await _granted();
    final snap = await buildHrDaySnapshot(_hc, d, granted);
    if (snap != null && isPast) {
      try {
        await _storage.saveSetting(cacheKey, jsonEncode(snap.toJson()));
      } catch (_) {/* cache best-effort */}
    }
    return snap;
  }

  Future<HrDaySnapshot?> _readCachedHrDay(String key) async {
    try {
      final raw = await _storage.getSetting(key);
      if (raw == null) return null;
      return HrDaySnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Sleep aggregation ─────────────────────────────────────────────────────────

  /// Aggregated sleep-duration bars for [g] anchored at [anchor].
  /// Day/Week/Month → one bar per night; Year → 12 monthly averages.
  /// Bars are emitted for every calendar slot in range (zero-filled) so the
  /// chart axis stays stable.
  Future<List<SleepDayBar>> sleepBars(
    DateTime anchor,
    HealthGranularity g,
  ) async {
    final granted = await _granted();
    if (!granted.contains(HealthReadType.sleep)) return const [];

    final r = rangeFor(anchor, g);
    // Pad the end so sleep ending the morning after the last day is captured.
    final periods =
        await _hc.readSleepSessions(r.start, r.end.add(const Duration(hours: 12)));

    // Group nightly totals by the day the session ENDS on (handles fragmented
    // Pixel-Watch records — sum, don't max).
    final byNight = <String, _StageTally>{};
    for (final p in periods) {
      final key = dateKey(p.end);
      final t = byNight.putIfAbsent(key, () => _StageTally());
      t.add(p);
    }

    if (g == HealthGranularity.year) {
      // Average each month's nightly totals.
      final byMonth = <int, List<_StageTally>>{};
      byNight.forEach((key, tally) {
        final d = DateTime.parse(key);
        byMonth.putIfAbsent(d.month, () => []).add(tally);
      });
      return List.generate(12, (i) {
        final month = i + 1;
        final tallies = byMonth[month] ?? const [];
        final date = DateTime(_midnight(anchor).year, month, 1);
        if (tallies.isEmpty) {
          return SleepDayBar(
              date: date, totalMinutes: 0, deepMin: 0, remMin: 0, lightMin: 0, awakeMin: 0);
        }
        final n = tallies.length;
        return SleepDayBar(
          date: date,
          totalMinutes: tallies.fold(0, (s, t) => s + t.total) ~/ n,
          deepMin: tallies.fold(0, (s, t) => s + t.deep) ~/ n,
          remMin: tallies.fold(0, (s, t) => s + t.rem) ~/ n,
          lightMin: tallies.fold(0, (s, t) => s + t.light) ~/ n,
          awakeMin: tallies.fold(0, (s, t) => s + t.awake) ~/ n,
        );
      });
    }

    // Per-night bars for each day in the range.
    final bars = <SleepDayBar>[];
    for (var d = r.start; d.isBefore(r.end); d = d.add(const Duration(days: 1))) {
      final t = byNight[dateKey(d)];
      bars.add(SleepDayBar(
        date: d,
        totalMinutes: t?.total ?? 0,
        deepMin: t?.deep ?? 0,
        remMin: t?.rem ?? 0,
        lightMin: t?.light ?? 0,
        awakeMin: t?.awake ?? 0,
      ));
    }
    return bars;
  }

  // ── HR aggregation ────────────────────────────────────────────────────────────

  /// Aggregated HR range bars for [g] anchored at [anchor].
  /// Week → per-day min/max from full samples (cached). Month/Year → daily /
  /// monthly min–max of resting-HR records (light query path).
  Future<List<HrRangeBar>> hrBars(
    DateTime anchor,
    HealthGranularity g,
  ) async {
    final granted = await _granted();
    if (!granted.contains(HealthReadType.heartRate) &&
        !granted.contains(HealthReadType.restingHeartRate)) {
      return const [];
    }
    final r = rangeFor(anchor, g);

    if (g == HealthGranularity.week) {
      final bars = <HrRangeBar>[];
      for (var d = r.start; d.isBefore(r.end); d = d.add(const Duration(days: 1))) {
        final snap = await hrDay(d);
        bars.add(HrRangeBar(
          date: d,
          label: _weekdayLabel(d),
          minBpm: snap?.minBpm ?? 0,
          maxBpm: snap?.maxBpm ?? 0,
          avgBpm: snap?.avgBpm ?? 0,
          restingBpm: snap?.restingBpm,
        ));
      }
      return bars;
    }

    // Month / Year → resting-HR records only.
    final rhr = granted.contains(HealthReadType.restingHeartRate)
        ? await _hc.readRestingHeartRate(r.start, r.end)
        : <HealthSample>[];

    final byDay = <String, List<double>>{};
    for (final s in rhr) {
      byDay.putIfAbsent(dateKey(s.time), () => []).add(s.value);
    }

    if (g == HealthGranularity.month) {
      final bars = <HrRangeBar>[];
      for (var d = r.start; d.isBefore(r.end); d = d.add(const Duration(days: 1))) {
        final vals = byDay[dateKey(d)] ?? const [];
        bars.add(_rangeBar(d, '${d.day}', vals));
      }
      return bars;
    }

    // Year → 12 monthly bars.
    final byMonth = <int, List<double>>{};
    byDay.forEach((key, vals) {
      final m = DateTime.parse(key).month;
      byMonth.putIfAbsent(m, () => []).addAll(vals);
    });
    return List.generate(12, (i) {
      final month = i + 1;
      final date = DateTime(_midnight(anchor).year, month, 1);
      return _rangeBar(date, _monthLabel(month), byMonth[month] ?? const []);
    });
  }

  HrRangeBar _rangeBar(DateTime date, String label, List<double> vals) {
    if (vals.isEmpty) {
      return HrRangeBar(
          date: date, label: label, minBpm: 0, maxBpm: 0, avgBpm: 0, restingBpm: null);
    }
    final mn = vals.reduce((a, b) => a < b ? a : b);
    final mx = vals.reduce((a, b) => a > b ? a : b);
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    return HrRangeBar(
      date: date,
      label: label,
      minBpm: mn.round(),
      maxBpm: mx.round(),
      avgBpm: avg,
      restingBpm: avg.round(),
    );
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
  String _weekdayLabel(DateTime d) => _weekdays[d.weekday - 1];
  String _monthLabel(int month) => _months[month - 1];
}

/// Accumulates stage minutes for one night across fragmented records.
class _StageTally {
  int total = 0;
  int deep = 0;
  int rem = 0;
  int light = 0;
  int awake = 0;

  void add(SleepPeriod p) {
    total += p.minutes;
    deep += p.deepMinutes ?? 0;
    rem += p.remMinutes ?? 0;
    light += p.lightMinutes ?? 0;
    awake += p.awakeMinutes ?? 0;
  }
}
