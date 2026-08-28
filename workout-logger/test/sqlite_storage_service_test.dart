import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/data/exercise_database.dart';

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

  tearDown(() async {
    final path = storage.databasePath;
    await storage.close();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  });

  group('SqliteStorageService — init', () {
    test('seeds default muscle groups', () async {
      final groups = await storage.getAllMuscleGroups();
      expect(groups, isNotEmpty);
      expect(groups.any((g) => g.name == 'Chest'), isTrue);
    });
  });

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
    // A DST fall-back maps two distinct UTC instants onto the same local
    // wall-clock string. Identity therefore lives on utc_ts, not on the local
    // timestamp column — asserted here without depending on the machine's
    // timezone actually observing DST.
    test('two instants sharing a local wall-clock string both survive', () async {
      final db = await openDatabase(storage.databasePath, singleInstance: false);
      const localString = '2026-11-01T01:30:00.000';
      await db.insert('health_samples', {
        'type': 'heart_rate',
        'timestamp': localString,
        'utc_ts': '2026-11-01T05:30:00.000Z',
        'value': 60.0,
      });
      await db.insert('health_samples', {
        'type': 'heart_rate',
        'timestamp': localString,
        'utc_ts': '2026-11-01T06:30:00.000Z',
        'value': 65.0,
      });
      await db.close();

      final rows = await rawQuery(
        storage,
        "SELECT value FROM health_samples WHERE type = 'heart_rate' ORDER BY utc_ts",
      );
      expect(rows.length, 2);
      expect(rows.map((r) => r['value']), [60.0, 65.0]);
    });

    test('upsertHealthSamples records the exact UTC instant in utc_ts', () async {
      final utcTime = DateTime.utc(2026, 8, 10, 21, 0);
      await storage.upsertHealthSamples('heart_rate', [HealthSample(time: utcTime, value: 60)]);

      final rows = await rawQuery(
        storage,
        "SELECT utc_ts FROM health_samples WHERE type = 'heart_rate'",
      );
      final stored = rows.first['utc_ts'] as String;
      expect(stored.endsWith('Z'), isTrue);
      expect(DateTime.parse(stored).toUtc(), utcTime);
    });

    test('sleep session id is the UTC start instant, not the local one', () async {
      final start = DateTime.utc(2026, 11, 1, 5, 30);
      await storage.upsertSleepSessions([
        SleepPeriod(
          start: start,
          end: start.add(const Duration(hours: 8)),
          lightMinutes: 200,
          deepMinutes: 60,
          remMinutes: 100,
          awakeMinutes: 10,
          stageTimeline: const [],
        ),
      ]);

      final rows = await rawQuery(storage, 'SELECT id, start_ts FROM sleep_sessions');
      expect(rows.length, 1);
      final id = rows.first['id'] as String;
      expect(id, start.toIso8601String());
      expect(DateTime.parse(id).toUtc(), start);
      // start_ts stays local so it joins cleanly against workout_sessions.date.
      expect((rows.first['start_ts'] as String).endsWith('Z'), isFalse);
    });

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

    test('upsertHealthSamples stores timestamps converted to local, not UTC', () async {
      final utcTime = DateTime.utc(2026, 8, 10, 21, 0);
      await storage.upsertHealthSamples('heart_rate', [HealthSample(time: utcTime, value: 60)]);

      final rows = await rawQuery(
        storage,
        "SELECT timestamp FROM health_samples WHERE type = 'heart_rate'",
      );
      final stored = rows.first['timestamp'] as String;
      expect(stored.contains('Z'), isFalse);
      expect(stored, utcTime.toLocal().toIso8601String());
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

      await upgraded.close();
      await File(path).delete();
    });

    test('onUpgrade rebuilds v2 health tables on the utc_ts shape', () async {
      final path =
          '${Directory.systemTemp.path}/sqlite_v2_upgrade_${DateTime.now().microsecondsSinceEpoch}.db';
      final v2 = await openDatabase(
        path,
        version: 2,
        onCreate: (db, v) async {
          await db.execute('''CREATE TABLE muscle_groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            growth_rate REAL NOT NULL DEFAULT 0,
            last_updated TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )''');
          // The v2 shape: no utc_ts, unique on the ambiguous local string.
          await db.execute('''CREATE TABLE health_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            value REAL NOT NULL
          )''');
          await db.execute(
              'CREATE UNIQUE INDEX idx_health_samples_unique ON health_samples(type, timestamp)');
          await db.execute('''CREATE TABLE sleep_sessions (
            id TEXT PRIMARY KEY,
            start_ts TEXT NOT NULL,
            end_ts TEXT NOT NULL,
            light_min INTEGER,
            deep_min INTEGER,
            rem_min INTEGER,
            awake_min INTEGER
          )''');
          await db.execute('''CREATE TABLE sleep_stage_intervals (
            sleep_session_id TEXT NOT NULL,
            start_ts TEXT NOT NULL,
            end_ts TEXT NOT NULL,
            stage TEXT NOT NULL
          )''');
          await db.insert('health_samples', {
            'type': 'heart_rate',
            'timestamp': '2026-08-10T22:30:00.000',
            'value': 60.0,
          });
          await db.insert('settings',
              {'key': 'health_sync.heart_rate', 'value': '2026-08-10T22:30:00.000Z'});
          await db.insert('settings', {'key': 'userName', 'value': 'Devasy'});
        },
      );
      await v2.close();

      final upgraded = SqliteStorageService(databasePathOverride: path);
      await upgraded.init();

      // The cache is rebuilt on the new shape...
      final cols = await rawQuery(upgraded, 'PRAGMA table_info(health_samples)');
      expect(cols.map((c) => c['name']), contains('utc_ts'));
      final samples = await rawQuery(upgraded, 'SELECT COUNT(*) AS n FROM health_samples');
      expect(samples.first['n'], 0);

      // ...the watermarks are cleared so the next sync re-pulls the window...
      final watermarks = await rawQuery(
        upgraded,
        "SELECT COUNT(*) AS n FROM settings WHERE key LIKE 'health_sync.%'",
      );
      expect(watermarks.first['n'], 0);

      // ...and unrelated settings are left alone.
      expect(await upgraded.getSetting('userName'), 'Devasy');

      await upgraded.close();
      await File(path).delete();
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

    test('preserves set order with 11+ sets (regression: synthetic ids like '
        '"_10" sort before "_2" lexicographically, so ordering must use '
        'rowid, not id)', () async {
      final weights = [for (var i = 0; i < 11; i++) 40.0 + i];
      final session = WorkoutSession(
        id: 's_order',
        date: DateTime(2026, 7, 15),
        duration: 60,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [for (final w in weights) WorkoutSet(weight: w, reps: 5)],
          ),
        ],
      );

      await storage.saveWorkoutSession(session);
      final fetched = await storage.getWorkoutSession('s_order');

      expect(
        fetched!.exercises.single.sets.map((s) => s.weight).toList(),
        weights,
      );
    });

    test('preserves exercise-log order with 11+ exercises in one session',
        () async {
      final session = WorkoutSession(
        id: 's_order_logs',
        date: DateTime(2026, 7, 16),
        duration: 90,
        exercises: [
          for (var i = 0; i < 11; i++)
            ExerciseLog(
              exerciseId: 'exercise_$i',
              sets: [WorkoutSet(weight: 10.0 + i, reps: 5)],
            ),
        ],
      );

      await storage.saveWorkoutSession(session);
      final fetched = await storage.getWorkoutSession('s_order_logs');

      expect(
        fetched!.exercises.map((e) => e.exerciseId).toList(),
        [for (var i = 0; i < 11; i++) 'exercise_$i'],
      );
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

    test('saveWorkoutSession + getWorkoutSession round-trips bodyWeightAtLog', () async {
      final session = WorkoutSession(
        id: 's4',
        date: DateTime(2026, 7, 5),
        duration: 25,
        exercises: [
          ExerciseLog(
            exerciseId: 'assisted_pullup',
            sets: [WorkoutSet(weight: 20, reps: 8, bodyWeightAtLog: 75.5)],
          ),
        ],
      );
      await storage.saveWorkoutSession(session);
      final fetched = await storage.getWorkoutSession('s4');
      expect(fetched!.exercises.single.sets.single.bodyWeightAtLog, 75.5);
    });
  });

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
}
