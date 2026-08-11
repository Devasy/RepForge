// health_data_sync_service.dart — pulls sleep + heart-rate data from Health
// Connect into SqliteStorageService's health_samples/sleep_sessions tables
// so the coach's run_sql_query tool can join them against workout data.
// See docs/superpowers/specs/2026-08-11-health-data-sync-and-coach-sql-design.md.

import '../models/models.dart';
import 'interfaces/health_connect_service_interface.dart';
import 'sqlite_storage_service.dart';

class HealthDataSyncService {
  HealthDataSyncService(this._hc, this._storage, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final IHealthConnectService _hc;
  final SqliteStorageService _storage;
  final DateTime Function() _now;

  static const Duration _backfillWindow = Duration(days: 90);
  static const Duration _lookback = Duration(days: 3);
  static const Duration _throttleWindow = Duration(minutes: 30);

  static const String _sleepWatermarkKey = 'health_sync.sleep';
  static const String _lastRunKey = 'health_sync.last_run';
  static const Map<String, String> _sampleWatermarkKeys = {
    'heart_rate': 'health_sync.heart_rate',
    'resting_heart_rate': 'health_sync.resting_heart_rate',
    'hrv_rmssd': 'health_sync.hrv_rmssd',
  };
  static const Map<String, HealthReadType> _sampleReadTypes = {
    'heart_rate': HealthReadType.heartRate,
    'resting_heart_rate': HealthReadType.restingHeartRate,
    'hrv_rmssd': HealthReadType.hrv,
  };

  /// Pulls any new sleep/HR data since the last sync into SQLite. Skipped if
  /// the last sync ran under 30 minutes ago, unless [force] is true. Each of
  /// the 4 underlying data streams fails independently and best-effort —
  /// one stream throwing never blocks the others or this call. Streams whose
  /// permission hasn't been granted yet are skipped entirely — their
  /// watermark is left untouched so the first sync after granting permission
  /// still performs the full backfill instead of resuming from a watermark
  /// that was silently advanced while unauthorized.
  Future<void> sync({bool force = false}) async {
    final now = _now();
    if (!force) {
      final lastRunRaw = await _storage.getSetting(_lastRunKey);
      final lastRun = lastRunRaw == null ? null : DateTime.tryParse(lastRunRaw);
      if (lastRun != null && now.difference(lastRun) < _throttleWindow) return;
    }

    final granted = await _hc.grantedReadTypes();

    if (granted.contains(HealthReadType.sleep)) {
      await _syncSleep(now);
    }
    for (final entry in _sampleReadTypes.entries) {
      if (!granted.contains(entry.value)) continue;
      final reader = switch (entry.key) {
        'heart_rate' => _hc.readHeartRateSamples,
        'resting_heart_rate' => _hc.readRestingHeartRate,
        'hrv_rmssd' => _hc.readHrvRmssd,
        _ => throw StateError('unknown stream ${entry.key}'),
      };
      await _syncSamples(entry.key, now, reader);
    }

    await _storage.saveSetting(_lastRunKey, now.toIso8601String());
  }

  Future<DateTime> _windowStart(String watermarkKey, DateTime now) async {
    final raw = await _storage.getSetting(watermarkKey);
    final watermark = raw == null ? null : DateTime.tryParse(raw);
    final base = watermark ?? now.subtract(_backfillWindow);
    return base.subtract(_lookback);
  }

  Future<void> _syncSleep(DateTime now) async {
    try {
      final from = await _windowStart(_sleepWatermarkKey, now);
      final periods = await _hc.readSleepSessions(from, now);
      await _storage.upsertSleepSessions(periods);
      await _storage.saveSetting(_sleepWatermarkKey, now.toIso8601String());
    } catch (_) {
      // Best-effort; leave the watermark untouched so the next sync retries.
    }
  }

  Future<void> _syncSamples(
    String type,
    DateTime now,
    Future<List<HealthSample>> Function(DateTime, DateTime) reader,
  ) async {
    final watermarkKey = _sampleWatermarkKeys[type]!;
    try {
      final from = await _windowStart(watermarkKey, now);
      final samples = await reader(from, now);
      await _storage.upsertHealthSamples(type, samples);
      await _storage.saveSetting(watermarkKey, now.toIso8601String());
    } catch (_) {
      // Best-effort; leave the watermark untouched so the next sync retries.
    }
  }
}
