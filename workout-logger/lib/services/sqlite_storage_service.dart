// SQLite-backed implementation of IStorageService — replaces Hive as the
// persistence backend. See docs/superpowers/specs/2026-08-08-sqlite-migration-and-coach-sql-tool-design.md
// for the schema and migration design this implements.

import 'dart:convert';
import 'dart:io';
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
  static const int _dbVersion = 2;
  static int _nextInstanceId = 0;

  /// Added in schema v2 (health sync). Kept separate from the rest of
  /// [_schemaStatements] so `onUpgrade` can run exactly these statements
  /// against pre-v2 databases without re-running the full v1 DDL.
  static const List<String> _healthSchemaStatements = [
    '''CREATE TABLE IF NOT EXISTS health_samples (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      value REAL NOT NULL
    )''',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_health_samples_unique ON health_samples(type, timestamp)',
    'CREATE INDEX IF NOT EXISTS idx_health_samples_type_ts ON health_samples(type, timestamp)',
    '''CREATE TABLE IF NOT EXISTS sleep_sessions (
      id TEXT PRIMARY KEY,
      start_ts TEXT NOT NULL,
      end_ts TEXT NOT NULL,
      light_min INTEGER,
      deep_min INTEGER,
      rem_min INTEGER,
      awake_min INTEGER
    )''',
    'CREATE INDEX IF NOT EXISTS idx_sleep_sessions_start ON sleep_sessions(start_ts)',
    '''CREATE TABLE IF NOT EXISTS sleep_stage_intervals (
      sleep_session_id TEXT NOT NULL,
      start_ts TEXT NOT NULL,
      end_ts TEXT NOT NULL,
      stage TEXT NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_sleep_stage_session ON sleep_stage_intervals(sleep_session_id)',
  ];

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
      body_weight_at_log REAL,
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
    ..._healthSchemaStatements,
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

  Future<void> close() async {
    await _db.close();
    _initialized = false;
  }

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
    // to support multiple concurrent test databases. Uses temp files because sqflite FFI's
    // shared-cache memory URIs don't support read-only secondary connections.
    if (dbPath == ':memory:') {
      dbPath = '${Directory.systemTemp.path}${Platform.pathSeparator}repforge_test_${DateTime.now().microsecondsSinceEpoch}_$_instanceId.db';
    }

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
            'body_weight_at_log': set.bodyWeightAtLog,
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
                  bodyWeightAtLog: (s['body_weight_at_log'] as num?)?.toDouble(),
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
          'timestamp': s.time.toLocal().toIso8601String(),
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
        final id = p.start.toLocal().toIso8601String();
        await txn.delete(
          'sleep_stage_intervals',
          where: 'sleep_session_id = ?',
          whereArgs: [id],
        );
        await txn.insert(
          'sleep_sessions',
          {
            'id': id,
            'start_ts': p.start.toLocal().toIso8601String(),
            'end_ts': p.end.toLocal().toIso8601String(),
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
            'start_ts': seg.start.toLocal().toIso8601String(),
            'end_ts': seg.end.toLocal().toIso8601String(),
            'stage': seg.stage,
          });
        }
      }
    });
  }

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
}
