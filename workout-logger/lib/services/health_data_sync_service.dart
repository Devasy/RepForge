// health_data_sync_service.dart — pulls sleep + heart-rate data from Health
// Connect into SqliteStorageService's health_samples/sleep_sessions tables
// so the coach's run_sql_query tool can join them against workout data.
// See docs/superpowers/specs/2026-08-11-health-data-sync-and-coach-sql-design.md.

import '../models/models.dart';
import 'interfaces/health_connect_service_interface.dart';
import 'sqlite_storage_service.dart';

typedef _SampleReader = Future<List<HealthSample>> Function(DateTime, DateTime);

class _SampleStream {
  const _SampleStream({
    required this.watermarkKey,
    required this.readType,
    required this.reader,
  });

  final String watermarkKey;
  final HealthReadType readType;
  final _SampleReader reader;
}

class HealthDataSyncService {
  HealthDataSyncService({
    required IHealthConnectService healthConnectService,
    required SqliteStorageService storage,
    DateTime Function()? now,
  })  : _hc = healthConnectService,
        _storage = storage,
        _now = now ?? DateTime.now {
    _sampleStreams = {
      'heart_rate': _SampleStream(
        watermarkKey: 'health_sync.heart_rate',
        readType: HealthReadType.heartRate,
        reader: _hc.readHeartRateSamples,
      ),
      'resting_heart_rate': _SampleStream(
        watermarkKey: 'health_sync.resting_heart_rate',
        readType: HealthReadType.restingHeartRate,
        reader: _hc.readRestingHeartRate,
      ),
      'hrv_rmssd': _SampleStream(
        watermarkKey: 'health_sync.hrv_rmssd',
        readType: HealthReadType.hrv,
        reader: _hc.readHrvRmssd,
      ),
    };
  }

  final IHealthConnectService _hc;
  final SqliteStorageService _storage;
  final DateTime Function() _now;

  // Adding a new sample stream only needs one entry here — the watermark key,
  // the permission it depends on, and the reader all live together instead of
  // being repeated across separate keyed maps that could drift apart.
  late final Map<String, _SampleStream> _sampleStreams;

  static const Duration _backfillWindow = Duration(days: 90);
  static const Duration _lookback = Duration(days: 3);
  static const Duration _throttleWindow = Duration(minutes: 30);

  static const String _sleepWatermarkKey = 'health_sync.sleep';
  static const String _lastRunKey = 'health_sync.last_run';

  Future<void>? _inFlight;

  /// Pulls any new sleep/HR data since the last sync into SQLite. Skipped if
  /// the last sync ran under 30 minutes ago, unless [force] is true. Each of
  /// the 4 underlying data streams fails independently and best-effort —
  /// one stream throwing never blocks the others or this call. Streams whose
  /// permission hasn't been granted yet are skipped entirely — their
  /// watermark is left untouched so the first sync after granting permission
  /// still performs the full backfill instead of resuming from a watermark
  /// that was silently advanced while unauthorized.
  ///
  /// Concurrent calls (e.g. the launch-time sync overlapping a manual
  /// "sync now" tap) share a single in-flight run instead of racing.
  Future<void> sync({bool force = false}) {
    return _inFlight ??= _sync(force: force).whenComplete(() => _inFlight = null);
  }

  Future<void> _sync({required bool force}) async {
    final now = _now();
    if (!force) {
      final lastRunRaw = await _storage.getSetting(_lastRunKey);
      final lastRun = lastRunRaw == null ? null : DateTime.tryParse(lastRunRaw);
      if (lastRun != null && now.difference(lastRun) < _throttleWindow) return;
    }

    final Set<HealthReadType> granted;
    try {
      granted = await _hc.grantedReadTypes();
    } catch (_) {
      // Best-effort; leave every watermark untouched so the next sync retries.
      return;
    }

    if (granted.contains(HealthReadType.sleep)) {
      await _syncSleep(now);
    }
    for (final entry in _sampleStreams.entries) {
      final stream = entry.value;
      if (!granted.contains(stream.readType)) continue;
      await _syncSamples(type: entry.key, now: now, stream: stream);
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

  Future<void> _syncSamples({
    required String type,
    required DateTime now,
    required _SampleStream stream,
  }) async {
    try {
      final from = await _windowStart(stream.watermarkKey, now);
      final samples = await stream.reader(from, now);
      await _storage.upsertHealthSamples(type, samples);
      await _storage.saveSetting(stream.watermarkKey, now.toIso8601String());
    } catch (_) {
      // Best-effort; leave the watermark untouched so the next sync retries.
    }
  }
}
