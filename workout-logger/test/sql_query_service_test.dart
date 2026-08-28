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
      await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
      await db.insert('settings', {'key': 'geminiApiKey', 'value': 'super-secret-key'});
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

  test('rejects queries reading the settings table', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM settings');
    expect(result['error'], contains('restricted table'));
  });

  test('rejects queries reading sqlite_master', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM sqlite_master');
    expect(result['error'], contains('restricted table'));
  });

  test('rejects queries reading sqlite_temp_schema', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM sqlite_temp_schema');
    expect(result['error'], contains('restricted table'));
  });

  test('rejects queries reading sqlite_dbpage', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM sqlite_dbpage');
    expect(result['error'], contains('restricted table'));
  });

  test('rejects queries reading pragma_table_list', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM pragma_table_list');
    expect(result['error'], contains('restricted table'));
  });

  // The query planner's stat tables are on the denylist but were not otherwise
  // exercised, so a typo there could silently reopen SQLite metadata access.
  for (final table in const [
    'sqlite_stat1',
    'sqlite_stat2',
    'sqlite_stat3',
    'sqlite_stat4',
  ]) {
    test('rejects queries reading $table', () async {
      final service = SqlQueryService(dbPath);
      final result = await service.runQuery('SELECT * FROM $table');
      expect(result['error'], contains('restricted table'));
    });
  }

  test('trailing line comment does not break the LIMIT wrapper', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM widgets -- get all');
    expect(result['error'], isNull);
    expect(result['row_count'], 2);
  });

  test('does not close the app\'s shared connection to the same path', () async {
    final service = SqlQueryService(dbPath);

    final first = await service.runQuery('SELECT * FROM widgets ORDER BY id');
    expect(first['error'], isNull);

    // Regression: opening a read-only connection at the same path as an
    // already-open shared connection returns that shared instance unless
    // singleInstance: false is passed. Closing it after the first query
    // would then break every later access to the app's real connection —
    // including seedDb here, standing in for the app's live database.
    final rows = await seedDb.rawQuery('SELECT * FROM widgets ORDER BY id');
    expect(rows.length, 2);

    final second = await service.runQuery('SELECT * FROM widgets ORDER BY id');
    expect(second['error'], isNull);
    expect(second['row_count'], 2);
  });

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
}
