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
  }) : _hc = healthConnectService,
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

  static const Duration _backfillWindow = Duration(days: 30);
  static const Duration _historyBackfillWindow = Duration(days: 90);
  static const Duration _lookback = Duration(days: 3);
  static const Duration _throttleWindow = Duration(minutes: 30);

  static const String _sleepWatermarkKey = 'health_sync.sleep';
  static const String _lastRunKey = 'health_sync.last_run';

  Future<void>? _inFlight;

  /// Pulls any new sleep/HR data since the last sync into SQLite. Skipped if
  /// the last sync ran under 30 minutes ago, unless [force] is true. Each of
  /// the underlying data streams fails independently and best-effort —
  /// one stream throwing never blocks the others or this call. Streams whose
  /// permission hasn't been granted yet are skipped entirely — their
  /// watermark is left untouched so the first sync after granting permission
  /// still performs the full backfill instead of resuming from a watermark
  /// that was silently advanced while unauthorized.
  /// Existing history access enables one 90-day backfill per stream, including
  /// streams that already synced with the default 30-day access window.
  ///
  /// Concurrent calls (e.g. the launch-time sync overlapping a manual
  /// "sync now" tap) share a single in-flight run instead of racing.
  Future<void> sync({bool force = false}) {
    return _inFlight ??= _sync(
      force: force,
    ).whenComplete(() => _inFlight = null);
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

    var historyGranted = false;
    final hc = _hc;
    if (hc is IHealthHistoryReadAccess) {
      try {
        historyGranted = await (hc as IHealthHistoryReadAccess)
            .hasHistoryReadPermission();
      } catch (_) {
        // Unsupported or unavailable history access keeps the default window.
      }
    }

    if (granted.contains(HealthReadType.sleep)) {
      await _syncSleep(now, historyGranted);
    }
    for (final entry in _sampleStreams.entries) {
      final stream = entry.value;
      if (!granted.contains(stream.readType)) continue;
      await _syncSamples(
        type: entry.key,
        now: now,
        stream: stream,
        historyGranted: historyGranted,
      );
    }
    if (granted.contains(HealthReadType.skinTemperature)) {
      const key = 'health_sync.skin_temperature';
      try {
        final from = await _windowStart(key, now, historyGranted);
        final samples = await _hc.readSkinTemperature(from, now);
        await _storage.upsertSkinTemperatureSamples(samples);
        await _saveSuccess(key, now, historyGranted);
      } catch (_) {
        // Unsupported modules, denied permissions and failed pages are retried.
      }
    }

    await _storage.saveSetting(_lastRunKey, now.toIso8601String());
  }

  Future<DateTime> _windowStart(
    String watermarkKey,
    DateTime now,
    bool historyGranted,
  ) async {
    final raw = await _storage.getSetting(watermarkKey);
    final watermark = raw == null ? null : DateTime.tryParse(raw);
    final incrementalStart = watermark?.subtract(_lookback);
    if (historyGranted &&
        await _storage.getSetting('$watermarkKey.history_backfilled') !=
            'true') {
      final historyStart = now.subtract(_historyBackfillWindow);
      return incrementalStart != null && incrementalStart.isBefore(historyStart)
          ? incrementalStart
          : historyStart;
    }
    return incrementalStart ?? now.subtract(_backfillWindow);
  }

  Future<void> _saveSuccess(
    String key,
    DateTime now,
    bool historyGranted,
  ) async {
    await _storage.saveSetting(key, now.toIso8601String());
    if (historyGranted) {
      await _storage.saveSetting('$key.history_backfilled', 'true');
    }
  }

  Future<void> _syncSleep(DateTime now, bool historyGranted) async {
    try {
      final from = await _windowStart(_sleepWatermarkKey, now, historyGranted);
      final periods = await _hc.readSleepSessions(from, now);
      await _storage.upsertSleepSessions(periods);
      await _saveSuccess(_sleepWatermarkKey, now, historyGranted);
    } catch (_) {
      // Best-effort; leave the watermark untouched so the next sync retries.
    }
  }

  Future<void> _syncSamples({
    required String type,
    required DateTime now,
    required _SampleStream stream,
    required bool historyGranted,
  }) async {
    try {
      final from = await _windowStart(stream.watermarkKey, now, historyGranted);
      final samples = await stream.reader(from, now);
      await _storage.upsertHealthSamples(type, samples);
      await _saveSuccess(stream.watermarkKey, now, historyGranted);
    } catch (_) {
      // Best-effort; leave the watermark untouched so the next sync retries.
    }
  }
}
