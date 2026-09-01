# Hive → SQLite Migration + Coach SQL Query Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Hive with SQLite (`sqflite`) as RepForge's persistence backend via a safe, one-time, reversible migration, then add a `run_sql_query` tool to the AI Coach that queries the live database directly.

**Architecture:** A new `SqliteStorageService implements IStorageService` sits alongside the existing Hive-backed `StorageService`. A `StorageMigrationService` copies data from one to the other exactly once, gated by a flag stored in the Hive settings box, with no deletion of Hive data and automatic fallback to Hive on any migration failure. `main.dart`'s composition root resolves which backend to hand to the rest of the app before `runApp()`. The Coach's new `run_sql_query` tool opens a dedicated **read-only** connection to the same SQLite file and runs model-submitted `SELECT` statements against live data.

**Tech Stack:** Flutter/Dart, `sqflite` (runtime), `sqflite_common_ffi` (dev/test only), existing `hive`/`hive_flutter` (kept, not removed), `google_generative_ai` (existing Coach tool-calling), `flutter_test`.

## Global Constraints

- No changes to any `IStorageService` method signature (spec §2 non-goal). Additions to concrete classes are fine.
- No changes to any manager, `WorkoutProvider`, or screen — all depend on `IStorageService`/`MockStorageService`, never a concrete backend.
- Hive boxes are never deleted at any point in this plan (spec §6.6).
- All new SQLite code lives under `lib/services/` (storage) and `lib/services/ai/` (SQL tool), matching existing structure.
- Follow the schema exactly as specified in `docs/superpowers/specs/2026-08-08-sqlite-migration-and-coach-sql-tool-design.md` §4.

---

### Task 1: Add SQLite dependencies

**Files:**
- Modify: `workout-logger/pubspec.yaml`

**Interfaces:**
- Produces: `sqflite` and `sqflite_common_ffi` packages available for import in later tasks.

- [ ] **Step 1: Add dependencies**

In `workout-logger/pubspec.yaml`, add to the `dependencies:` section (after the `hive_flutter` line):

```yaml
  # SQLite persistence (replacing Hive)
  sqflite: ^2.4.2
```

Add to the `dev_dependencies:` section (after `build_runner`):

```yaml
  # sqflite testing on the Dart VM (flutter test has no platform binding)
  sqflite_common_ffi: ^2.3.4+4
```

- [ ] **Step 2: Install**

Run: `cd workout-logger && flutter pub get`
Expected: resolves successfully, `pubspec.lock` updated with `sqflite` and `sqflite_common_ffi`.

- [ ] **Step 3: Commit**

```bash
git add workout-logger/pubspec.yaml workout-logger/pubspec.lock
git commit -m "chore: add sqflite dependencies for SQLite storage migration"
```

---

### Task 2: `SqliteStorageService` — schema + workout sessions

**Files:**
- Create: `workout-logger/lib/services/sqlite_storage_service.dart`
- Test: `workout-logger/test/sqlite_storage_service_test.dart`

**Interfaces:**
- Consumes: `IStorageService` (`lib/services/interfaces/storage_service_interface.dart`), models from `lib/models/models.dart`, `ExerciseDatabase`/`MuscleGroups` from `lib/data/exercise_database.dart`.
- Produces: `class SqliteStorageService implements IStorageService` with:
  - `Future<void> init()`
  - `String get databasePath` (exposes the open DB's file path for `SqlQueryService`, Task 10)
  - `SqliteStorageService({String? databasePathOverride})` constructor (override used by tests for `inMemoryDatabasePath`)
  - Full workout-session CRUD this task implements: `saveWorkoutSession`, `getAllWorkoutSessions`, `getWorkoutSession`, `deleteWorkoutSession`, `getSessionsForExercise`, `getSessionsInDateRange`
  - Remaining `IStorageService` methods stubbed with `throw UnimplementedError()` (filled in by Tasks 3–6)

- [ ] **Step 1: Write the failing test**

Create `workout-logger/test/sqlite_storage_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/sqlite_storage_service.dart';

void main() {
  late SqliteStorageService storage;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    storage = SqliteStorageService(databasePathOverride: inMemoryDatabasePath);
    await storage.init();
  });

  group('SqliteStorageService — init', () {
    test('seeds default muscle groups', () async {
      final groups = await storage.getAllMuscleGroups();
      expect(groups, isNotEmpty);
      expect(groups.any((g) => g.name == 'Chest'), isTrue);
    });
  });

  group('SqliteStorageService — workout sessions', () {
    test('saveWorkoutSession + getWorkoutSession round-trips nested sets', () async {
      final session = WorkoutSession(
        id: 's1',
        date: DateTime(2026, 7, 10),
        duration: 45,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [
              WorkoutSet(weight: 60, reps: 8),
              WorkoutSet(weight: 65, reps: 6, isDropset: true, drops: [
                DropsetEntry(weight: 50, reps: 10),
              ]),
            ],
          ),
        ],
      );

      await storage.saveWorkoutSession(session);
      final fetched = await storage.getWorkoutSession('s1');

      expect(fetched, isNotNull);
      expect(fetched!.duration, 45);
      expect(fetched.exercises.single.sets.length, 2);
      expect(fetched.exercises.single.sets.first.weight, 60);
      expect(fetched.exercises.single.sets[1].isDropset, isTrue);
      expect(fetched.exercises.single.sets[1].drops!.single.weight, 50);
    });

    test('saveWorkoutSession overwrites previous sets on re-save', () async {
      final session = WorkoutSession(
        id: 's2',
        date: DateTime(2026, 7, 1),
        duration: 30,
        exercises: [
          ExerciseLog(exerciseId: 'squat', sets: [WorkoutSet(weight: 100, reps: 5)]),
        ],
      );
      await storage.saveWorkoutSession(session);

      final updated = session.copyWith(
        exercises: [
          ExerciseLog(exerciseId: 'squat', sets: [WorkoutSet(weight: 110, reps: 3)]),
        ],
      );
      await storage.saveWorkoutSession(updated);

      final fetched = await storage.getWorkoutSession('s2');
      expect(fetched!.exercises.single.sets.length, 1);
      expect(fetched.exercises.single.sets.first.weight, 110);
    });

    test('deleteWorkoutSession removes the session', () async {
      final session = WorkoutSession(
        id: 's3',
        date: DateTime.now(),
        duration: 20,
        exercises: [ExerciseLog(exerciseId: 'row', sets: [WorkoutSet(weight: 40, reps: 10)])],
      );
      await storage.saveWorkoutSession(session);
      await storage.deleteWorkoutSession('s3');
      expect(await storage.getWorkoutSession('s3'), isNull);
    });

    test('getAllWorkoutSessions returns most-recent first', () async {
      await storage.saveWorkoutSession(
        WorkoutSession(id: 'old', date: DateTime(2026, 1, 1), duration: 10, exercises: []),
      );
      await storage.saveWorkoutSession(
        WorkoutSession(id: 'new', date: DateTime(2026, 6, 1), duration: 10, exercises: []),
      );
      final all = await storage.getAllWorkoutSessions();
      expect(all.first.id, 'new');
    });

    test('getSessionsInDateRange filters by date', () async {
      await storage.saveWorkoutSession(
        WorkoutSession(id: 'a', date: DateTime(2026, 1, 1), duration: 10, exercises: []),
      );
      await storage.saveWorkoutSession(
        WorkoutSession(id: 'b', date: DateTime(2026, 6, 1), duration: 10, exercises: []),
      );
      final result = await storage.getSessionsInDateRange(DateTime(2026, 5, 1), DateTime(2026, 7, 1));
      expect(result.map((s) => s.id), ['b']);
    });

    test('getSessionsForExercise filters by exercise id', () async {
      await storage.saveWorkoutSession(WorkoutSession(
        id: 'c1', date: DateTime.now(), duration: 10,
        exercises: [ExerciseLog(exerciseId: 'deadlift', sets: [WorkoutSet(weight: 120, reps: 5)])],
      ));
      await storage.saveWorkoutSession(WorkoutSession(
        id: 'c2', date: DateTime.now(), duration: 10,
        exercises: [ExerciseLog(exerciseId: 'squat', sets: [WorkoutSet(weight: 100, reps: 5)])],
      ));
      final result = await storage.getSessionsForExercise('deadlift');
      expect(result.map((s) => s.id), ['c1']);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: FAIL — `lib/services/sqlite_storage_service.dart` does not exist.

- [ ] **Step 3: Implement schema + sessions CRUD**

Create `workout-logger/lib/services/sqlite_storage_service.dart`:

```dart
// SQLite-backed implementation of IStorageService — replaces Hive as the
// persistence backend. See docs/superpowers/specs/2026-08-08-sqlite-migration-and-coach-sql-tool-design.md
// for the schema and migration design this implements.

import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../data/exercise_database.dart';
import 'interfaces/storage_service_interface.dart';

class SqliteStorageService implements IStorageService {
  SqliteStorageService({String? databasePathOverride})
      : _databasePathOverride = databasePathOverride;

  static const String _dbName = 'repforge.db';
  static const int _dbVersion = 1;

  static const List<String> _schemaStatements = [
    '''CREATE TABLE exercises (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      is_custom INTEGER NOT NULL DEFAULT 0,
      available_handles TEXT
    )''',
    '''CREATE TABLE muscle_groups (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      growth_rate REAL NOT NULL DEFAULT 0,
      last_updated TEXT NOT NULL
    )''',
    '''CREATE TABLE exercise_muscle_activations (
      exercise_id TEXT NOT NULL,
      muscle_group_id TEXT NOT NULL,
      activation_percentage INTEGER NOT NULL
    )''',
    '''CREATE TABLE routines (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''',
    '''CREATE TABLE routine_exercises (
      routine_id TEXT NOT NULL,
      exercise_id TEXT NOT NULL,
      position INTEGER NOT NULL
    )''',
    '''CREATE TABLE sessions (
      id TEXT PRIMARY KEY,
      date TEXT NOT NULL,
      routine_id TEXT,
      duration_min INTEGER NOT NULL,
      notes TEXT,
      hc_synced_at TEXT
    )''',
    '''CREATE TABLE exercise_logs (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      exercise_id TEXT NOT NULL,
      notes TEXT,
      handle TEXT
    )''',
    '''CREATE TABLE sets (
      id TEXT PRIMARY KEY,
      exercise_log_id TEXT NOT NULL,
      weight REAL NOT NULL,
      reps INTEGER NOT NULL,
      is_dropset INTEGER NOT NULL DEFAULT 0,
      drops_json TEXT,
      time_taken INTEGER,
      timestamp TEXT NOT NULL,
      assist_weight REAL,
      extra_weight REAL,
      handle TEXT
    )''',
    '''CREATE TABLE targets (
      id TEXT PRIMARY KEY,
      exercise_id TEXT NOT NULL,
      target_type TEXT NOT NULL,
      target_value REAL NOT NULL,
      current_value REAL NOT NULL DEFAULT 0,
      estimated_completion_date TEXT,
      created_at TEXT NOT NULL,
      is_completed INTEGER NOT NULL DEFAULT 0
    )''',
    '''CREATE TABLE personal_records (
      exercise_id TEXT PRIMARY KEY,
      best_weight REAL NOT NULL,
      best_reps INTEGER NOT NULL,
      best_volume REAL NOT NULL,
      achieved_at TEXT NOT NULL
    )''',
    '''CREATE TABLE training_programs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      total_weeks INTEGER NOT NULL,
      author TEXT,
      is_imported INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      phases_json TEXT NOT NULL,
      weeks_json TEXT NOT NULL
    )''',
    '''CREATE TABLE conversations (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      kind TEXT NOT NULL DEFAULT 'coach',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      messages_json TEXT NOT NULL
    )''',
    '''CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT
    )''',
    'CREATE INDEX idx_sets_exercise_log ON sets(exercise_log_id)',
    'CREATE INDEX idx_exercise_logs_session ON exercise_logs(session_id)',
    'CREATE INDEX idx_exercise_logs_exercise ON exercise_logs(exercise_id)',
    'CREATE INDEX idx_sessions_date ON sessions(date)',
  ];

  final String? _databasePathOverride;
  late Database _db;
  bool _initialized = false;

  String _appVersion = const String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'unknown',
  );

  /// File path of the open database — used by SqlQueryService to open a
  /// separate read-only connection for the coach's SQL tool.
  String get databasePath => _db.path;

  @override
  Future<void> init() async {
    if (_initialized) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      _appVersion = buildNumber.isNotEmpty ? '$version+$buildNumber' : version;
    } catch (_) {
      // Keep build-time fallback in environments without platform metadata.
    }

    final dbPath = _databasePathOverride ?? '${await getDatabasesPath()}/$_dbName';
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        for (final statement in _schemaStatements) {
          await db.execute(statement);
        }
      },
    );

    final count = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM muscle_groups'),
        ) ??
        0;
    if (count == 0) {
      await _seedDefaultMuscleGroups();
    }

    _initialized = true;
  }

  Future<void> _seedDefaultMuscleGroups() async {
    final batch = _db.batch();
    for (final mg in MuscleGroups.getAll()) {
      batch.insert('muscle_groups', {
        'id': mg.id,
        'name': mg.name,
        'growth_rate': mg.growthRate,
        'last_updated': mg.lastUpdated.toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  // ==================== WORKOUT SESSIONS ====================

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {
    await _db.transaction((txn) async {
      final oldLogs = await txn.query(
        'exercise_logs',
        columns: ['id'],
        where: 'session_id = ?',
        whereArgs: [session.id],
      );
      for (final row in oldLogs) {
        await txn.delete('sets', where: 'exercise_log_id = ?', whereArgs: [row['id']]);
      }
      await txn.delete('exercise_logs', where: 'session_id = ?', whereArgs: [session.id]);
      await txn.delete('sessions', where: 'id = ?', whereArgs: [session.id]);

      await txn.insert('sessions', {
        'id': session.id,
        'date': session.date.toIso8601String(),
        'routine_id': session.routineId,
        'duration_min': session.duration,
        'notes': session.notes,
        'hc_synced_at': session.hcSyncedAt?.toIso8601String(),
      });

      for (var i = 0; i < session.exercises.length; i++) {
        final log = session.exercises[i];
        final logId = '${session.id}_$i';
        await txn.insert('exercise_logs', {
          'id': logId,
          'session_id': session.id,
          'exercise_id': log.exerciseId,
          'notes': log.notes,
          'handle': log.handle,
        });
        for (var j = 0; j < log.sets.length; j++) {
          final set = log.sets[j];
          await txn.insert('sets', {
            'id': '${logId}_$j',
            'exercise_log_id': logId,
            'weight': set.weight,
            'reps': set.reps,
            'is_dropset': set.isDropset ? 1 : 0,
            'drops_json': set.drops == null
                ? null
                : jsonEncode(set.drops!.map((d) => d.toJson()).toList()),
            'time_taken': set.timeTaken,
            'timestamp': set.timestamp.toIso8601String(),
            'assist_weight': set.assistWeight,
            'extra_weight': set.extraWeight,
            'handle': set.handle,
          });
        }
      }
    });
  }

  Future<List<WorkoutSession>> _loadSessions({String? where, List<Object?>? whereArgs}) async {
    final sessionRows = await _db.query('sessions', where: where, whereArgs: whereArgs);
    final sessions = <WorkoutSession>[];
    for (final row in sessionRows) {
      final sessionId = row['id'] as String;
      final logRows = await _db.query(
        'exercise_logs',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'id ASC',
      );
      final exerciseLogs = <ExerciseLog>[];
      for (final logRow in logRows) {
        final logId = logRow['id'] as String;
        final setRows = await _db.query(
          'sets',
          where: 'exercise_log_id = ?',
          whereArgs: [logId],
          orderBy: 'id ASC',
        );
        final sets = setRows
            .map((s) => WorkoutSet(
                  weight: (s['weight'] as num).toDouble(),
                  reps: s['reps'] as int,
                  isDropset: (s['is_dropset'] as int) == 1,
                  drops: s['drops_json'] == null
                      ? null
                      : (jsonDecode(s['drops_json'] as String) as List)
                          .map((d) => DropsetEntry.fromJson(d as Map<String, dynamic>))
                          .toList(),
                  timeTaken: s['time_taken'] as int?,
                  timestamp: DateTime.parse(s['timestamp'] as String),
                  assistWeight: (s['assist_weight'] as num?)?.toDouble(),
                  extraWeight: (s['extra_weight'] as num?)?.toDouble(),
                  handle: s['handle'] as String?,
                ))
            .toList();
        exerciseLogs.add(ExerciseLog(
          exerciseId: logRow['exercise_id'] as String,
          sets: sets,
          notes: logRow['notes'] as String?,
          handle: logRow['handle'] as String?,
        ));
      }
      sessions.add(WorkoutSession(
        id: sessionId,
        date: DateTime.parse(row['date'] as String),
        routineId: row['routine_id'] as String?,
        exercises: exerciseLogs,
        duration: row['duration_min'] as int,
        notes: row['notes'] as String?,
        hcSyncedAt: row['hc_synced_at'] == null
            ? null
            : DateTime.parse(row['hc_synced_at'] as String),
      ));
    }
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions;
  }

  @override
  Future<List<WorkoutSession>> getAllWorkoutSessions() => _loadSessions();

  @override
  Future<WorkoutSession?> getWorkoutSession(String id) async {
    final result = await _loadSessions(where: 'id = ?', whereArgs: [id]);
    return result.isEmpty ? null : result.first;
  }

  @override
  Future<void> deleteWorkoutSession(String id) async {
    await _db.transaction((txn) async {
      final logRows = await txn.query(
        'exercise_logs',
        columns: ['id'],
        where: 'session_id = ?',
        whereArgs: [id],
      );
      for (final row in logRows) {
        await txn.delete('sets', where: 'exercise_log_id = ?', whereArgs: [row['id']]);
      }
      await txn.delete('exercise_logs', where: 'session_id = ?', whereArgs: [id]);
      await txn.delete('sessions', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<List<WorkoutSession>> getSessionsForExercise(String exerciseId) async {
    final all = await getAllWorkoutSessions();
    return all.where((s) => s.exercises.any((e) => e.exerciseId == exerciseId)).toList();
  }

  @override
  Future<List<WorkoutSession>> getSessionsInDateRange(DateTime start, DateTime end) async {
    final all = await getAllWorkoutSessions();
    final lo = start.isAfter(end) ? end : start;
    final hi = start.isAfter(end) ? start : end;
    return all.where((s) => !s.date.isBefore(lo) && !s.date.isAfter(hi)).toList();
  }

  // ==================== ROUTINES (Task 3) ====================

  @override
  Future<void> saveRoutine(Routine routine) => throw UnimplementedError();
  @override
  Future<List<Routine>> getAllRoutines() => throw UnimplementedError();
  @override
  Future<Routine?> getRoutine(String id) => throw UnimplementedError();
  @override
  Future<void> deleteRoutine(String id) => throw UnimplementedError();

  // ==================== TARGETS (Task 3) ====================

  @override
  Future<void> saveTarget(Target target) => throw UnimplementedError();
  @override
  Future<List<Target>> getAllTargets() => throw UnimplementedError();
  @override
  Future<Target?> getTarget(String id) => throw UnimplementedError();
  @override
  Future<void> deleteTarget(String id) => throw UnimplementedError();
  @override
  Future<List<Target>> getTargetsForExercise(String exerciseId) => throw UnimplementedError();

  // ==================== MUSCLE GROUPS / EXERCISES (Task 4) ====================

  @override
  Future<void> updateMuscleGroupGrowthRate(String muscleGroupId, double rate) =>
      throw UnimplementedError();
  @override
  Future<List<MuscleGroup>> getAllMuscleGroups() => throw UnimplementedError();
  @override
  Future<MuscleGroup?> getMuscleGroup(String id) => throw UnimplementedError();
  @override
  Future<void> saveCustomExercise(Exercise exercise) => throw UnimplementedError();
  @override
  Future<List<Exercise>> getCustomExercises() => throw UnimplementedError();
  @override
  Future<void> deleteCustomExercise(String id) => throw UnimplementedError();
  @override
  Future<List<Exercise>> getAllExercises() => throw UnimplementedError();
  @override
  Future<Exercise?> getExercise(String id) => throw UnimplementedError();

  // ==================== SETTINGS / PROGRAMS / PRs / CONVERSATIONS (Task 5) ====================

  @override
  Future<void> saveSetting(String key, String value) => throw UnimplementedError();
  @override
  Future<String?> getSetting(String key) => throw UnimplementedError();
  @override
  Future<void> saveTrainingProgram(TrainingProgram program) => throw UnimplementedError();
  @override
  Future<List<TrainingProgram>> getAllTrainingPrograms() => throw UnimplementedError();
  @override
  Future<TrainingProgram?> getTrainingProgram(String id) => throw UnimplementedError();
  @override
  Future<void> deleteTrainingProgram(String id) => throw UnimplementedError();
  @override
  Future<void> savePersonalRecord(PersonalRecord record) => throw UnimplementedError();
  @override
  Future<PersonalRecord?> getPersonalRecord(String exerciseId) => throw UnimplementedError();
  @override
  Future<List<PersonalRecord>> getAllPersonalRecords() => throw UnimplementedError();
  @override
  Future<void> saveConversation(Conversation conversation) => throw UnimplementedError();
  @override
  Future<List<Conversation>> getAllConversations() => throw UnimplementedError();
  @override
  Future<Conversation?> getConversation(String id) => throw UnimplementedError();
  @override
  Future<void> deleteConversation(String id) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getQuickStats() => throw UnimplementedError();

  // ==================== EXPORT / IMPORT (Task 6) ====================

  @override
  Future<String> exportAllData() => throw UnimplementedError();
  @override
  Future<void> importData(String jsonData) => throw UnimplementedError();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: PASS (all 7 tests).

- [ ] **Step 5: Commit**

```bash
git add workout-logger/lib/services/sqlite_storage_service.dart workout-logger/test/sqlite_storage_service_test.dart
git commit -m "feat: add SqliteStorageService with schema and workout session CRUD"
```

---

### Task 3: `SqliteStorageService` — routines + targets

**Files:**
- Modify: `workout-logger/lib/services/sqlite_storage_service.dart`
- Modify: `workout-logger/test/sqlite_storage_service_test.dart`

**Interfaces:**
- Consumes: schema from Task 2 (`routines`, `routine_exercises`, `targets` tables).
- Produces: working `saveRoutine`, `getAllRoutines`, `getRoutine`, `deleteRoutine`, `saveTarget`, `getAllTargets`, `getTarget`, `deleteTarget`, `getTargetsForExercise`.

- [ ] **Step 1: Write the failing tests**

Append to `workout-logger/test/sqlite_storage_service_test.dart` (inside `main()`, alongside the existing groups):

```dart
  group('SqliteStorageService — routines', () {
    test('saveRoutine + getRoutine round-trips ordered exercise ids', () async {
      await storage.saveRoutine(Routine(
        id: 'r1',
        name: 'Push Day',
        exerciseIds: ['bench_press', 'shoulder_press', 'triceps_pushdown'],
      ));
      final fetched = await storage.getRoutine('r1');
      expect(fetched!.name, 'Push Day');
      expect(fetched.exerciseIds, ['bench_press', 'shoulder_press', 'triceps_pushdown']);
    });

    test('saveRoutine overwrites exercise order on re-save', () async {
      await storage.saveRoutine(Routine(id: 'r2', name: 'Pull Day', exerciseIds: ['a', 'b']));
      await storage.saveRoutine(Routine(id: 'r2', name: 'Pull Day', exerciseIds: ['b', 'a', 'c']));
      final fetched = await storage.getRoutine('r2');
      expect(fetched!.exerciseIds, ['b', 'a', 'c']);
    });

    test('deleteRoutine removes it', () async {
      await storage.saveRoutine(Routine(id: 'r3', name: 'Legs', exerciseIds: ['squat']));
      await storage.deleteRoutine('r3');
      expect(await storage.getRoutine('r3'), isNull);
    });

    test('getAllRoutines returns all saved routines', () async {
      await storage.saveRoutine(Routine(id: 'r4', name: 'A', exerciseIds: []));
      await storage.saveRoutine(Routine(id: 'r5', name: 'B', exerciseIds: []));
      final all = await storage.getAllRoutines();
      expect(all.map((r) => r.id), containsAll(['r4', 'r5']));
    });
  });

  group('SqliteStorageService — targets', () {
    test('saveTarget + getTarget round-trips', () async {
      await storage.saveTarget(Target(
        id: 't1',
        exerciseId: 'bench_press',
        targetType: 'weight',
        targetValue: 100,
        currentValue: 70,
      ));
      final fetched = await storage.getTarget('t1');
      expect(fetched!.targetValue, 100);
      expect(fetched.currentValue, 70);
    });

    test('deleteTarget removes it', () async {
      await storage.saveTarget(Target(id: 't2', exerciseId: 'squat', targetType: 'weight', targetValue: 150));
      await storage.deleteTarget('t2');
      expect(await storage.getTarget('t2'), isNull);
    });

    test('getTargetsForExercise filters by exercise id', () async {
      await storage.saveTarget(Target(id: 't3', exerciseId: 'squat', targetType: 'weight', targetValue: 150));
      await storage.saveTarget(Target(id: 't4', exerciseId: 'deadlift', targetType: 'weight', targetValue: 180));
      final result = await storage.getTargetsForExercise('squat');
      expect(result.map((t) => t.id), ['t3']);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: FAIL with `UnimplementedError` on the routine/target tests.

- [ ] **Step 3: Implement routines + targets**

In `workout-logger/lib/services/sqlite_storage_service.dart`, replace the `// ==================== ROUTINES (Task 3) ====================` and `// ==================== TARGETS (Task 3) ====================` sections with:

```dart
  // ==================== ROUTINES ====================

  @override
  Future<void> saveRoutine(Routine routine) async {
    await _db.transaction((txn) async {
      await txn.delete('routine_exercises', where: 'routine_id = ?', whereArgs: [routine.id]);
      await txn.insert(
        'routines',
        {
          'id': routine.id,
          'name': routine.name,
          'created_at': routine.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var i = 0; i < routine.exerciseIds.length; i++) {
        await txn.insert('routine_exercises', {
          'routine_id': routine.id,
          'exercise_id': routine.exerciseIds[i],
          'position': i,
        });
      }
    });
  }

  Future<Routine> _loadRoutineRow(Map<String, Object?> row) async {
    final exRows = await _db.query(
      'routine_exercises',
      where: 'routine_id = ?',
      whereArgs: [row['id']],
      orderBy: 'position ASC',
    );
    return Routine(
      id: row['id'] as String,
      name: row['name'] as String,
      exerciseIds: exRows.map((r) => r['exercise_id'] as String).toList(),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    final rows = await _db.query('routines');
    final result = <Routine>[];
    for (final row in rows) {
      result.add(await _loadRoutineRow(row));
    }
    return result;
  }

  @override
  Future<Routine?> getRoutine(String id) async {
    final rows = await _db.query('routines', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _loadRoutineRow(rows.first);
  }

  @override
  Future<void> deleteRoutine(String id) async {
    await _db.transaction((txn) async {
      await txn.delete('routine_exercises', where: 'routine_id = ?', whereArgs: [id]);
      await txn.delete('routines', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ==================== TARGETS ====================

  @override
  Future<void> saveTarget(Target target) async {
    await _db.insert(
      'targets',
      {
        'id': target.id,
        'exercise_id': target.exerciseId,
        'target_type': target.targetType,
        'target_value': target.targetValue,
        'current_value': target.currentValue,
        'estimated_completion_date': target.estimatedCompletionDate?.toIso8601String(),
        'created_at': target.createdAt.toIso8601String(),
        'is_completed': target.isCompleted ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Target _targetFromRow(Map<String, Object?> row) => Target(
        id: row['id'] as String,
        exerciseId: row['exercise_id'] as String,
        targetType: row['target_type'] as String,
        targetValue: (row['target_value'] as num).toDouble(),
        currentValue: (row['current_value'] as num).toDouble(),
        estimatedCompletionDate: row['estimated_completion_date'] == null
            ? null
            : DateTime.parse(row['estimated_completion_date'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        isCompleted: (row['is_completed'] as int) == 1,
      );

  @override
  Future<List<Target>> getAllTargets() async {
    final rows = await _db.query('targets');
    return rows.map(_targetFromRow).toList();
  }

  @override
  Future<Target?> getTarget(String id) async {
    final rows = await _db.query('targets', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _targetFromRow(rows.first);
  }

  @override
  Future<void> deleteTarget(String id) async {
    await _db.delete('targets', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Target>> getTargetsForExercise(String exerciseId) async {
    final rows = await _db.query('targets', where: 'exercise_id = ?', whereArgs: [exerciseId]);
    return rows.map(_targetFromRow).toList();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: PASS (all tests, including Task 2's).

- [ ] **Step 5: Commit**

```bash
git add workout-logger/lib/services/sqlite_storage_service.dart workout-logger/test/sqlite_storage_service_test.dart
git commit -m "feat: implement routine and target CRUD in SqliteStorageService"
```

---

### Task 4: `SqliteStorageService` — muscle groups + custom exercises

**Files:**
- Modify: `workout-logger/lib/services/sqlite_storage_service.dart`
- Modify: `workout-logger/test/sqlite_storage_service_test.dart`

**Interfaces:**
- Consumes: `exercises`, `exercise_muscle_activations`, `muscle_groups` tables; `ExerciseDatabase.getAll()` / `getById()` for built-ins.
- Produces: working `updateMuscleGroupGrowthRate`, `getAllMuscleGroups`, `getMuscleGroup`, `saveCustomExercise`, `getCustomExercises`, `deleteCustomExercise`, `getAllExercises`, `getExercise`.

- [ ] **Step 1: Write the failing tests**

Append to `workout-logger/test/sqlite_storage_service_test.dart`:

```dart
  group('SqliteStorageService — muscle groups', () {
    test('updateMuscleGroupGrowthRate updates an existing group', () async {
      final groups = await storage.getAllMuscleGroups();
      final chest = groups.firstWhere((g) => g.name == 'Chest');
      await storage.updateMuscleGroupGrowthRate(chest.id, 2.5);
      final updated = await storage.getMuscleGroup(chest.id);
      expect(updated!.growthRate, 2.5);
    });
  });

  group('SqliteStorageService — custom exercises', () {
    test('saveCustomExercise + getExercise round-trips muscle activations', () async {
      final exercise = Exercise(
        id: 'custom1',
        name: 'Cable Crossover',
        category: 'isolation',
        isCustom: true,
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'chest', activationPercentage: 80),
          MuscleActivation(muscleGroupId: 'triceps', activationPercentage: 20),
        ],
      );
      await storage.saveCustomExercise(exercise);

      final fetched = await storage.getExercise('custom1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Cable Crossover');
      expect(fetched.muscleActivations.length, 2);
      expect(fetched.primaryMuscle, 'chest');
    });

    test('getExercise falls back to built-in exercises', () async {
      final builtIns = ExerciseDatabase.getAll();
      final known = builtIns.first;
      final fetched = await storage.getExercise(known.id);
      expect(fetched!.name, known.name);
    });

    test('getAllExercises merges built-in and custom', () async {
      await storage.saveCustomExercise(Exercise(
        id: 'custom2',
        name: 'My Exercise',
        category: 'compound',
        isCustom: true,
        muscleActivations: [MuscleActivation(muscleGroupId: 'back', activationPercentage: 100)],
      ));
      final all = await storage.getAllExercises();
      expect(all.any((e) => e.id == 'custom2'), isTrue);
      expect(all.length, greaterThan(1));
    });

    test('deleteCustomExercise removes it and its activations', () async {
      await storage.saveCustomExercise(Exercise(
        id: 'custom3',
        name: 'Temp',
        category: 'isolation',
        isCustom: true,
        muscleActivations: [MuscleActivation(muscleGroupId: 'biceps', activationPercentage: 100)],
      ));
      await storage.deleteCustomExercise('custom3');
      expect(await storage.getExercise('custom3'), isNull);
      final custom = await storage.getCustomExercises();
      expect(custom.any((e) => e.id == 'custom3'), isFalse);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: FAIL with `UnimplementedError` on the muscle group / custom exercise tests.

- [ ] **Step 3: Implement muscle groups + custom exercises**

In `workout-logger/lib/services/sqlite_storage_service.dart`, replace the `// ==================== MUSCLE GROUPS / EXERCISES (Task 4) ====================` section with:

```dart
  // ==================== MUSCLE GROUPS ====================

  @override
  Future<void> updateMuscleGroupGrowthRate(String muscleGroupId, double rate) async {
    await _db.update(
      'muscle_groups',
      {'growth_rate': rate, 'last_updated': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [muscleGroupId],
    );
  }

  MuscleGroup _muscleGroupFromRow(Map<String, Object?> row) => MuscleGroup(
        id: row['id'] as String,
        name: row['name'] as String,
        growthRate: (row['growth_rate'] as num).toDouble(),
        lastUpdated: DateTime.parse(row['last_updated'] as String),
      );

  @override
  Future<List<MuscleGroup>> getAllMuscleGroups() async {
    final rows = await _db.query('muscle_groups');
    return rows.map(_muscleGroupFromRow).toList();
  }

  @override
  Future<MuscleGroup?> getMuscleGroup(String id) async {
    final rows = await _db.query('muscle_groups', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _muscleGroupFromRow(rows.first);
  }

  // ==================== CUSTOM EXERCISES ====================

  @override
  Future<void> saveCustomExercise(Exercise exercise) async {
    await _db.transaction((txn) async {
      await txn.delete('exercise_muscle_activations', where: 'exercise_id = ?', whereArgs: [exercise.id]);
      await txn.insert(
        'exercises',
        {
          'id': exercise.id,
          'name': exercise.name,
          'category': exercise.category,
          'is_custom': 1,
          'available_handles':
              exercise.availableHandles == null ? null : jsonEncode(exercise.availableHandles),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final ma in exercise.muscleActivations) {
        await txn.insert('exercise_muscle_activations', {
          'exercise_id': exercise.id,
          'muscle_group_id': ma.muscleGroupId,
          'activation_percentage': ma.activationPercentage,
        });
      }
    });
  }

  Future<Exercise> _loadCustomExerciseRow(Map<String, Object?> row) async {
    final activations = await _db.query(
      'exercise_muscle_activations',
      where: 'exercise_id = ?',
      whereArgs: [row['id']],
    );
    return Exercise(
      id: row['id'] as String,
      name: row['name'] as String,
      category: row['category'] as String,
      isCustom: true,
      availableHandles: row['available_handles'] == null
          ? null
          : (jsonDecode(row['available_handles'] as String) as List).cast<String>(),
      muscleActivations: activations
          .map((a) => MuscleActivation(
                muscleGroupId: a['muscle_group_id'] as String,
                activationPercentage: a['activation_percentage'] as int,
              ))
          .toList(),
    );
  }

  @override
  Future<List<Exercise>> getCustomExercises() async {
    final rows = await _db.query('exercises');
    final result = <Exercise>[];
    for (final row in rows) {
      result.add(await _loadCustomExerciseRow(row));
    }
    return result;
  }

  @override
  Future<void> deleteCustomExercise(String id) async {
    await _db.transaction((txn) async {
      await txn.delete('exercise_muscle_activations', where: 'exercise_id = ?', whereArgs: [id]);
      await txn.delete('exercises', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<List<Exercise>> getAllExercises() async {
    final builtIn = ExerciseDatabase.getAll();
    final custom = await getCustomExercises();
    return [...builtIn, ...custom];
  }

  @override
  Future<Exercise?> getExercise(String id) async {
    final builtIn = ExerciseDatabase.getById(id);
    if (builtIn != null) return builtIn;
    final rows = await _db.query('exercises', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _loadCustomExerciseRow(rows.first);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add workout-logger/lib/services/sqlite_storage_service.dart workout-logger/test/sqlite_storage_service_test.dart
git commit -m "feat: implement muscle group and custom exercise CRUD in SqliteStorageService"
```

---

### Task 5: `SqliteStorageService` — settings, personal records, training programs, conversations, stats

**Files:**
- Modify: `workout-logger/lib/services/sqlite_storage_service.dart`
- Modify: `workout-logger/test/sqlite_storage_service_test.dart`

**Interfaces:**
- Consumes: `settings`, `personal_records`, `training_programs`, `conversations` tables. `TrainingPhase`/`ProgramWeek`/`ChatMessage` `toJson`/`fromJson` (already defined in `lib/models/models.dart`, used the same way the existing Hive `StorageService` uses them).
- Produces: working `saveSetting`, `getSetting`, `savePersonalRecord`, `getPersonalRecord`, `getAllPersonalRecords`, `saveTrainingProgram`, `getAllTrainingPrograms`, `getTrainingProgram`, `deleteTrainingProgram`, `saveConversation`, `getAllConversations`, `getConversation`, `deleteConversation`, `getQuickStats`.

- [ ] **Step 1: Write the failing tests**

Append to `workout-logger/test/sqlite_storage_service_test.dart`:

```dart
  group('SqliteStorageService — settings', () {
    test('saveSetting + getSetting round-trips, overwrite replaces value', () async {
      await storage.saveSetting('user_name', 'Alex');
      expect(await storage.getSetting('user_name'), 'Alex');
      await storage.saveSetting('user_name', 'Sam');
      expect(await storage.getSetting('user_name'), 'Sam');
    });

    test('getSetting returns null for unknown key', () async {
      expect(await storage.getSetting('does_not_exist'), isNull);
    });
  });

  group('SqliteStorageService — personal records', () {
    test('savePersonalRecord + getPersonalRecord round-trips', () async {
      await storage.savePersonalRecord(PersonalRecord(
        exerciseId: 'bench_press',
        bestWeight: 90,
        bestReps: 5,
        bestVolume: 450,
        achievedAt: DateTime(2026, 4, 1),
      ));
      final pr = await storage.getPersonalRecord('bench_press');
      expect(pr!.bestWeight, 90);
    });

    test('getAllPersonalRecords returns everything saved', () async {
      await storage.savePersonalRecord(PersonalRecord(
        exerciseId: 'squat', bestWeight: 150, bestReps: 3, bestVolume: 450, achievedAt: DateTime(2026, 3, 1),
      ));
      final all = await storage.getAllPersonalRecords();
      expect(all.any((r) => r.exerciseId == 'squat'), isTrue);
    });
  });

  group('SqliteStorageService — training programs', () {
    test('saveTrainingProgram + getTrainingProgram round-trips phases/weeks', () async {
      final program = TrainingProgram(
        id: 'p1',
        name: '12-Week Strength',
        totalWeeks: 12,
        phases: [],
        weeks: [],
      );
      await storage.saveTrainingProgram(program);
      final fetched = await storage.getTrainingProgram('p1');
      expect(fetched!.name, '12-Week Strength');
      expect(fetched.totalWeeks, 12);
    });

    test('deleteTrainingProgram removes it', () async {
      await storage.saveTrainingProgram(TrainingProgram(id: 'p2', name: 'X', totalWeeks: 4, phases: [], weeks: []));
      await storage.deleteTrainingProgram('p2');
      expect(await storage.getTrainingProgram('p2'), isNull);
    });
  });

  group('SqliteStorageService — conversations', () {
    test('saveConversation + getConversation round-trips messages', () async {
      final conversation = Conversation(
        id: 'c1',
        title: 'Progress check',
        messages: [ChatMessage(role: 'user', text: 'How is my bench doing?')],
      );
      await storage.saveConversation(conversation);
      final fetched = await storage.getConversation('c1');
      expect(fetched!.messages.single.text, 'How is my bench doing?');
    });

    test('getAllConversations returns most-recently-updated first', () async {
      await storage.saveConversation(Conversation(
        id: 'c2', title: 'Old', updatedAt: DateTime(2026, 1, 1), messages: [],
      ));
      await storage.saveConversation(Conversation(
        id: 'c3', title: 'New', updatedAt: DateTime(2026, 6, 1), messages: [],
      ));
      final all = await storage.getAllConversations();
      expect(all.first.id, 'c3');
    });

    test('deleteConversation removes it', () async {
      await storage.saveConversation(Conversation(id: 'c4', title: 'Temp', messages: []));
      await storage.deleteConversation('c4');
      expect(await storage.getConversation('c4'), isNull);
    });
  });

  group('SqliteStorageService — quick stats', () {
    test('getQuickStats aggregates the last 7 days', () async {
      await storage.saveWorkoutSession(WorkoutSession(
        id: 'stat1',
        date: DateTime.now(),
        duration: 30,
        exercises: [ExerciseLog(exerciseId: 'bench_press', sets: [WorkoutSet(weight: 60, reps: 10)])],
      ));
      final stats = await storage.getQuickStats();
      expect(stats['totalWorkouts'], greaterThanOrEqualTo(1));
      expect(stats['weeklyWorkouts'], greaterThanOrEqualTo(1));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: FAIL with `UnimplementedError` on the new tests.

- [ ] **Step 3: Implement settings, PRs, training programs, conversations, stats**

In `workout-logger/lib/services/sqlite_storage_service.dart`, replace the `// ==================== SETTINGS / PROGRAMS / PRs / CONVERSATIONS (Task 5) ====================` section with:

```dart
  // ==================== SETTINGS ====================

  @override
  Future<void> saveSetting(String key, String value) async {
    await _db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<String?> getSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  // ==================== TRAINING PROGRAMS ====================

  @override
  Future<void> saveTrainingProgram(TrainingProgram program) async {
    await _db.insert(
      'training_programs',
      {
        'id': program.id,
        'name': program.name,
        'description': program.description,
        'total_weeks': program.totalWeeks,
        'author': program.author,
        'is_imported': program.isImported ? 1 : 0,
        'created_at': program.createdAt.toIso8601String(),
        'phases_json': jsonEncode(program.phases.map((p) => p.toJson()).toList()),
        'weeks_json': jsonEncode(program.weeks.map((w) => w.toJson()).toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  TrainingProgram _programFromRow(Map<String, Object?> row) => TrainingProgram(
        id: row['id'] as String,
        name: row['name'] as String,
        description: row['description'] as String?,
        totalWeeks: row['total_weeks'] as int,
        phases: (jsonDecode(row['phases_json'] as String) as List)
            .map((p) => TrainingPhase.fromJson(p as Map<String, dynamic>))
            .toList(),
        weeks: (jsonDecode(row['weeks_json'] as String) as List)
            .map((w) => ProgramWeek.fromJson(w as Map<String, dynamic>))
            .toList(),
        author: row['author'] as String?,
        isImported: (row['is_imported'] as int) == 1,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  @override
  Future<List<TrainingProgram>> getAllTrainingPrograms() async {
    final rows = await _db.query('training_programs', orderBy: 'created_at DESC');
    return rows.map(_programFromRow).toList();
  }

  @override
  Future<TrainingProgram?> getTrainingProgram(String id) async {
    final rows = await _db.query('training_programs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _programFromRow(rows.first);
  }

  @override
  Future<void> deleteTrainingProgram(String id) async {
    await _db.delete('training_programs', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== PERSONAL RECORDS ====================

  @override
  Future<void> savePersonalRecord(PersonalRecord record) async {
    await _db.insert(
      'personal_records',
      {
        'exercise_id': record.exerciseId,
        'best_weight': record.bestWeight,
        'best_reps': record.bestReps,
        'best_volume': record.bestVolume,
        'achieved_at': record.achievedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  PersonalRecord _prFromRow(Map<String, Object?> row) => PersonalRecord(
        exerciseId: row['exercise_id'] as String,
        bestWeight: (row['best_weight'] as num).toDouble(),
        bestReps: row['best_reps'] as int,
        bestVolume: (row['best_volume'] as num).toDouble(),
        achievedAt: DateTime.parse(row['achieved_at'] as String),
      );

  @override
  Future<PersonalRecord?> getPersonalRecord(String exerciseId) async {
    final rows = await _db.query('personal_records', where: 'exercise_id = ?', whereArgs: [exerciseId]);
    return rows.isEmpty ? null : _prFromRow(rows.first);
  }

  @override
  Future<List<PersonalRecord>> getAllPersonalRecords() async {
    final rows = await _db.query('personal_records');
    return rows.map(_prFromRow).toList();
  }

  // ==================== AI CONVERSATIONS ====================

  @override
  Future<void> saveConversation(Conversation conversation) async {
    await _db.insert(
      'conversations',
      {
        'id': conversation.id,
        'title': conversation.title,
        'kind': conversation.kind,
        'created_at': conversation.createdAt.toIso8601String(),
        'updated_at': conversation.updatedAt.toIso8601String(),
        'messages_json': jsonEncode(conversation.messages.map((m) => m.toJson()).toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Conversation _conversationFromRow(Map<String, Object?> row) => Conversation(
        id: row['id'] as String,
        title: row['title'] as String,
        kind: row['kind'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        messages: (jsonDecode(row['messages_json'] as String) as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  @override
  Future<List<Conversation>> getAllConversations() async {
    final rows = await _db.query('conversations', orderBy: 'updated_at DESC');
    return rows.map(_conversationFromRow).toList();
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    final rows = await _db.query('conversations', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _conversationFromRow(rows.first);
  }

  @override
  Future<void> deleteConversation(String id) async {
    await _db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== STATS ====================

  @override
  Future<Map<String, dynamic>> getQuickStats() async {
    final sessions = await getAllWorkoutSessions();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekSessions = sessions.where((s) => s.date.isAfter(weekAgo)).toList();

    double weeklyVolume = 0;
    int exercisesCompleted = 0;
    for (var session in weekSessions) {
      weeklyVolume += session.totalVolume;
      exercisesCompleted += session.exercises.length;
    }

    return {
      'totalWorkouts': sessions.length,
      'weeklyWorkouts': weekSessions.length,
      'weeklyVolume': weeklyVolume,
      'exercisesThisWeek': exercisesCompleted,
    };
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add workout-logger/lib/services/sqlite_storage_service.dart workout-logger/test/sqlite_storage_service_test.dart
git commit -m "feat: implement settings, PR, training program, and conversation CRUD in SqliteStorageService"
```

---

### Task 6: `SqliteStorageService` — export/import

**Files:**
- Modify: `workout-logger/lib/services/sqlite_storage_service.dart`
- Modify: `workout-logger/test/sqlite_storage_service_test.dart`

**Interfaces:**
- Consumes: all read/write methods implemented in Tasks 2–5.
- Produces: working `exportAllData` (JSON shape matching the existing Hive `StorageService.exportAllData` — same top-level keys: `sessions`, `routines`, `targets`, `muscleGroups`, `customExercises`, `conversations`, `settings`, `exportDate`, `appVersion`) and `importData` (same merge-skip-existing semantics as Hive's).

- [ ] **Step 1: Write the failing tests**

Append to `workout-logger/test/sqlite_storage_service_test.dart`:

```dart
  group('SqliteStorageService — export/import', () {
    test('exportAllData includes sessions, routines, settings', () async {
      await storage.saveWorkoutSession(WorkoutSession(
        id: 'exp1', date: DateTime(2026, 5, 1), duration: 20,
        exercises: [ExerciseLog(exerciseId: 'row', sets: [WorkoutSet(weight: 40, reps: 10)])],
      ));
      await storage.saveRoutine(Routine(id: 'exp_r1', name: 'Export Routine', exerciseIds: ['row']));
      await storage.saveSetting('unit', 'kg');

      final json = await storage.exportAllData();
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect((data['sessions'] as List).any((s) => s['id'] == 'exp1'), isTrue);
      expect((data['routines'] as List).any((r) => r['id'] == 'exp_r1'), isTrue);
      expect((data['settings'] as Map)['unit'], 'kg');
    });

    test('importData merges without overwriting existing ids', () async {
      await storage.saveWorkoutSession(WorkoutSession(
        id: 'imp1', date: DateTime(2026, 1, 1), duration: 15,
        exercises: [ExerciseLog(exerciseId: 'row', sets: [WorkoutSet(weight: 30, reps: 12)])],
      ));

      final payload = jsonEncode({
        'sessions': [
          {
            'id': 'imp1', // already exists — must be skipped
            'date': DateTime(2099, 1, 1).toIso8601String(),
            'duration': 999,
            'exercises': [],
          },
          {
            'id': 'imp2', // new — must be imported
            'date': DateTime(2026, 2, 1).toIso8601String(),
            'duration': 25,
            'exercises': [],
          },
        ],
        'settings': {'imported_key': 'imported_value'},
      });

      await storage.importData(payload);

      final existing = await storage.getWorkoutSession('imp1');
      expect(existing!.duration, 15); // untouched
      final imported = await storage.getWorkoutSession('imp2');
      expect(imported!.duration, 25);
      expect(await storage.getSetting('imported_key'), 'imported_value');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: FAIL with `UnimplementedError` on export/import tests.

- [ ] **Step 3: Implement export/import**

In `workout-logger/lib/services/sqlite_storage_service.dart`, replace the `// ==================== EXPORT / IMPORT (Task 6) ====================` section with:

```dart
  // ==================== EXPORT / IMPORT ====================

  Map<String, dynamic>? _normalizeImportItem(dynamic item) {
    if (item is Map<String, dynamic>) return item;
    if (item is Map) return Map<String, dynamic>.from(item);
    if (item is String) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<String> exportAllData() async {
    final sessions = await getAllWorkoutSessions();
    final routines = await getAllRoutines();
    final targets = await getAllTargets();
    final muscleGroups = await getAllMuscleGroups();
    final customExercises = await getCustomExercises();
    final conversations = await getAllConversations();
    final settingsRows = await _db.query('settings');
    final settingsMap = <String, String>{
      for (final row in settingsRows)
        if (row['value'] != null) row['key'] as String: row['value'] as String,
    };

    final data = {
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'routines': routines.map((r) => r.toJson()).toList(),
      'targets': targets.map((t) => t.toJson()).toList(),
      'muscleGroups': muscleGroups.map((m) => m.toJson()).toList(),
      'customExercises': customExercises.map((e) => e.toJson()).toList(),
      'conversations': conversations.map((c) => c.toJson()).toList(),
      'settings': settingsMap,
      'exportDate': DateTime.now().toIso8601String(),
      'appVersion': _appVersion,
    };
    return jsonEncode(data);
  }

  @override
  Future<void> importData(String jsonData) async {
    final data = jsonDecode(jsonData) as Map<String, dynamic>;

    final sessions = data['sessions'];
    if (sessions is List) {
      for (final item in sessions) {
        final map = _normalizeImportItem(item);
        if (map == null) continue;
        final session = WorkoutSession.fromJson(map);
        if (await getWorkoutSession(session.id) == null) {
          await saveWorkoutSession(session);
        }
      }
    }

    final routines = data['routines'];
    if (routines is List) {
      for (final item in routines) {
        final map = _normalizeImportItem(item);
        if (map == null) continue;
        final routine = Routine.fromJson(map);
        if (await getRoutine(routine.id) == null) {
          await saveRoutine(routine);
        }
      }
    }

    final targets = data['targets'];
    if (targets is List) {
      for (final item in targets) {
        final map = _normalizeImportItem(item);
        if (map == null) continue;
        final target = Target.fromJson(map);
        if (await getTarget(target.id) == null) {
          await saveTarget(target);
        }
      }
    }

    final muscleGroups = data['muscleGroups'];
    if (muscleGroups is List) {
      for (final item in muscleGroups) {
        final map = _normalizeImportItem(item);
        if (map == null) continue;
        final mg = MuscleGroup.fromJson(map);
        if (await getMuscleGroup(mg.id) == null) {
          await _db.insert('muscle_groups', {
            'id': mg.id,
            'name': mg.name,
            'growth_rate': mg.growthRate,
            'last_updated': mg.lastUpdated.toIso8601String(),
          });
        }
      }
    }

    final customExercises = data['customExercises'];
    if (customExercises is List) {
      for (final item in customExercises) {
        final map = _normalizeImportItem(item);
        if (map == null) continue;
        final exercise = Exercise.fromJson(map);
        final rows = await _db.query('exercises', where: 'id = ?', whereArgs: [exercise.id]);
        if (rows.isEmpty) {
          await saveCustomExercise(exercise);
        }
      }
    }

    if (data['settings'] is Map) {
      final settings = data['settings'] as Map<String, dynamic>;
      for (final entry in settings.entries) {
        if (await getSetting(entry.key) == null) {
          await saveSetting(entry.key, entry.value.toString());
        }
      }
    }

    final conversations = data['conversations'];
    if (conversations is List) {
      for (final item in conversations) {
        final map = _normalizeImportItem(item);
        if (map == null) continue;
        final conversation = Conversation.fromJson(map);
        if (await getConversation(conversation.id) == null) {
          await saveConversation(conversation);
        }
      }
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd workout-logger && flutter test test/sqlite_storage_service_test.dart`
Expected: PASS — full file, all tasks 2–6 combined (roughly 25 tests).

- [ ] **Step 5: Commit**

```bash
git add workout-logger/lib/services/sqlite_storage_service.dart workout-logger/test/sqlite_storage_service_test.dart
git commit -m "feat: implement export/import in SqliteStorageService, completing IStorageService"
```

---

### Task 7: `StorageService` (Hive) — settings enumeration for migration

**Files:**
- Modify: `workout-logger/lib/services/storage_service.dart`
- Test: `workout-logger/test/storage_service_test.dart`

**Interfaces:**
- Produces: `Future<Map<String, String>> getAllSettingsForMigration()` — a concrete-class-only addition (not part of `IStorageService`), used exclusively by `StorageMigrationService` (Task 8) to enumerate every settings key. Not on the interface because no other consumer needs to list all keys.

- [ ] **Step 1: Write the failing test**

Append to `workout-logger/test/storage_service_test.dart`, inside the existing `group('StorageService CRUD & Operations', () { ... })`:

```dart
    test('getAllSettingsForMigration returns every saved key/value', () async {
      await storage.saveSetting('mig_key_1', 'value_1');
      await storage.saveSetting('mig_key_2', 'value_2');

      final all = await storage.getAllSettingsForMigration();

      expect(all['mig_key_1'], 'value_1');
      expect(all['mig_key_2'], 'value_2');
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workout-logger && flutter test test/storage_service_test.dart`
Expected: FAIL — `getAllSettingsForMigration` is not defined on `StorageService`.

- [ ] **Step 3: Implement the helper**

In `workout-logger/lib/services/storage_service.dart`, add this method right after `getSetting` (inside the `// ==================== SETTINGS ====================` section):

```dart
  /// Every stored setting key/value. Used only by [StorageMigrationService]
  /// to migrate the settings box to the SQLite backend — not part of
  /// [IStorageService] since no other consumer needs to enumerate all keys.
  Future<Map<String, String>> getAllSettingsForMigration() async {
    final map = <String, String>{};
    for (final key in _settingsBoxInstance.keys) {
      final value = _settingsBoxInstance.get(key);
      if (value != null) map[key as String] = value;
    }
    return map;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd workout-logger && flutter test test/storage_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add workout-logger/lib/services/storage_service.dart workout-logger/test/storage_service_test.dart
git commit -m "feat: add settings enumeration helper to StorageService for migration"
```

---

### Task 8: `StorageMigrationService`

**Files:**
- Create: `workout-logger/lib/services/storage_migration_service.dart`
- Test: `workout-logger/test/storage_migration_service_test.dart`

**Interfaces:**
- Consumes: `StorageService` (Hive, Task 7's `getAllSettingsForMigration`), `SqliteStorageService` (Tasks 2–6, full `IStorageService`).
- Produces: `class StorageMigrationService { StorageMigrationService(StorageService source, SqliteStorageService target); Future<void> migrate(); }`. Throws on any failure (caller in Task 9 decides fallback) — does not catch internally.

- [ ] **Step 1: Write the failing test**

Create `workout-logger/test/storage_migration_service_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/storage_service.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/storage_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService hiveStorage;
  late SqliteStorageService sqliteStorage;

  setUpAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == 'getApplicationDocumentsDirectory' ? './test/tmp_hive_migration_service' : null,
    );
    Hive.init('./test/tmp_hive_migration_service');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    hiveStorage = StorageService();
    await hiveStorage.init();
    sqliteStorage = SqliteStorageService(databasePathOverride: inMemoryDatabasePath);
    await sqliteStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  test('migrate copies every entity type from Hive to SQLite', () async {
    await hiveStorage.saveWorkoutSession(WorkoutSession(
      id: 'sess1', date: DateTime(2026, 5, 1), duration: 40,
      exercises: [ExerciseLog(exerciseId: 'bench_press', sets: [WorkoutSet(weight: 70, reps: 8)])],
    ));
    await hiveStorage.saveRoutine(Routine(id: 'r1', name: 'Push Day', exerciseIds: ['bench_press']));
    await hiveStorage.saveTarget(Target(id: 't1', exerciseId: 'bench_press', targetType: 'weight', targetValue: 100));
    await hiveStorage.savePersonalRecord(PersonalRecord(
      exerciseId: 'bench_press', bestWeight: 90, bestReps: 5, bestVolume: 450, achievedAt: DateTime(2026, 4, 1),
    ));
    await hiveStorage.saveCustomExercise(Exercise(
      id: 'custom_mig', name: 'Migrated Exercise', category: 'isolation', isCustom: true,
      muscleActivations: [MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100)],
    ));
    await hiveStorage.saveConversation(Conversation(id: 'conv1', title: 'Chat', messages: []));
    await hiveStorage.saveSetting('user_name', 'Alex');

    await StorageMigrationService(hiveStorage, sqliteStorage).migrate();

    expect((await sqliteStorage.getWorkoutSession('sess1'))?.duration, 40);
    expect((await sqliteStorage.getRoutine('r1'))?.name, 'Push Day');
    expect((await sqliteStorage.getTarget('t1'))?.targetValue, 100);
    expect((await sqliteStorage.getPersonalRecord('bench_press'))?.bestWeight, 90);
    expect((await sqliteStorage.getExercise('custom_mig'))?.name, 'Migrated Exercise');
    expect((await sqliteStorage.getConversation('conv1'))?.title, 'Chat');
    expect(await sqliteStorage.getSetting('user_name'), 'Alex');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workout-logger && flutter test test/storage_migration_service_test.dart`
Expected: FAIL — `lib/services/storage_migration_service.dart` does not exist.

- [ ] **Step 3: Implement `StorageMigrationService`**

Create `workout-logger/lib/services/storage_migration_service.dart`:

```dart
// One-time migration from the Hive-backed StorageService to
// SqliteStorageService. Reads exclusively through StorageService's existing,
// already-correct read methods; writes exclusively through
// SqliteStorageService's write methods. Throws on any failure — the caller
// (main.dart) decides whether to fall back to Hive. See
// docs/superpowers/specs/2026-08-08-sqlite-migration-and-coach-sql-tool-design.md §6.

import 'storage_service.dart';
import 'sqlite_storage_service.dart';

class StorageMigrationService {
  StorageMigrationService(this._source, this._target);

  final StorageService _source;
  final SqliteStorageService _target;

  Future<void> migrate() async {
    for (final session in await _source.getAllWorkoutSessions()) {
      await _target.saveWorkoutSession(session);
    }
    for (final routine in await _source.getAllRoutines()) {
      await _target.saveRoutine(routine);
    }
    for (final target in await _source.getAllTargets()) {
      await _target.saveTarget(target);
    }
    for (final mg in await _source.getAllMuscleGroups()) {
      await _target.updateMuscleGroupGrowthRate(mg.id, mg.growthRate);
    }
    for (final exercise in await _source.getCustomExercises()) {
      await _target.saveCustomExercise(exercise);
    }
    for (final record in await _source.getAllPersonalRecords()) {
      await _target.savePersonalRecord(record);
    }
    for (final program in await _source.getAllTrainingPrograms()) {
      await _target.saveTrainingProgram(program);
    }
    for (final conversation in await _source.getAllConversations()) {
      await _target.saveConversation(conversation);
    }
    final settings = await _source.getAllSettingsForMigration();
    for (final entry in settings.entries) {
      await _target.saveSetting(entry.key, entry.value);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd workout-logger && flutter test test/storage_migration_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add workout-logger/lib/services/storage_migration_service.dart workout-logger/test/storage_migration_service_test.dart
git commit -m "feat: add StorageMigrationService for one-time Hive-to-SQLite migration"
```

---

### Task 9: Wire the storage backend resolution into `main.dart`

**Files:**
- Modify: `workout-logger/lib/main.dart`

**Interfaces:**
- Consumes: `StorageService`, `SqliteStorageService`, `StorageMigrationService` (Tasks 2, 7, 8).
- Produces: top-level `IStorageService? _resolvedStorageService` and `Future<void> _resolveStorageBackend()`, called from `main()` before `runApp()`. `WorkoutLoggerApp._storageService`'s existing `static final` initializer reads `_resolvedStorageService!` — this works correctly because Dart `static`/top-level variables are lazily initialized on first access, and `_storageService` isn't accessed until `build()` runs, by which point `_resolveStorageBackend()` has already completed inside `main()`.

This task has no automated test — `main()`/composition-root wiring isn't unit-testable without a larger DI refactor that's out of scope here (every dependent entity — `WorkoutProvider`, `CoachToolService`, etc. — is already covered by its own tests against `IStorageService`/`MockStorageService`). Verification is `flutter analyze` plus a manual run.

- [ ] **Step 1: Add imports**

In `workout-logger/lib/main.dart`, add these imports alongside the existing `services/storage_service.dart` import:

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'services/sqlite_storage_service.dart';
import 'services/storage_migration_service.dart';
import 'services/ai/sql_query_service.dart';
```

- [ ] **Step 2: Add the resolver function**

In `workout-logger/lib/main.dart`, add this above `void main() async {`:

```dart
/// Resolved once in main() before runApp(). Read lazily by
/// WorkoutLoggerApp._storageService's static initializer, which only runs
/// on first access (during build()) — by then this is already set.
IStorageService? _resolvedStorageService;

/// One-time, flag-gated, reversible Hive -> SQLite cutover. See
/// docs/superpowers/specs/2026-08-08-sqlite-migration-and-coach-sql-tool-design.md §6.
Future<void> _resolveStorageBackend() async {
  await Hive.initFlutter();
  final settingsBox = await Hive.openBox<String>('settings');
  final alreadyMigrated = settingsBox.get('storage_migrated_v1') == 'true';

  if (alreadyMigrated) {
    final sqlite = SqliteStorageService();
    await sqlite.init();
    _resolvedStorageService = sqlite;
    return;
  }

  final hiveStorage = StorageService();
  await hiveStorage.init();
  final sqliteStorage = SqliteStorageService();
  await sqliteStorage.init();

  var migrationSucceeded = false;
  try {
    await StorageMigrationService(hiveStorage, sqliteStorage).migrate();
    await hiveStorage.saveSetting('storage_migrated_v1', 'true');
    migrationSucceeded = true;
  } catch (e, st) {
    debugPrint('Storage migration to SQLite failed, staying on Hive: $e\n$st');
  }

  _resolvedStorageService = migrationSucceeded ? sqliteStorage : hiveStorage;
}
```

- [ ] **Step 3: Call the resolver before `runApp`**

In `workout-logger/lib/main.dart`, modify `void main() async { ... }` to call the resolver right before `runApp`:

```dart
  // Keep all system overlays transparent; content uses SafeArea for insets
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await _resolveStorageBackend();

  runApp(const WorkoutLoggerApp());
}
```

- [ ] **Step 4: Point the composition root at the resolved backend**

In `workout-logger/lib/main.dart`, change the `_storageService` static field:

```dart
  static final IStorageService _storageService = StorageService();
```

to:

```dart
  static final IStorageService _storageService = _resolvedStorageService!;
```

- [ ] **Step 5: Wire the coach's SQL tool, only when SQLite is active**

In `workout-logger/lib/main.dart`, modify the `Provider<CoachToolService>` block:

```dart
        // CoachToolService backs AI tool calls; reads from WorkoutProvider + PRManager.
        Provider<CoachToolService>(
          create: (ctx) => CoachToolService(
            ctx.read<WorkoutProvider>(),
            ctx.read<PRManager>(),
            healthHistory: ctx.read<HealthHistoryManager>(),
          ),
        ),
```

to:

```dart
        // CoachToolService backs AI tool calls; reads from WorkoutProvider + PRManager.
        // run_sql_query is only offered once the app has cut over to SQLite —
        // it needs a live database file to open a read-only connection against.
        Provider<CoachToolService>(
          create: (ctx) => CoachToolService(
            ctx.read<WorkoutProvider>(),
            ctx.read<PRManager>(),
            healthHistory: ctx.read<HealthHistoryManager>(),
            sqlQuery: _storageService is SqliteStorageService
                ? SqlQueryService((_storageService as SqliteStorageService).databasePath)
                : null,
          ),
        ),
```

- [ ] **Step 6: Verify with static analysis**

Run: `cd workout-logger && flutter analyze lib/main.dart`
Expected: no errors. (`sqlQuery` and `SqlQueryService` won't exist yet — Task 11 adds the `CoachToolService` constructor parameter. If `flutter analyze` fails here because of that, that's expected; re-run this step after Task 11 instead and treat this as a checkpoint, not a blocker to committing Task 9's `main.dart` changes on their own branch state.)

- [ ] **Step 7: Commit**

```bash
git add workout-logger/lib/main.dart
git commit -m "feat: resolve Hive-vs-SQLite storage backend in main() before runApp"
```

---

### Task 10: `SqlQueryService` — read-only SQL execution

**Files:**
- Create: `workout-logger/lib/services/ai/sql_query_service.dart`
- Test: `workout-logger/test/sql_query_service_test.dart`

**Interfaces:**
- Produces: `class SqlQueryService { SqlQueryService(String databasePath); Future<Map<String, Object?>> runQuery(String rawQuery, {int? limit}); }`. Returns `{'row_count': int, 'rows': List<Map<String, Object?>>}` on success, `{'error': String}` on any validation or execution failure — never throws.

- [ ] **Step 1: Write the failing test**

Create `workout-logger/test/sql_query_service_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/services/ai/sql_query_service.dart';

void main() {
  late String dbPath;
  late Database seedDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbPath = '${Directory.systemTemp.path}/sql_query_test_${DateTime.now().microsecondsSinceEpoch}.db';
    seedDb = await openDatabase(dbPath, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE widgets (id INTEGER PRIMARY KEY, name TEXT)');
      await db.insert('widgets', {'id': 1, 'name': 'foo'});
      await db.insert('widgets', {'id': 2, 'name': 'bar'});
    });
  });

  tearDown(() async {
    await seedDb.close();
    final f = File(dbPath);
    if (await f.exists()) await f.delete();
  });

  test('valid SELECT returns rows', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM widgets ORDER BY id');
    expect(result['row_count'], 2);
    expect((result['rows'] as List).first, {'id': 1, 'name': 'foo'});
  });

  test('rejects non-SELECT statements', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('DELETE FROM widgets');
    expect(result['error'], contains('Only SELECT'));
  });

  test('rejects multi-statement input', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM widgets; DROP TABLE widgets;');
    expect(result['error'], contains('single SQL statement'));
  });

  test('caps row count via limit', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM widgets', limit: 1);
    expect(result['row_count'], 1);
  });

  test('returns error map instead of throwing on invalid SQL', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM does_not_exist');
    expect(result['error'], isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workout-logger && flutter test test/sql_query_service_test.dart`
Expected: FAIL — `lib/services/ai/sql_query_service.dart` does not exist.

- [ ] **Step 3: Implement `SqlQueryService`**

Create `workout-logger/lib/services/ai/sql_query_service.dart`:

```dart
// Executes model-submitted read-only SQL against a dedicated read-only
// connection to the app's live SQLite database. Used only by the coach's
// run_sql_query tool — never the app's own read/write connection. See
// docs/superpowers/specs/2026-08-08-sqlite-migration-and-coach-sql-tool-design.md §7.

import 'package:sqflite/sqflite.dart';

class SqlValidationException implements Exception {
  SqlValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SqlQueryService {
  SqlQueryService(this.databasePath);

  final String databasePath;

  static const _forbiddenKeywords = [
    'INSERT',
    'UPDATE',
    'DELETE',
    'DROP',
    'ALTER',
    'CREATE',
    'ATTACH',
    'DETACH',
    'PRAGMA',
    'VACUUM',
    'REPLACE',
    'TRIGGER',
  ];

  String _sanitize(String rawQuery) {
    var q = rawQuery.trim();
    if (q.endsWith(';')) {
      q = q.substring(0, q.length - 1).trim();
    }
    if (q.contains(';')) {
      throw SqlValidationException('Only a single SQL statement is allowed.');
    }
    final upper = q.toUpperCase();
    if (!(upper.startsWith('SELECT') || upper.startsWith('WITH'))) {
      throw SqlValidationException('Only SELECT queries are allowed.');
    }
    for (final kw in _forbiddenKeywords) {
      if (RegExp('\\b$kw\\b').hasMatch(upper)) {
        throw SqlValidationException('Query contains a forbidden keyword: $kw');
      }
    }
    return q;
  }

  /// Runs [rawQuery] read-only and returns {'row_count', 'rows'} on success
  /// or {'error': message} on any validation or execution failure. Never
  /// throws — callers (the coach tool loop) always get a JSON-safe result.
  Future<Map<String, Object?>> runQuery(String rawQuery, {int? limit}) async {
    final cappedLimit = (limit ?? 200).clamp(1, 500);

    final String safeQuery;
    try {
      safeQuery = _sanitize(rawQuery);
    } on SqlValidationException catch (e) {
      return {'error': e.message};
    }

    Database? db;
    try {
      db = await openReadOnlyDatabase(databasePath);
      final rows = await db.rawQuery('SELECT * FROM ($safeQuery) LIMIT ?', [cappedLimit]);
      return {'row_count': rows.length, 'rows': rows};
    } catch (e) {
      return {'error': 'Query failed: $e'};
    } finally {
      await db?.close();
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd workout-logger && flutter test test/sql_query_service_test.dart`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Commit**

```bash
git add workout-logger/lib/services/ai/sql_query_service.dart workout-logger/test/sql_query_service_test.dart
git commit -m "feat: add SqlQueryService for read-only SQL execution"
```

---

### Task 11: Wire `run_sql_query` into `CoachToolService`

**Files:**
- Modify: `workout-logger/lib/services/ai/coach_tool_service.dart`
- Modify: `workout-logger/test/coach_tool_service_test.dart`

**Interfaces:**
- Consumes: `SqlQueryService` (Task 10).
- Produces: `CoachToolService(WorkoutProvider, PRManager, {HealthHistoryManager? healthHistory, SqlQueryService? sqlQuery})`. `run_sql_query` is only advertised in `buildTools()` when `sqlQuery` is non-null.

- [ ] **Step 1: Write the failing tests**

In `workout-logger/test/coach_tool_service_test.dart`, add these imports at the top:

```dart
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/ai/sql_query_service.dart';
```

Then, inside the existing `group('CoachToolService', () { ... })` (after the existing `setUp`), add a nested group:

```dart
    group('run_sql_query', () {
      late String dbPath;
      late SqliteStorageService sqliteStorage;

      setUpAll(() {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      });

      setUp(() async {
        dbPath = '${Directory.systemTemp.path}/coach_sql_test_${DateTime.now().microsecondsSinceEpoch}.db';
        sqliteStorage = SqliteStorageService(databasePathOverride: dbPath);
        await sqliteStorage.init();
        await sqliteStorage.saveWorkoutSession(WorkoutSession(
          id: 'sess1', date: DateTime(2026, 5, 1), duration: 40,
          exercises: [ExerciseLog(exerciseId: 'bench_press', sets: [WorkoutSet(weight: 70, reps: 8)])],
        ));
      });

      tearDown(() async {
        final f = File(dbPath);
        if (await f.exists()) await f.delete();
      });

      test('is not advertised when no SqlQueryService is provided', () {
        final declared =
            tools.buildTools().expand((t) => t.functionDeclarations ?? []).map((f) => f.name);
        expect(declared, isNot(contains('run_sql_query')));
      });

      test('is advertised and runs a live SELECT when wired', () async {
        final withSql = CoachToolService(provider, pr, sqlQuery: SqlQueryService(dbPath));

        final declared =
            withSql.buildTools().expand((t) => t.functionDeclarations ?? []).map((f) => f.name);
        expect(declared, contains('run_sql_query'));

        final result = await withSql.handleCall(
          FunctionCall('run_sql_query', {'query': 'SELECT id, duration_min FROM sessions'}),
        );
        expect(result['row_count'], 1);
        expect((result['rows'] as List).first, {'id': 'sess1', 'duration_min': 40});
      });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd workout-logger && flutter test test/coach_tool_service_test.dart`
Expected: FAIL — `sqlQuery` is not a recognized named parameter on `CoachToolService`.

- [ ] **Step 3: Wire the tool**

In `workout-logger/lib/services/ai/coach_tool_service.dart`:

Add the import at the top, alongside the existing imports:

```dart
import 'sql_query_service.dart';
```

Change the class fields and constructor:

```dart
class CoachToolService {
  final WorkoutProvider _wp;
  final PRManager _pr;
  final HealthHistoryManager? _hh;
  final SqlQueryService? _sql;

  CoachToolService(
    this._wp,
    this._pr, {
    HealthHistoryManager? healthHistory,
    SqlQueryService? sqlQuery,
  })  : _hh = healthHistory,
        _sql = sqlQuery;
```

In `buildTools()`, find the closing of the `functionDeclarations` list (right after the `get_sleeping_hr_analytics` declaration, before the final `]),` that closes the `Tool(...)`), and add the conditional entry:

```dart
          FunctionDeclaration(
            'get_sleeping_hr_analytics',
            // ... (existing declaration body, unchanged)
          ),
          if (_sql != null) _runSqlQueryDeclaration,
        ]),
      ];
```

Add this getter right after `buildTools()` (before `/// Dispatch a model function call...`):

```dart
  /// Schema-aware declaration for run_sql_query — only included when a
  /// SqlQueryService is wired (i.e. the app has cut over to SQLite).
  FunctionDeclaration get _runSqlQueryDeclaration => FunctionDeclaration(
        'run_sql_query',
        'Run a read-only SQL SELECT query directly against the workout database '
            'for questions the other tools cannot answer (custom joins, filters, '
            'or aggregations). Tables:\n'
            'sessions(id, date, routine_id, duration_min, notes, hc_synced_at)\n'
            'exercise_logs(id, session_id, exercise_id, notes, handle)\n'
            'sets(id, exercise_log_id, weight, reps, is_dropset, drops_json, '
            'time_taken, timestamp, assist_weight, extra_weight, handle)\n'
            'exercises(id, name, category, is_custom, available_handles) — custom '
            'exercises only; built-ins are not stored here\n'
            'muscle_groups(id, name, growth_rate, last_updated)\n'
            'exercise_muscle_activations(exercise_id, muscle_group_id, activation_percentage)\n'
            'routines(id, name, created_at)\n'
            'routine_exercises(routine_id, exercise_id, position)\n'
            'targets(id, exercise_id, target_type, target_value, current_value, '
            'estimated_completion_date, created_at, is_completed)\n'
            'personal_records(exercise_id, best_weight, best_reps, best_volume, achieved_at)\n'
            'Only SELECT/WITH statements are allowed, one statement per call.',
        Schema.object(
          properties: {
            'query': Schema.string(
              description: 'A single read-only SQL SELECT statement.',
            ),
            'limit': Schema.integer(
              description: 'Optional. Max rows to return (default 200, max 500).',
              nullable: true,
            ),
          },
          requiredProperties: ['query'],
        ),
      );
```

In `handleCall()`, add a case to the `switch (call.name)`:

```dart
      case 'run_sql_query':
        final sql = _sql;
        if (sql == null) return {'error': 'SQL query tool is not available.'};
        return await sql.runQuery(
          (call.args['query'] as String?) ?? '',
          limit: (call.args['limit'] as num?)?.toInt(),
        );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd workout-logger && flutter test test/coach_tool_service_test.dart`
Expected: PASS (all existing tests plus the two new `run_sql_query` tests).

- [ ] **Step 5: Re-verify `main.dart` now compiles end-to-end**

Run: `cd workout-logger && flutter analyze lib/main.dart lib/services/ai/coach_tool_service.dart`
Expected: no errors — this closes the loop left open at the end of Task 9 Step 6.

- [ ] **Step 6: Commit**

```bash
git add workout-logger/lib/services/ai/coach_tool_service.dart workout-logger/test/coach_tool_service_test.dart
git commit -m "feat: wire run_sql_query tool into CoachToolService"
```

---

### Task 12: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Static analysis across the whole project**

Run: `cd workout-logger && flutter analyze`
Expected: no errors introduced by this plan's changes (pre-existing warnings, if any, are out of scope).

- [ ] **Step 2: Full test suite**

Run: `cd workout-logger && flutter test`
Expected: all tests pass, including every test added in Tasks 2–11 plus the full pre-existing suite (managers, providers, screens — all unaffected since they depend on `IStorageService`/`MockStorageService`, never a concrete backend).

- [ ] **Step 3: Manual smoke test — fresh install path**

Run: `cd workout-logger && flutter run` (with no existing app data, e.g. a fresh emulator or `flutter clean` + reinstall).
Expected: app launches normally, `storage_migrated_v1` gets set on first launch (no prior Hive data to migrate, so migration is instant), Coach chat still works, and asking the Coach a question that needs `run_sql_query` (e.g. "what's the total volume for each exercise this month, sorted highest to lowest?") produces a sensible answer — confirms the tool is both advertised and functional against real live data.

- [ ] **Step 4: Manual smoke test — upgrade path (if a build with existing Hive data is available)**

Install a version prior to this change, log a few workouts, then install this branch's build over it.
Expected: app launches normally, prior workout history is visible (now served from SQLite), and re-launching the app a second time does not re-run the migration (check via logs — `_resolveStorageBackend` should hit the `alreadyMigrated` branch and skip straight to opening `SqliteStorageService`).

- [ ] **Step 5: Commit (if any fixups were needed)**

```bash
git add -A
git commit -m "chore: fix issues found during full verification of SQLite migration"
```

(Skip this step if Steps 1–4 all passed cleanly with no changes needed.)
