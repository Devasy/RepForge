# Health Data Sync (Sleep + HR) into SQLite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist sleep and heart-rate data from Health Connect into new SQLite tables so the AI coach's `run_sql_query` tool can join workout data against health data in a single query.

**Architecture:** A new `HealthDataSyncService` reads from the existing `IHealthConnectService` abstraction and writes into three new tables via new methods added directly on `SqliteStorageService` (not on `IStorageService` — this data has no manager/provider consumer, matching how `SqlQueryService` already bypasses that interface). Sync runs once per app launch (throttled 30 min) plus on-demand via a "Sync now" button on the Profile screen. `run_sql_query`'s embedded schema description is extended with the new tables.

**Tech Stack:** Flutter/Dart, `sqflite` (already a dependency), `sqflite_common_ffi` (test-only, already a dev dependency), `provider`.

## Global Constraints

- No new pubspec dependencies.
- No changes to `IStorageService`'s method signatures, `MockStorageService`, or any manager/provider — the new tables and methods are additive on `SqliteStorageService` only.
- 90-day backfill window on first sync per stream; subsequent syncs re-fetch from `watermark - 3 days` (look-back for late corrections).
- 30-minute throttle between non-forced syncs; manual "Sync now" always forces.
- Health sync is only constructed/run when the active backend is `SqliteStorageService` (guarded like `SqlQueryService` already is in `main.dart`).
- The existing live `get_health_metrics` coach tool is untouched.
- Timestamps are stored as ISO8601 strings, matching every other table in this schema.

Reference spec: `docs/superpowers/specs/2026-08-11-health-data-sync-and-coach-sql-design.md`.

---

### Task 1: Schema + upsert methods on `SqliteStorageService`

**Files:**
- Modify: `workout-logger/lib/services/sqlite_storage_service.dart`
- Test: `workout-logger/test/sqlite_storage_service_test.dart`

**Interfaces:**
- Produces (used by Task 2): `SqliteStorageService.upsertHealthSamples(String type, List<HealthSample> samples) -> Future<void>`, `SqliteStorageService.upsertSleepSessions(List<SleepPeriod> periods) -> Future<void>`, and the existing `getSetting`/`saveSetting` (unchanged, already public) used for sync watermarks.
- Produces (used by Task 5): tables `health_samples(id, type, timestamp, value)`, `sleep_sessions(id, start_ts, end_ts, light_min, deep_min, rem_min, awake_min)`, `sleep_stage_intervals(sleep_session_id, start_ts, end_ts, stage)`.
- Consumes: `HealthSample { DateTime time, double value }` and `SleepPeriod { DateTime start, end; int? lightMinutes, deepMinutes, remMinutes, awakeMinutes; List<SleepStageInterval> stageTimeline }` / `SleepStageInterval { DateTime start, end; String stage }` — all already defined in `lib/models/models.dart`.

- [ ] **Step 1: Write the failing tests**

Add `import 'dart:io';` to the top of `workout-logger/test/sqlite_storage_service_test.dart` (alongside the existing `dart:convert` import), and add this helper + these three tests anywhere inside `main()` (e.g. right after the existing `group('SqliteStorageService — init', ...)` block):

```dart
  Future<List<Map<String, Object?>>> rawQuery(
    SqliteStorageService s,
    String sql, [
    List<Object?>? args,
  ]) async {
    final db = await openReadOnlyDatabase(s.databasePath, singleInstance: false);
    final rows = await db.rawQuery(sql, args);
    await db.close();
    return rows;
  }

  group('SqliteStorageService — health data', () {
    test('upsertHealthSamples replaces duplicates on (type, timestamp)', () async {
      final t = DateTime(2026, 8, 10, 22, 30);
      await storage.upsertHealthSamples('heart_rate', [HealthSample(time: t, value: 60)]);
      await storage.upsertHealthSamples('heart_rate', [HealthSample(time: t, value: 65)]);

      final rows = await rawQuery(
        storage,
        "SELECT value FROM health_samples WHERE type = 'heart_rate'",
      );
      expect(rows.length, 1);
      expect(rows.first['value'], 65.0);
    });

    test('upsertSleepSessions replaces stage intervals for a re-synced session', () async {
      final start = DateTime(2026, 8, 10, 23);
      final end = DateTime(2026, 8, 11, 7);

      await storage.upsertSleepSessions([
        SleepPeriod(
          start: start,
          end: end,
          lightMinutes: 200,
          deepMinutes: 60,
          remMinutes: 100,
          awakeMinutes: 10,
          stageTimeline: [
            SleepStageInterval(start: start, end: start.add(const Duration(hours: 1)), stage: 'light'),
          ],
        ),
      ]);

      await storage.upsertSleepSessions([
        SleepPeriod(
          start: start,
          end: end,
          lightMinutes: 190,
          deepMinutes: 70,
          remMinutes: 100,
          awakeMinutes: 10,
          stageTimeline: [
            SleepStageInterval(start: start, end: start.add(const Duration(hours: 2)), stage: 'deep'),
          ],
        ),
      ]);

      final sessions = await rawQuery(storage, 'SELECT id, deep_min FROM sleep_sessions');
      expect(sessions.length, 1);
      expect(sessions.first['deep_min'], 70);

      final intervals = await rawQuery(
        storage,
        'SELECT stage FROM sleep_stage_intervals WHERE sleep_session_id = ?',
        [sessions.first['id']],
      );
      expect(intervals.length, 1);
      expect(intervals.first['stage'], 'deep');
    });
  });

  group('SqliteStorageService — schema upgrade', () {
    test('onUpgrade adds health tables to a pre-existing v1 database', () async {
      final path =
          '${Directory.systemTemp.path}/sqlite_v1_upgrade_${DateTime.now().microsecondsSinceEpoch}.db';
      final v1 = await openDatabase(
        path,
        version: 1,
        onCreate: (db, v) async {
          await db.execute('''CREATE TABLE muscle_groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            growth_rate REAL NOT NULL DEFAULT 0,
            last_updated TEXT NOT NULL
          )''');
        },
      );
      await v1.close();

      final upgraded = SqliteStorageService(databasePathOverride: path);
      await upgraded.init();

      final tableRows = await rawQuery(
        upgraded,
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tableRows.map((r) => r['name'] as String).toSet();
      expect(names, containsAll(['health_samples', 'sleep_sessions', 'sleep_stage_intervals']));

      await File(path).delete();
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/sqlite_storage_service_test.dart` (from `workout-logger/`)
Expected: FAIL — `upsertHealthSamples`/`upsertSleepSessions` are not defined on `SqliteStorageService`, and the upgrade test fails because `health_samples` etc. don't exist yet.

- [ ] **Step 3: Implement the schema + upsert methods**

In `workout-logger/lib/services/sqlite_storage_service.dart`:

Change the version constant:

```dart
  static const int _dbVersion = 2;
```

Add a new const list right above `_schemaStatements`, and spread it into `_schemaStatements`'s closing entries (immediately after the existing `'CREATE INDEX idx_sessions_date ON sessions(date)',` line):

```dart
  /// Added in schema v2 (health sync). Kept separate from the rest of
  /// [_schemaStatements] so `onUpgrade` can run exactly these statements
  /// against pre-v2 databases without re-running the full v1 DDL.
  static const List<String> _healthSchemaStatements = [
    '''CREATE TABLE health_samples (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      value REAL NOT NULL
    )''',
    'CREATE UNIQUE INDEX idx_health_samples_unique ON health_samples(type, timestamp)',
    'CREATE INDEX idx_health_samples_type_ts ON health_samples(type, timestamp)',
    '''CREATE TABLE sleep_sessions (
      id TEXT PRIMARY KEY,
      start_ts TEXT NOT NULL,
      end_ts TEXT NOT NULL,
      light_min INTEGER,
      deep_min INTEGER,
      rem_min INTEGER,
      awake_min INTEGER
    )''',
    'CREATE INDEX idx_sleep_sessions_start ON sleep_sessions(start_ts)',
    '''CREATE TABLE sleep_stage_intervals (
      sleep_session_id TEXT NOT NULL,
      start_ts TEXT NOT NULL,
      end_ts TEXT NOT NULL,
      stage TEXT NOT NULL
    )''',
    'CREATE INDEX idx_sleep_stage_session ON sleep_stage_intervals(sleep_session_id)',
  ];

  static const List<String> _schemaStatements = [
    // ...existing statements unchanged...
    'CREATE INDEX idx_sessions_date ON sessions(date)',
    ..._healthSchemaStatements,
  ];
```

Update the `openDatabase` call inside `init()` to add `onUpgrade`:

```dart
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        for (final statement in _schemaStatements) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final statement in _healthSchemaStatements) {
            await db.execute(statement);
          }
        }
      },
    );
```

Add a new section right after `// ==================== STATS ====================` and its method (before `// ==================== EXPORT / IMPORT ====================`):

```dart
  // ==================== HEALTH DATA (coach SQL joins only) ====================
  // Written by HealthDataSyncService; never read through IStorageService —
  // consumed only via the coach's run_sql_query tool. See
  // docs/superpowers/specs/2026-08-11-health-data-sync-and-coach-sql-design.md.

  Future<void> upsertHealthSamples(String type, List<HealthSample> samples) async {
    if (samples.isEmpty) return;
    final batch = _db.batch();
    for (final s in samples) {
      batch.insert(
        'health_samples',
        {
          'type': type,
          'timestamp': s.time.toIso8601String(),
          'value': s.value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertSleepSessions(List<SleepPeriod> periods) async {
    if (periods.isEmpty) return;
    await _db.transaction((txn) async {
      for (final p in periods) {
        final id = p.start.toIso8601String();
        await txn.delete(
          'sleep_stage_intervals',
          where: 'sleep_session_id = ?',
          whereArgs: [id],
        );
        await txn.insert(
          'sleep_sessions',
          {
            'id': id,
            'start_ts': p.start.toIso8601String(),
            'end_ts': p.end.toIso8601String(),
            'light_min': p.lightMinutes,
            'deep_min': p.deepMinutes,
            'rem_min': p.remMinutes,
            'awake_min': p.awakeMinutes,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final seg in p.stageTimeline) {
          await txn.insert('sleep_stage_intervals', {
            'sleep_session_id': id,
            'start_ts': seg.start.toIso8601String(),
            'end_ts': seg.end.toIso8601String(),
            'stage': seg.stage,
          });
        }
      }
    });
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/sqlite_storage_service_test.dart`
Expected: PASS (all tests, including the pre-existing ones in this file).

- [ ] **Step 5: Commit**

```bash
git add lib/services/sqlite_storage_service.dart test/sqlite_storage_service_test.dart
git commit -m "feat: add health_samples/sleep_sessions tables + upsert methods to SqliteStorageService"
```

---

### Task 2: `HealthDataSyncService`

**Files:**
- Create: `workout-logger/lib/services/health_data_sync_service.dart`
- Test: Create `workout-logger/test/health_data_sync_service_test.dart`

**Interfaces:**
- Consumes (from Task 1): `SqliteStorageService.upsertHealthSamples`, `SqliteStorageService.upsertSleepSessions`, `SqliteStorageService.getSetting`/`saveSetting`, `SqliteStorageService.databasePath`.
- Consumes (existing): `IHealthConnectService.readSleepSessions(DateTime, DateTime) -> Future<List<SleepPeriod>>`, `.readHeartRateSamples(DateTime, DateTime) -> Future<List<HealthSample>>`, `.readRestingHeartRate(DateTime, DateTime) -> Future<List<HealthSample>>`, `.readHrvRmssd(DateTime, DateTime) -> Future<List<HealthSample>>` (all in `lib/services/interfaces/health_connect_service_interface.dart`).
- Produces (used by Task 3 and Task 4): `HealthDataSyncService(IHealthConnectService hc, SqliteStorageService storage, {DateTime Function()? now})` with method `Future<void> sync({bool force = false})`.

- [ ] **Step 1: Write the failing tests**

Create `workout-logger/test/health_data_sync_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:repforge/models/models.dart';
import 'package:repforge/services/health_data_sync_service.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/sqlite_storage_service.dart';

class _RecordingHcService implements IHealthConnectService {
  final List<({String method, DateTime from, DateTime to})> calls = [];
  List<HealthSample> heartRateSamples = const [];
  List<HealthSample> restingHrSamples = const [];
  bool throwOnHeartRate = false;

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
  Future<Set<HealthReadType>> grantedReadTypes() async => HealthReadType.values.toSet();
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> hasPermissions() async => true;
  @override
  Future<bool> requestReadPermissions() async => true;
  @override
  Future<bool> syncWorkoutSession(WorkoutSession session, {String? title}) async => true;
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

  test('first sync backfills 90 days plus the 3-day lookback', () async {
    final now = DateTime(2026, 8, 11, 9);
    final service = HealthDataSyncService(hc, storage, now: () => now);

    await service.sync();

    final sleepCall = hc.calls.firstWhere((c) => c.method == 'sleep');
    expect(sleepCall.to, now);
    expect(sleepCall.from, now.subtract(const Duration(days: 93)));
  });

  test('second sync only re-fetches from watermark minus the 3-day lookback', () async {
    final firstRun = DateTime(2026, 8, 1, 9);
    final secondRun = DateTime(2026, 8, 11, 9);
    var current = firstRun;
    final service = HealthDataSyncService(hc, storage, now: () => current);

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
    final service = HealthDataSyncService(hc, storage, now: () => current);

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
    final service = HealthDataSyncService(hc, storage, now: () => current);

    await service.sync();
    hc.calls.clear();
    current = soonAfter;
    await service.sync(force: true);

    expect(hc.calls, isNotEmpty);
  });

  test('re-syncing the same sample does not duplicate rows', () async {
    final now = DateTime(2026, 8, 11, 9);
    hc.heartRateSamples = [HealthSample(time: DateTime(2026, 8, 10, 22), value: 62)];
    final service = HealthDataSyncService(hc, storage, now: () => now);

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
    final service = HealthDataSyncService(hc, storage, now: () => now);

    await service.sync(force: true);

    expect(await storage.getSetting('health_sync.heart_rate'), isNull);
    expect(await storage.getSetting('health_sync.resting_heart_rate'), now.toIso8601String());

    final rows = await _rawQuery(
      storage,
      "SELECT COUNT(*) AS c FROM health_samples WHERE type = 'resting_heart_rate'",
    );
    expect(rows.first['c'], 1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/health_data_sync_service_test.dart`
Expected: FAIL — `package:repforge/services/health_data_sync_service.dart` doesn't exist yet.

- [ ] **Step 3: Implement `HealthDataSyncService`**

Create `workout-logger/lib/services/health_data_sync_service.dart`:

```dart
// health_data_sync_service.dart — pulls sleep + heart-rate data from Health
// Connect into SqliteStorageService's health_samples/sleep_sessions tables
// so the coach's run_sql_query tool can join them against workout data.
// See docs/superpowers/specs/2026-08-11-health-data-sync-and-coach-sql-design.md.

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

  /// Pulls any new sleep/HR data since the last sync into SQLite. Skipped if
  /// the last sync ran under 30 minutes ago, unless [force] is true. Each of
  /// the 4 underlying data streams fails independently and best-effort —
  /// one stream throwing never blocks the others or this call.
  Future<void> sync({bool force = false}) async {
    final now = _now();
    if (!force) {
      final lastRunRaw = await _storage.getSetting(_lastRunKey);
      final lastRun = lastRunRaw == null ? null : DateTime.tryParse(lastRunRaw);
      if (lastRun != null && now.difference(lastRun) < _throttleWindow) return;
    }

    await _syncSleep(now);
    await _syncSamples('heart_rate', now, _hc.readHeartRateSamples);
    await _syncSamples('resting_heart_rate', now, _hc.readRestingHeartRate);
    await _syncSamples('hrv_rmssd', now, _hc.readHrvRmssd);

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
```

Note: `HealthSample` is used here only as a type annotation on the `reader` function parameter — it comes transitively from `interfaces/health_connect_service_interface.dart`, which imports `../../models/models.dart`. No separate models import is needed in this file.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/health_data_sync_service_test.dart`
Expected: PASS (all 6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/health_data_sync_service.dart test/health_data_sync_service_test.dart
git commit -m "feat: add HealthDataSyncService to pull sleep/HR data into SQLite"
```

---

### Task 3: Wire sync-on-launch into `main.dart`

**Files:**
- Modify: `workout-logger/lib/main.dart`

**Interfaces:**
- Consumes: `HealthDataSyncService(IHealthConnectService, SqliteStorageService, {DateTime Function()? now})` and `.sync({bool force})` from Task 2.

- [ ] **Step 1: Add the import**

In `workout-logger/lib/main.dart`, add near the other service imports (after `import 'services/health_connect_service.dart';`):

```dart
import 'services/health_data_sync_service.dart';
```

- [ ] **Step 2: Add the guarded static field**

In `WorkoutLoggerApp`, add after the existing `_healthHistoryManager` field (`main.dart:131-132`):

```dart
  // Populates the SQLite health tables the coach's run_sql_query tool joins
  // against workout data. Null under the pre-migration Hive fallback path —
  // there's no live SQLite database file to sync into. Mirrors the
  // sqlQuery ? ... : null guard used for CoachToolService below.
  static final HealthDataSyncService? _healthDataSyncService =
      _storageService is SqliteStorageService
          ? HealthDataSyncService(
              _healthConnectService,
              _storageService as SqliteStorageService,
            )
          : null;
```

- [ ] **Step 3: Provide it in the widget tree**

In the `MultiProvider` `providers` list, add right after `Provider<HealthHistoryManager>.value(value: _healthHistoryManager),` (`main.dart:164`):

```dart
        Provider<HealthDataSyncService?>.value(value: _healthDataSyncService),
```

- [ ] **Step 4: Trigger sync on app launch**

In `_AppInitializerState._initializeApp()`, add `healthDataSync` to the synchronous provider-capture block at the top (alongside `readiness`):

```dart
    final readiness = context.read<ReadinessManager>();
    final healthDataSync = context.read<HealthDataSyncService?>();
```

Then, right after the existing `readiness.refresh();` fire-and-forget call, add:

```dart
      // Fire-and-forget: populates the SQLite tables run_sql_query joins
      // against. No-op under the pre-migration Hive fallback (null there).
      healthDataSync?.sync();
```

- [ ] **Step 5: Verify with static analysis**

Run: `flutter analyze` (from `workout-logger/`)
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat: sync health data into SQLite once per app launch"
```

---

### Task 4: "Sync now" button on the Profile screen

**Files:**
- Modify: `workout-logger/lib/screens/widgets/profile_sections.dart`
- Modify: `workout-logger/lib/screens/profile_screen.dart`
- Modify: `workout-logger/test/test_utils/test_harness.dart`
- Test: Create `workout-logger/test/screens/widgets/profile_sections_health_sync_test.dart`

**Interfaces:**
- Consumes: `HealthDataSyncService.sync({bool force})` from Task 2, provided via `Provider<HealthDataSyncService?>` from Task 3.
- Produces: `HealthConnectSection` gains two new required constructor params: `bool isHealthSyncLoading` and `VoidCallback? onHealthSyncNow`.

- [ ] **Step 1: Write the failing widget tests**

Create `workout-logger/test/screens/widgets/profile_sections_health_sync_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repforge/screens/widgets/profile_sections.dart';
import 'package:repforge/services/settings_provider.dart';

import '../../test_utils/mock_storage_service.dart';

void main() {
  testWidgets('Sync now tile appears when readiness is enabled and invokes callback on tap',
      (tester) async {
    final settings = SettingsProvider(MockStorageService());
    await settings.init();
    await settings.setReadinessEnabled(true);

    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HealthConnectSection(
          settings: settings,
          isLoading: false,
          onToggle: (_) async {},
          isReadinessLoading: false,
          onReadinessToggle: (_) async {},
          isHealthSyncLoading: false,
          onHealthSyncNow: () => tapped = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sync coach data now'), findsOneWidget);
    await tester.tap(find.text('Sync coach data now'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('Sync now tile is hidden when readiness is disabled', (tester) async {
    final settings = SettingsProvider(MockStorageService());
    await settings.init();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HealthConnectSection(
          settings: settings,
          isLoading: false,
          onToggle: (_) async {},
          isReadinessLoading: false,
          onReadinessToggle: (_) async {},
          isHealthSyncLoading: false,
          onHealthSyncNow: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sync coach data now'), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/widgets/profile_sections_health_sync_test.dart`
Expected: FAIL — `HealthConnectSection` has no `isHealthSyncLoading`/`onHealthSyncNow` parameters yet, and no "Sync coach data now" text exists.

- [ ] **Step 3: Add the tile to `HealthConnectSection`**

In `workout-logger/lib/screens/widgets/profile_sections.dart`, update the `HealthConnectSection` constructor (around line 234-248):

```dart
class HealthConnectSection extends StatelessWidget {
  const HealthConnectSection({
    super.key,
    required this.settings,
    required this.isLoading,
    required this.onToggle,
    required this.isReadinessLoading,
    required this.onReadinessToggle,
    required this.isHealthSyncLoading,
    required this.onHealthSyncNow,
  });

  final SettingsProvider settings;
  final bool isLoading;
  final Future<void> Function(bool) onToggle;
  final bool isReadinessLoading;
  final Future<void> Function(bool) onReadinessToggle;
  final bool isHealthSyncLoading;
  final VoidCallback? onHealthSyncNow;
```

Then, inside `build()`, right after the closing `],\n          ),` of the readiness `Row` (the block ending around line 346, immediately before the final `],\n      ),\n    );\n  }\n}` that closes the outer `Column`/`_ProfileSection`), add:

```dart
          if (settings.readinessEnabled) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.sync_rounded,
              iconColor: _hcColor,
              title: 'Sync coach data now',
              subtitle: "Pull recent sleep & heart rate into the coach's database",
              loading: isHealthSyncLoading,
              onTap: onHealthSyncNow,
            ),
          ],
```

(`_ActionTile` is already defined later in this same file and used by `DataManagementSection`.)

- [ ] **Step 4: Wire it up in `ProfileScreen`**

In `workout-logger/lib/screens/profile_screen.dart`, add an import and state field near the existing ones:

```dart
import '../services/health_data_sync_service.dart';
```

```dart
  bool _isSyncingHealthData = false;
```

Add a handler method near `_requestReadinessPermission`:

```dart
  Future<void> _syncHealthDataNow() async {
    setState(() => _isSyncingHealthData = true);
    try {
      final sync = context.read<HealthDataSyncService?>();
      if (sync == null) {
        _showSnack('Health data sync is not available.', AppColors.error);
        return;
      }
      await sync.sync(force: true);
      if (mounted) _showSnack('Coach data synced!', AppColors.success);
    } catch (e) {
      if (mounted) _showSnack('Sync failed. Try again later.', AppColors.error);
    } finally {
      if (mounted) setState(() => _isSyncingHealthData = false);
    }
  }
```

Update the `HealthConnectSection(...)` call in `build()` (around `profile_screen.dart:359-377`) to pass the two new params:

```dart
                HealthConnectSection(
                  settings: settings,
                  isLoading: _isRequestingHcPermission,
                  onToggle: (value) async {
                    if (value) {
                      await _requestHealthConnectPermission();
                    } else {
                      await settings.setHealthConnectEnabled(false);
                    }
                  },
                  isReadinessLoading: _isRequestingReadinessPermission,
                  onReadinessToggle: (value) async {
                    if (value) {
                      await _requestReadinessPermission();
                    } else {
                      await settings.setReadinessEnabled(false);
                    }
                  },
                  isHealthSyncLoading: _isSyncingHealthData,
                  onHealthSyncNow: _isSyncingHealthData ? null : _syncHealthDataNow,
                ),
```

- [ ] **Step 5: Keep existing widget tests passing**

`ProfileScreen` reads `HealthDataSyncService?` via `context.read`, and `TestHarness.wrap` (used by `test/screens/profile_screen_test.dart` and others) doesn't register that provider. Provider's nullable-type lookup returns `null` when no matching provider is registered, so this works without changes — but add it explicitly for clarity. In `workout-logger/test/test_utils/test_harness.dart`, add the import:

```dart
import 'package:repforge/services/health_data_sync_service.dart';
```

and add to the `providers` list (after `Provider<IHealthConnectService>.value(value: const StubHcService()),`):

```dart
        Provider<HealthDataSyncService?>.value(value: null),
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/screens/widgets/profile_sections_health_sync_test.dart test/screens/profile_screen_test.dart test/screens/profile_screen_full_test.dart test/userflow_health_and_profile_screen_test.dart`
Expected: PASS for all four files.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/widgets/profile_sections.dart lib/screens/profile_screen.dart test/test_utils/test_harness.dart test/screens/widgets/profile_sections_health_sync_test.dart
git commit -m "feat: add manual 'Sync coach data now' action to Profile screen"
```

---

### Task 5: Extend `run_sql_query`'s schema for the coach

**Files:**
- Modify: `workout-logger/lib/services/ai/coach_tool_service.dart`
- Test: Create `workout-logger/test/coach_tool_service_schema_test.dart`
- Test: Modify `workout-logger/test/sql_query_service_test.dart`

**Interfaces:**
- Consumes: the `health_samples`, `sleep_sessions`, `sleep_stage_intervals` tables from Task 1. Consumes `CoachToolService.buildTools() -> List<Tool>` (existing, public) and `FunctionDeclaration.name`/`.description` (public fields from the `google_generative_ai` package) to assert on the schema text.

- [ ] **Step 1: Write the failing tests**

Create `workout-logger/test/coach_tool_service_schema_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/ai/sql_query_service.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';

import 'test_utils/mock_ml_service.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  test('run_sql_query schema description includes the new health tables', () {
    final storage = MockStorageService();
    final wp = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    final prm = PRManager(storage);
    final tools = CoachToolService(wp, prm, sqlQuery: SqlQueryService('unused.db'));

    final decl = tools
        .buildTools()
        .single
        .functionDeclarations!
        .firstWhere((d) => d.name == 'run_sql_query');

    expect(decl.description, contains('health_samples'));
    expect(decl.description, contains('sleep_sessions'));
    expect(decl.description, contains('sleep_stage_intervals'));
  });
}
```

This test fails before Step 3's edit (the current description has none of those table names) and passes after — it's the actual TDD-relevant assertion for this task, since the schema text is what the model reads and nothing else in the codebase asserts on it.

Also add this regression test to `workout-logger/test/sql_query_service_test.dart`, inside `main()` (e.g. after the `'does not close the app\'s shared connection...'` test added previously), to confirm the join shape the coach will actually run works end-to-end once the tables exist:

```dart
  test('can join workouts against sleep and HR data', () async {
    await seedDb.execute('''CREATE TABLE health_samples (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      value REAL NOT NULL
    )''');
    await seedDb.execute('''CREATE TABLE sleep_sessions (
      id TEXT PRIMARY KEY,
      start_ts TEXT NOT NULL,
      end_ts TEXT NOT NULL,
      light_min INTEGER,
      deep_min INTEGER,
      rem_min INTEGER,
      awake_min INTEGER
    )''');
    await seedDb.insert('health_samples', {
      'type': 'resting_heart_rate',
      'timestamp': '2026-08-10T07:00:00.000',
      'value': 58.0,
    });
    await seedDb.insert('sleep_sessions', {
      'id': '2026-08-09T23:00:00.000',
      'start_ts': '2026-08-09T23:00:00.000',
      'end_ts': '2026-08-10T07:00:00.000',
      'light_min': 200,
      'deep_min': 70,
      'rem_min': 90,
      'awake_min': 5,
    });

    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('''
      SELECT w.name AS widget_name, s.deep_min AS deep_min, h.value AS resting_hr
      FROM widgets w, sleep_sessions s
      JOIN health_samples h ON h.type = 'resting_heart_rate'
      WHERE w.id = 1
    ''');

    expect(result['error'], isNull);
    expect(result['row_count'], 1);
    expect((result['rows'] as List).first, {
      'widget_name': 'foo',
      'deep_min': 70,
      'resting_hr': 58.0,
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail/pass as expected**

Run: `flutter test test/coach_tool_service_schema_test.dart`
Expected: FAIL — the current `run_sql_query` description doesn't mention `health_samples`, `sleep_sessions`, or `sleep_stage_intervals`.

Run: `flutter test test/sql_query_service_test.dart --plain-name "can join workouts against sleep and HR data"`
Expected: PASS already — this test only exercises the query engine against tables it creates itself, not the schema description, so it isn't failing-first. It's included as regression coverage for the join shape the coach will actually run once Step 3 tells it these tables exist.

- [ ] **Step 3: Extend the coach's schema description**

In `workout-logger/lib/services/ai/coach_tool_service.dart`, in `_runSqlQueryDeclaration` (around line 391-393), insert the three new table lines right after the `personal_records(...)` line and before the `'When joining tables, ...'` line:

```dart
            'personal_records(exercise_id, best_weight, best_reps, best_volume, achieved_at)\n'
            'health_samples(id, type, timestamp, value) — type is heart_rate | '
            'resting_heart_rate | hrv_rmssd; one row per Health Connect sample\n'
            'sleep_sessions(id, start_ts, end_ts, light_min, deep_min, rem_min, '
            'awake_min) — one row per night, id is the session start_ts\n'
            'sleep_stage_intervals(sleep_session_id, start_ts, end_ts, stage) — '
            'stage is deep | rem | light | awake\n'
            'When joining tables, select explicit columns with aliases (e.g. s.id AS '
            'session_id, l.id AS log_id) instead of SELECT *, since duplicate column '
            'names across joined tables will silently collide.\n'
            'Only SELECT/WITH statements are allowed, one statement per call.',
```

(Delete the old `'When joining tables, ...'` and `'Only SELECT/WITH...'` lines from their original position — they're being replaced by the block above, unchanged in content but moved after the three new lines.)

- [ ] **Step 4: Run tests to verify everything passes**

Run: `flutter test test/sql_query_service_test.dart test/coach_tool_service_schema_test.dart`
Expected: PASS for both files.

- [ ] **Step 5: Commit**

```bash
git add lib/services/ai/coach_tool_service.dart test/sql_query_service_test.dart test/coach_tool_service_schema_test.dart
git commit -m "feat: teach run_sql_query about the new health_samples/sleep_sessions tables"
```

---

### Final Verification

- [ ] Run the full test suite: `flutter test` (from `workout-logger/`). Expected: all tests PASS, no regressions.
- [ ] Run `flutter analyze`. Expected: `No issues found!`
