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
      : _databasePathOverride = databasePathOverride,
        _instanceId = _nextInstanceId++;

  static const String _dbName = 'repforge.db';
  static const int _dbVersion = 1;
  static int _nextInstanceId = 0;

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
  final int _instanceId;
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

    var dbPath = _databasePathOverride ?? '${await getDatabasesPath()}/$_dbName';

    // For in-memory databases in tests, create unique isolated databases per instance
    if (dbPath == ':memory:') {
      dbPath = 'file:memdb_$_instanceId?mode=memory&cache=shared';
    }

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
  Future<List<MuscleGroup>> getAllMuscleGroups() async {
    final rows = await _db.query('muscle_groups');
    return rows
        .map((row) => MuscleGroup(
              id: row['id'] as String,
              name: row['name'] as String,
              growthRate: (row['growth_rate'] as num).toDouble(),
              lastUpdated: DateTime.parse(row['last_updated'] as String),
            ))
        .toList();
  }

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
