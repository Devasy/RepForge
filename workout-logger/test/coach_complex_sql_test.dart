import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/services/ai/sql_query_service.dart';

void main() {
  late Database db;
  late String path;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    path =
        '${Directory.systemTemp.path}/coach-complex-${DateTime.now().microsecondsSinceEpoch}.db';
    db = await openDatabase(path);
    await db.execute(
      'CREATE TABLE sessions(id TEXT, date TEXT, routine_id TEXT)',
    );
    await db.execute(
      'CREATE TABLE exercise_logs(id TEXT, session_id TEXT, exercise_id TEXT, handle TEXT)',
    );
    await db.execute(
      'CREATE TABLE sets(exercise_log_id TEXT, weight REAL, reps INTEGER)',
    );
    await db.execute('CREATE TABLE exercises(id TEXT, name TEXT)');
    await db.execute(
      'CREATE TABLE exercise_muscle_activations(exercise_id TEXT, muscle_group_id TEXT)',
    );
    await db.execute(
      'CREATE TABLE sleep_sessions(start_ts TEXT, deep_min REAL)',
    );
    for (final period in ['early', 'recent']) {
      final date = period == 'early' ? '2026-06-01' : '2026-11-01';
      await db.insert('sessions', {
        'id': period,
        'date': date,
        'routine_id': 'back-biceps',
      });
      await db.insert('exercise_logs', {
        'id': period,
        'session_id': period,
        'exercise_id': 'incline',
        'handle': 'barbell',
      });
    }
    await db.insert('sets', {
      'exercise_log_id': 'early',
      'weight': 60,
      'reps': 8,
    });
    // More tonnage but a lighter top set: these are different signals.
    await db.insert('sets', {
      'exercise_log_id': 'recent',
      'weight': 50,
      'reps': 12,
    });
    await db.insert('sets', {
      'exercise_log_id': 'recent',
      'weight': 40,
      'reps': 15,
    });
    for (final group in ['chest', 'upper_chest']) {
      await db.insert('exercise_muscle_activations', {
        'exercise_id': 'incline',
        'muscle_group_id': group,
      });
    }
  });
  tearDown(() async {
    await db.close();
    await File(path).delete();
  });

  test(
    'period comparison preserves built-in logs and does not multiply overlapping activations',
    () async {
      final result = await SqlQueryService(path).runQuery('''
SELECT s.date AS session_date, l.exercise_id, e.name,
       SUM(t.weight * t.reps) AS tonnage, MAX(t.weight) AS maximum_load
FROM sessions s JOIN exercise_logs l ON l.session_id = s.id
JOIN sets t ON t.exercise_log_id = l.id
LEFT JOIN exercises e ON e.id = l.exercise_id
WHERE s.date BETWEEN '2026-05-07' AND '2026-11-06'
AND EXISTS (SELECT 1 FROM exercise_muscle_activations a
 WHERE a.exercise_id = l.exercise_id AND a.muscle_group_id IN ('chest', 'upper_chest'))
GROUP BY s.id, s.date, l.exercise_id, e.name ORDER BY s.date
''');
      final rows = result['rows'] as List;
      expect(rows, hasLength(2));
      expect(rows[0]['tonnage'], 480);
      expect(rows[1]['tonnage'], 1200);
      expect(rows[1]['maximum_load'], 50);
      expect(rows[1]['name'], isNull); // Built-in has no override row.
      expect(result['truncated'], false);
    },
  );

  test(
    'exact PR verification returns observed pairs instead of independent maxima',
    () async {
      final result = await SqlQueryService(path).runQuery('''
SELECT s.date AS session_date, t.weight, t.reps FROM sessions s
JOIN exercise_logs l ON l.session_id = s.id JOIN sets t ON t.exercise_log_id = l.id
WHERE l.exercise_id = 'incline' ORDER BY t.weight DESC, t.reps DESC LIMIT 1
''');
      expect((result['rows'] as List).single['weight'], 60);
      expect((result['rows'] as List).single['reps'], 8);
    },
  );

  test(
    'sleep coverage stays missing rather than becoming zero or proving recovery',
    () async {
      final result = await SqlQueryService(path).runQuery('''
SELECT COUNT(DISTINCT s.id) AS training_sessions,
COUNT(DISTINCT h.start_ts) AS matched_sleep_nights, AVG(h.deep_min) AS mean_deep_sleep
FROM sessions s LEFT JOIN sleep_sessions h ON date(h.start_ts) = date(s.date)
WHERE s.date >= '2026-05-07'
''');
      final row = (result['rows'] as List).single;
      expect(row['training_sessions'], 2);
      expect(row['matched_sleep_nights'], 0);
      expect(row['mean_deep_sleep'], isNull);
    },
  );

  test(
    'routine-specific detailed query preserves the requested window and handle',
    () async {
      final result = await SqlQueryService(path).runQuery('''
WITH observations AS (
 SELECT s.date AS session_date, l.handle, t.weight, t.reps
 FROM sessions s JOIN exercise_logs l ON l.session_id = s.id
 JOIN sets t ON t.exercise_log_id = l.id
 WHERE s.routine_id = 'back-biceps' AND s.date >= '2026-10-01'
)
SELECT handle, COUNT(*) AS sets_logged, SUM(weight * reps) AS tonnage
FROM observations GROUP BY handle
''');
      expect((result['rows'] as List).single['sets_logged'], 2);
      expect((result['rows'] as List).single['tonnage'], 1200);
    },
  );
}
