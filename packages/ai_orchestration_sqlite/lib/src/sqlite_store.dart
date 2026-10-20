import 'dart:convert';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// The host owns the connection, its lifecycle, and application migrations.
class SqliteCheckpointStore implements CheckpointStore {
  final Database database;
  final String namespace;
  SqliteCheckpointStore(this.database, {this.namespace = 'ai_orchestration'}) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,47}$').hasMatch(namespace)) {
      throw ArgumentError('Use a short lowercase SQL namespace.');
    }
  }
  String get _runs => '${namespace}_runs';
  String get _operations => '${namespace}_operations';

  Future<void> initialize() async {
    await database.transaction((transaction) async {
      await transaction.execute(
        'CREATE TABLE IF NOT EXISTS ${namespace}_meta '
        '(id INTEGER PRIMARY KEY CHECK (id = 1), version INTEGER NOT NULL)',
      );
      await transaction.rawInsert(
        'INSERT OR IGNORE INTO ${namespace}_meta (id, version) VALUES (1, 1)',
      );
      final meta = await transaction.rawQuery(
        'SELECT version FROM ${namespace}_meta WHERE id = 1',
      );
      if (meta.single['version'] != 1) {
        throw const OrchestrationException(
          'store_version',
          'Unsupported orchestration schema version.',
        );
      }
      await transaction.execute(
        'CREATE TABLE IF NOT EXISTS $_runs '
        '(thread_id TEXT PRIMARY KEY, revision INTEGER NOT NULL, checkpoint TEXT NOT NULL)',
      );
      await transaction.execute(
        'CREATE TABLE IF NOT EXISTS $_operations '
        '(operation_id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, result TEXT NOT NULL)',
      );
    });
  }

  @override
  Future<RunCheckpoint?> load(String threadId) async {
    final rows = await database.query(
      _runs,
      columns: ['checkpoint'],
      where: 'thread_id = ?',
      whereArgs: [threadId],
    );
    return rows.isEmpty
        ? null
        : RunCheckpoint.fromJson(
            jsonObject(jsonDecode(rows.single['checkpoint']! as String)),
          );
  }

  @override
  Future<void> save(
    RunCheckpoint checkpoint, {
    required int? expectedRevision,
  }) async {
    if (checkpoint.revision != (expectedRevision ?? -1) + 1) {
      throw const CheckpointConflict();
    }
    final values = {
      'thread_id': checkpoint.threadId,
      'revision': checkpoint.revision,
      'checkpoint': jsonEncode(checkpoint.toJson()),
    };
    if (expectedRevision == null) {
      try {
        await database.insert(_runs, values);
      } on DatabaseException catch (error) {
        if (error.isUniqueConstraintError()) throw const CheckpointConflict();
        rethrow;
      }
    } else {
      final updated = await database.update(
        _runs,
        values,
        where: 'thread_id = ? AND revision = ?',
        whereArgs: [checkpoint.threadId, expectedRevision],
      );
      if (updated != 1) throw const CheckpointConflict();
    }
  }

  /// Deduplicates only writes performed through this same transaction.
  Future<JsonMap> executeOnce({
    required String operationId,
    required JsonMap arguments,
    CancellationToken? cancellation,
    DateTime? deadline,
    required Future<JsonMap> Function(DatabaseExecutor transaction) action,
  }) async {
    if (operationId.isEmpty) throw ArgumentError('Operation ID is required.');
    final fingerprint = canonicalJson(arguments);
    void check() {
      cancellation?.check();
      if (deadline != null && !DateTime.now().toUtc().isBefore(deadline)) {
        throw const OrchestrationException(
          'exhausted',
          'Database operation deadline exceeded.',
        );
      }
    }

    check();
    return database.transaction((transaction) async {
      check();
      final existing = await transaction.query(
        _operations,
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
      if (existing.isNotEmpty) {
        if (existing.single['fingerprint'] != fingerprint) {
          throw const OrchestrationException(
            'operation_conflict',
            'Operation ID was reused with different arguments.',
          );
        }
        return jsonObject(jsonDecode(existing.single['result']! as String));
      }
      final result = jsonObject(await action(transaction));
      check();
      await transaction.insert(_operations, {
        'operation_id': operationId,
        'fingerprint': fingerprint,
        'result': jsonEncode(result),
      });
      return result;
    });
  }
}
