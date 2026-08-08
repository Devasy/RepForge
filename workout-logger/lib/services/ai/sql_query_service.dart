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

  static const _forbiddenIdentifiers = [
    'SETTINGS',
    'SQLITE_MASTER',
    'SQLITE_TEMP_MASTER',
    'SQLITE_SCHEMA',
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
    for (final id in _forbiddenIdentifiers) {
      if (RegExp('\\b$id\\b').hasMatch(upper)) {
        throw SqlValidationException('Query references a restricted table: $id');
      }
    }
    if (upper.contains('PRAGMA_')) {
      throw SqlValidationException('Query references a restricted table: PRAGMA_*');
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
      final rows = await db.rawQuery(
        'SELECT * FROM (\n$safeQuery\n) LIMIT ?',
        [cappedLimit],
      );
      return {'row_count': rows.length, 'rows': rows};
    } catch (e) {
      return {'error': 'Query failed: $e'};
    } finally {
      await db?.close();
    }
  }
}
