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

  test('trailing line comment does not break the LIMIT wrapper', () async {
    final service = SqlQueryService(dbPath);
    final result = await service.runQuery('SELECT * FROM widgets -- get all');
    expect(result['error'], isNull);
    expect(result['row_count'], 2);
  });
}
