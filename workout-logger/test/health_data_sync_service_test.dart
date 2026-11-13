import 'package:repforge/models/skin_temperature_sample.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:repforge/models/models.dart';
import 'package:repforge/services/health_data_sync_service.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/sqlite_storage_service.dart';

class _RecordingHcService
    implements IHealthConnectService, IHealthHistoryReadAccess {
  bool historyGranted = false;
  bool throwOnHistoryCheck = false;

  @override
  Future<bool> hasHistoryReadPermission() async {
    if (throwOnHistoryCheck) throw Exception('history unavailable');
    return historyGranted;
  }

  @override
  Future<List<SkinTemperatureSample>> readSkinTemperature(DateTime start, DateTime end) async {
    calls.add((method: 'skin_temperature', from: start, to: end));
    if (throwOnSkinTemperature) throw Exception('unsupported or failed page');
    return skinTemperatureSamples;
  }
  List<SkinTemperatureSample> skinTemperatureSamples = const [];
  bool throwOnSkinTemperature = false;

  final List<({String method, DateTime from, DateTime to})> calls = [];
  List<HealthSample> heartRateSamples = const [];
  List<HealthSample> restingHrSamples = const [];
  bool throwOnHeartRate = false;
  Set<HealthReadType> grantedTypes = HealthReadType.values.toSet();

  @override
  Future<List<SleepPeriod>> readSleepSessions(DateTime start, DateTime end) async {
    calls.add((method: 'sleep', from: start, to: end));
    return const [];
  }

  @override
  Future<List<HealthSample>> readHeartRateSamples(DateTime start, DateTime end) async {
    calls.add((method: 'heart_rate', from: start, to: end));
    if (throwOnHeartRate) throw Exception('boom');
    return heartRateSamples;
  }

  @override
  Future<List<HealthSample>> readRestingHeartRate(DateTime start, DateTime end) async {
    calls.add((method: 'resting_heart_rate', from: start, to: end));
    return restingHrSamples;
  }

  @override
  Future<List<HealthSample>> readHrvRmssd(DateTime start, DateTime end) async {
    calls.add((method: 'hrv_rmssd', from: start, to: end));
    return const [];
  }

  @override
  Future<Set<HealthReadType>> grantedReadTypes() async => grantedTypes;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> hasPermissions() async => true;
  @override
  Future<bool> requestReadPermissions() async => true;
  @override
  Future<bool> syncWorkoutSession(
    WorkoutSession session, {
    String? title,
    Map<String, String>? exerciseNames,
  }) async => true;
}

class _FailingHealthStorage extends SqliteStorageService {
  _FailingHealthStorage({required super.databasePathOverride});
  bool failHeartRate = true;

  @override
  Future<void> upsertHealthSamples(
    String type,
    List<HealthSample> samples,
  ) async {
    if (type == 'heart_rate' && failHeartRate) throw StateError('write failed');
    await super.upsertHealthSamples(type, samples);
  }
}

Future<List<Map<String, Object?>>> _rawQuery(
  SqliteStorageService s,
  String sql, [
  List<Object?>? args,
]) async {
  final db = await openReadOnlyDatabase(s.databasePath, singleInstance: false);
  final rows = await db.rawQuery(sql, args);
  await db.close();
  return rows;
}

void main() {
  late SqliteStorageService storage;
  late _RecordingHcService hc;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    storage = SqliteStorageService(databasePathOverride: inMemoryDatabasePath);
    await storage.init();
    hc = _RecordingHcService();
  });

  tearDown(() async {
    final path = storage.databasePath;
    await storage.close();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('first sync defaults to 30 days without history access', () async {
    final now = DateTime(2026, 8, 11, 9);
    final service = HealthDataSyncService(healthConnectService: hc, storage: storage, now: () => now);

    await service.sync();

    final sleepCall = hc.calls.firstWhere((c) => c.method == 'sleep');
    expect(sleepCall.to, now);
    expect(sleepCall.from, now.subtract(const Duration(days: 30)));
    for (final call in hc.calls) {
      expect(call.from, now.subtract(const Duration(days: 30)));
      expect(await storage.getSetting(
        'health_sync.${call.method}.history_backfilled'), isNull);
    }
  });

  test(
    'granted history backfills 90 days for every authorized stream',
    () async {
      hc.historyGranted = true;
      final now = DateTime(2026, 8, 11, 9);
      final service = HealthDataSyncService(
        healthConnectService: hc,
        storage: storage,
        now: () => now,
      );
      await service.sync(force: true);
      expect(hc.calls, hasLength(5));
      for (final call in hc.calls) {
        expect(call.from, now.subtract(const Duration(days: 90)));
        expect(
          await storage.getSetting(
            'health_sync.' + call.method + '.history_backfilled',
          ),
          'true',
        );
      }
    },
  );

  test('failed history check retains the default 30-day window', () async {
    hc.throwOnHistoryCheck = true;
    final now = DateTime(2026, 8, 11, 9);
    await HealthDataSyncService(
      healthConnectService: hc,
      storage: storage,
      now: () => now,
    ).sync(force: true);
    for (final call in hc.calls) {
      expect(call.from, now.subtract(const Duration(days: 30)));
      expect(
        await storage.getSetting(
          'health_sync.' + call.method + '.history_backfilled',
        ),
        isNull,
      );
    }
  });

  test(
    'later history grant backfills old watermarks once per stream',
    () async {
      var now = DateTime(2026, 8, 11, 9);
      final service = HealthDataSyncService(
        healthConnectService: hc,
        storage: storage,
        now: () => now,
      );
      await service.sync(force: true);
      hc.calls.clear();
      hc.historyGranted = true;
      hc.throwOnSkinTemperature = true;
      now = now.add(const Duration(days: 1));
      await service.sync(force: true);
      for (final call in hc.calls) {
        expect(call.from, now.subtract(const Duration(days: 90)));
      }
      expect(
        await storage.getSetting(
          'health_sync.skin_temperature.history_backfilled',
        ),
        isNull,
      );
      expect(
        await storage.getSetting('health_sync.skin_temperature'),
        now.subtract(const Duration(days: 1)).toIso8601String(),
      );

      final backfillRun = now;
      now = now.add(const Duration(days: 1));
      hc.throwOnSkinTemperature = false;
      hc.calls.clear();
      // Recreating the service proves backfill completion survives a restart.
      await HealthDataSyncService(
        healthConnectService: hc,
        storage: storage,
        now: () => now,
      ).sync(force: true);
      for (final call in hc.calls) {
        expect(
          call.from,
          call.method == 'skin_temperature'
              ? now.subtract(const Duration(days: 90))
              : backfillRun.subtract(const Duration(days: 3)),
        );
      }
      hc.calls.clear();
      await service.sync(force: true);
      for (final call in hc.calls) {
        expect(call.from, now.subtract(const Duration(days: 3)));
      }
    },
  );

  test(
    'failed persistence leaves history pending and watermark unchanged',
    () async {
      final path = storage.databasePath;
      await storage.close();
      storage = _FailingHealthStorage(databasePathOverride: path);
      await storage.init();
      hc.historyGranted = true;
      final now = DateTime(2026, 8, 11, 9);
      final old = now.subtract(const Duration(days: 1));
      await storage.saveSetting(
        'health_sync.heart_rate',
        old.toIso8601String(),
      );
      final service = HealthDataSyncService(
        healthConnectService: hc,
        storage: storage,
        now: () => now,
      );
      await service.sync(force: true);
      expect(
        await storage.getSetting('health_sync.heart_rate'),
        old.toIso8601String(),
      );
      expect(
        await storage.getSetting('health_sync.heart_rate.history_backfilled'),
        isNull,
      );
      expect(
        await storage.getSetting('health_sync.sleep.history_backfilled'),
        'true',
      );
      (storage as _FailingHealthStorage).failHeartRate = false;
      hc.calls.clear();
      await service.sync(force: true);
      expect(
        hc.calls.firstWhere((c) => c.method == 'heart_rate').from,
        now.subtract(const Duration(days: 90)),
      );
      expect(
        await storage.getSetting('health_sync.heart_rate.history_backfilled'),
        'true',
      );
    },
  );

  test('temperature preserves bridge data, separates sources and joins sleep', () async {
    final start = DateTime(2026, 8, 10, 22);
    final end = DateTime(2026, 8, 11, 7);
    final time = start.add(const Duration(hours: 2));
    hc.skinTemperatureSamples = [
      for (final source in ['bridge.one', 'bridge.two'])
        SkinTemperatureSample(
          recordId: 'record', recordStart: start, recordEnd: end,
          time: time, deltaCelsius: -0.25,
          baselineCelsius: source == 'bridge.one' ? 33.5 : null,
          sourcePackage: source, measurementLocation: 'wrist',
        ),
    ];
    await storage.upsertSleepSessions([SleepPeriod(start: start, end: end)]);
    final service = HealthDataSyncService(
      healthConnectService: hc, storage: storage, now: () => end,
    );
    await service.sync(force: true);
    await service.sync(force: true);
    final rows = await _rawQuery(storage,
      'SELECT t.* FROM skin_temperature_samples t JOIN sleep_sessions s '
      'ON t.timestamp >= s.start_ts AND t.timestamp < s.end_ts '
      'ORDER BY source_package');
    expect(rows, hasLength(2));
    expect(rows.first['delta_c'], -0.25);
    expect(rows.first['baseline_c'], 33.5);
    expect(rows.last['baseline_c'], isNull);
    expect(rows.first['utc_ts'], time.toUtc().toIso8601String());
    expect(rows.first['measurement_location'], 'wrist');
  });

  test('HealthBridge nightly comparison reconstructs absolute temperatures', () async {
    // HealthBridge's RecordMapper uses the session summary/sample mean as its
    // baseline. Both nights have zero mean delta despite being 1 C apart.
    final start = DateTime(2026, 11, 9, 22);
    hc.skinTemperatureSamples = [
      for (var night = 0; night < 2; night++)
        for (var minute = 0; minute < 2; minute++)
          SkinTemperatureSample(
            recordId: 'night-$night',
            recordStart: start.add(Duration(days: night)),
            recordEnd: start.add(Duration(days: night, hours: 8)),
            time: start.add(Duration(days: night, minutes: minute + 1)),
            deltaCelsius: minute == 0 ? -0.1 : 0.1,
            baselineCelsius: 33.8 + night,
            sourcePackage: 'com.repforge.healthbridge',
            measurementLocation: 'wrist',
          ),
    ];
    await storage.upsertSleepSessions([
      for (var night = 0; night < 2; night++)
        SleepPeriod(
          start: start.add(Duration(days: night)),
          end: start.add(Duration(days: night, hours: 8)),
        ),
    ]);
    final service = HealthDataSyncService(
      healthConnectService: hc,
      storage: storage,
      now: () => start.add(const Duration(days: 2)),
    );
    await service.sync(force: true);
    final rows = await _rawQuery(storage,
      'SELECT s.id, AVG(t.delta_c) AS mean_delta, '
      'AVG(t.baseline_c + t.delta_c) AS mean_skin_c '
      'FROM skin_temperature_samples t JOIN sleep_sessions s '
      'ON t.timestamp >= s.start_ts AND t.timestamp < s.end_ts '
      'WHERE t.source_package = \'com.repforge.healthbridge\' '
      'AND t.measurement_location = \'wrist\' '
      'GROUP BY s.id ORDER BY s.id');
    expect(rows, hasLength(2));
    expect(rows.first['mean_delta'], closeTo(0, 1e-9));
    expect(rows.last['mean_delta'], closeTo(0, 1e-9));
    expect(rows.first['mean_skin_c'], closeTo(33.8, 1e-9));
    expect(rows.last['mean_skin_c'], closeTo(34.8, 1e-9));
  });

  test('temperature failure leaves watermark and other streams usable', () async {
    hc.throwOnSkinTemperature = true;
    final now = DateTime(2026, 8, 11, 9);
    final service = HealthDataSyncService(
      healthConnectService: hc, storage: storage, now: () => now,
    );
    await service.sync(force: true);
    expect(await storage.getSetting('health_sync.skin_temperature'), isNull);
    expect(await storage.getSetting('health_sync.hrv_rmssd'), isNotNull);
    hc.throwOnSkinTemperature = false;
    hc.calls.clear();
    await service.sync(force: true);
    expect(hc.calls.firstWhere((c) => c.method == 'skin_temperature').from,
      now.subtract(const Duration(days: 30)));
  });

  test('temperature grant after upgrade retains full initial backfill', () async {
    hc.grantedTypes.remove(HealthReadType.skinTemperature);
    final now = DateTime(2026, 8, 11, 9);
    final service = HealthDataSyncService(
      healthConnectService: hc, storage: storage, now: () => now,
    );
    await service.sync(force: true);
    expect(hc.calls.any((c) => c.method == 'skin_temperature'), isFalse);
    expect(await storage.getSetting('health_sync.skin_temperature'), isNull);
    hc.grantedTypes.add(HealthReadType.skinTemperature);
    await service.sync(force: true);
    expect(hc.calls.firstWhere((c) => c.method == 'skin_temperature').from,
      now.subtract(const Duration(days: 30)));
  });

  test('v8 database upgrade adds temperature without losing existing data', () async {
    await storage.saveSetting('keep', 'value');
    final path = storage.databasePath;
    await storage.close();
    final legacy = await openDatabase(path);
    await legacy.execute('DROP TABLE skin_temperature_samples');
    await legacy.execute('PRAGMA user_version = 8');
    await legacy.close();
    storage = SqliteStorageService(databasePathOverride: path);
    await storage.init();
    expect(await storage.getSetting('keep'), 'value');
    expect(await _rawQuery(storage, 'SELECT * FROM skin_temperature_samples'), isEmpty);
  });

  test('second sync only re-fetches from watermark minus the 3-day lookback', () async {
    final firstRun = DateTime(2026, 8, 1, 9);
    final secondRun = DateTime(2026, 8, 11, 9);
    var current = firstRun;
    final service = HealthDataSyncService(healthConnectService: hc, storage: storage, now: () => current);

    await service.sync(force: true);
    hc.calls.clear();
    current = secondRun;
    await service.sync(force: true);

    final sleepCall = hc.calls.firstWhere((c) => c.method == 'sleep');
    expect(sleepCall.from, firstRun.subtract(const Duration(days: 3)));
    expect(sleepCall.to, secondRun);
  });

  test('a sync within the 30-minute throttle window is skipped unless forced', () async {
    final firstRun = DateTime(2026, 8, 11, 9, 0);
    final soonAfter = DateTime(2026, 8, 11, 9, 10);
    var current = firstRun;
    final service = HealthDataSyncService(healthConnectService: hc, storage: storage, now: () => current);

    await service.sync();
    hc.calls.clear();
    current = soonAfter;
    await service.sync();

    expect(hc.calls, isEmpty);
  });

  test('force:true bypasses the throttle', () async {
    final firstRun = DateTime(2026, 8, 11, 9, 0);
    final soonAfter = DateTime(2026, 8, 11, 9, 10);
    var current = firstRun;
    final service = HealthDataSyncService(healthConnectService: hc, storage: storage, now: () => current);

    await service.sync();
    hc.calls.clear();
    current = soonAfter;
    await service.sync(force: true);

    expect(hc.calls, isNotEmpty);
  });

  test('re-syncing the same sample does not duplicate rows', () async {
    final now = DateTime(2026, 8, 11, 9);
    hc.heartRateSamples = [HealthSample(time: DateTime(2026, 8, 10, 22), value: 62)];
    final service = HealthDataSyncService(healthConnectService: hc, storage: storage, now: () => now);

    await service.sync(force: true);
    await service.sync(force: true);

    final rows = await _rawQuery(
      storage,
      "SELECT COUNT(*) AS c FROM health_samples WHERE type = 'heart_rate'",
    );
    expect(rows.first['c'], 1);
  });

  test('a stream that throws does not block the others and leaves its watermark untouched', () async {
    final now = DateTime(2026, 8, 11, 9);
    hc.throwOnHeartRate = true;
    hc.restingHrSamples = [HealthSample(time: now, value: 55)];
    final service = HealthDataSyncService(healthConnectService: hc, storage: storage, now: () => now);

    await service.sync(force: true);

    expect(await storage.getSetting('health_sync.heart_rate'), isNull);
    expect(await storage.getSetting('health_sync.resting_heart_rate'), now.toIso8601String());

    final rows = await _rawQuery(
      storage,
      "SELECT COUNT(*) AS c FROM health_samples WHERE type = 'resting_heart_rate'",
    );
    expect(rows.first['c'], 1);
  });

  test('an ungranted stream is skipped entirely and its watermark never advances', () async {
    final now = DateTime(2026, 8, 11, 9);
    // Permission not yet granted for heart rate — simulates first launch
    // before the user has opened Health Connect settings.
    hc.grantedTypes = {
      HealthReadType.sleep,
      HealthReadType.restingHeartRate,
      HealthReadType.hrv,
    };
    final service = HealthDataSyncService(healthConnectService: hc, storage: storage, now: () => now);

    await service.sync(force: true);

    // The reader for the ungranted stream must never even be called.
    expect(hc.calls.any((c) => c.method == 'heart_rate'), isFalse);
    // And critically, its watermark must stay unset so a later grant still
    // triggers the full initial backfill instead of resuming from `now`.
    expect(await storage.getSetting('health_sync.heart_rate'), isNull);
  });
}
