import 'dart:convert';
import 'dart:io';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_sqlite/ai_orchestration_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

class _Codec implements StateCodec<int> {
  @override
  int decode(JsonMap json) => json['value']! as int;
  @override
  JsonMap encode(int state) => {'value': state};
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late Database database;
  late SqliteCheckpointStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orchestration_test_');
    path = '${directory.path}/app.db';
    database = await databaseFactoryFfi.openDatabase(path);
    store = SqliteCheckpointStore(database);
    await store.initialize();
  });
  tearDown(() async {
    if (database.isOpen) await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'cancellation during a local mutation rolls back both write and receipt',
    () async {
      await database.execute(
        'CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT)',
      );
      final cancellation = CancellationToken();
      await expectLater(
        store.executeOnce(
          operationId: 'cancelled',
          arguments: {'title': 'draft'},
          cancellation: cancellation,
          action: (transaction) async {
            await transaction.insert('tasks', {'title': 'draft'});
            cancellation.cancel();
            return {'saved': true};
          },
        ),
        throwsA(isA<OrchestrationException>()),
      );
      expect(await database.query('tasks'), isEmpty);
      final result = await store.executeOnce(
        operationId: 'cancelled',
        arguments: {'title': 'draft'},
        action: (transaction) async => {
          'id': await transaction.insert('tasks', {'title': 'draft'}),
        },
      );
      expect(result['id'], isNotNull);
      expect(await database.query('tasks'), hasLength(1));
    },
  );

  test(
    'suspended workflow resumes from a reopened SQLite connection',
    () async {
      final workflow = Workflow(
        id: 'expense',
        entryNode: 'confirm',
        codec: _Codec(),
        initialize: (_, _) => 0,
        nodes: {
          'confirm': WorkflowNode<int>(
            destinations: {'apply'},
            execute: (_, _) => NodeResult(
              update: (value) => value + 1,
              transition: SuspendAt(
                'apply',
                InputRequest(responseSchema: ValueSchema.boolean()),
              ),
            ),
          ),
          'apply': WorkflowNode<int>(
            execute: (context, _) {
              expect(context.resumeInput!.value, true);
              return NodeResult(
                update: (value) => value + 1,
                transition: const Complete(),
              );
            },
          ),
        },
      );
      final paused = await (await AgentRuntime(
        store: store,
      ).start(workflow: workflow, threadId: 'thread')).done;
      await database.close();
      database = await databaseFactoryFfi.openDatabase(path);
      final reopened = SqliteCheckpointStore(database);
      await reopened.initialize();
      final loaded = (await reopened.load('thread'))!;
      expect(jsonEncode(loaded.toJson()), jsonEncode(paused.toJson()));
      final resumed = await (await AgentRuntime(store: reopened).resume(
        workflow: workflow,
        threadId: 'thread',
        runId: loaded.runId,
        interruptId: loaded.interrupt!.id,
        expectedRevision: loaded.revision,
        value: true,
      )).done;
      expect(resumed.status, RunStatus.completed);
      expect(resumed.state['value'], 2);
    },
  );

  test('competing SQLite stores reject stale checkpoint writes', () async {
    final checkpoint = RunCheckpoint(
      threadId: 'thread',
      runId: 'run',
      workflowId: 'expense',
      workflowVersion: 1,
      revision: 0,
      nextNode: 'apply',
      status: RunStatus.running,
      state: {'value': 1},
      limits: const RunLimits().toJson(),
    );
    await store.save(checkpoint, expectedRevision: null);
    final second = SqliteCheckpointStore(database);
    await expectLater(
      second.save(checkpoint, expectedRevision: null),
      throwsA(isA<CheckpointConflict>()),
    );
    await store.save(checkpoint.update({'revision': 1}), expectedRevision: 0);
    await expectLater(
      second.save(checkpoint.update({'revision': 1}), expectedRevision: 0),
      throwsA(isA<CheckpointConflict>()),
    );
  });

  test(
    'operation receipt and application mutation commit atomically and deduplicate',
    () async {
      await database.execute(
        'CREATE TABLE expenses (id INTEGER PRIMARY KEY, amount INTEGER NOT NULL)',
      );
      var writes = 0;
      Future<JsonMap> save() => store.executeOnce(
        operationId: 'record-1',
        arguments: {'amount': 25},
        action: (transaction) async {
          writes++;
          final id = await transaction.insert('expenses', {'amount': 25});
          return {'id': id};
        },
      );
      final first = await save();
      final second = await save();
      expect(first, second);
      expect(writes, 1);
      expect(await database.query('expenses'), hasLength(1));
      await expectLater(
        store.executeOnce(
          operationId: 'record-1',
          arguments: {'amount': 99},
          action: (_) async => {},
        ),
        throwsA(isA<OrchestrationException>()),
      );
      await expectLater(
        store.executeOnce(
          operationId: 'record-2',
          arguments: {'amount': 10},
          action: (transaction) async {
            await transaction.insert('expenses', {'amount': 10});
            throw StateError('Fail before receipt');
          },
        ),
        throwsStateError,
      );
      expect(await database.query('expenses'), hasLength(1));
      final retried = await store.executeOnce(
        operationId: 'record-2',
        arguments: {'amount': 10},
        action: (transaction) async => {
          'id': await transaction.insert('expenses', {'amount': 10}),
        },
      );
      expect(retried['id'], isNotNull);
      expect(await database.query('expenses'), hasLength(2));
    },
  );

  test(
    'different namespaces coexist and newer schema versions are not overwritten',
    () async {
      final second = SqliteCheckpointStore(database, namespace: 'second_agent');
      await second.initialize();
      await database.rawUpdate(
        'UPDATE second_agent_meta SET version = 2 WHERE id = 1',
      );
      await expectLater(
        second.initialize(),
        throwsA(isA<OrchestrationException>()),
      );
      expect(
        (await database.rawQuery(
          'SELECT version FROM second_agent_meta',
        )).single['version'],
        2,
      );
      expect(
        () => SqliteCheckpointStore(database, namespace: 'unsafe;DROP'),
        throwsArgumentError,
      );
    },
  );

  test(
    'named SQL read binds values, caps rows and keeps app connection open',
    () async {
      await database.execute(
        'CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT, done INTEGER)',
      );
      for (var i = 0; i < 4; i++) {
        await database.insert('tasks', {'title': 'task $i', 'done': 0});
      }
      final definition = ToolDefinition(
        name: 'open_tasks',
        description: 'Open tasks',
        replaySafe: true,
        arguments: ValueSchema.object(
          properties: {'title': ValueSchema.string()},
          required: ['title'],
        ),
      );
      final tool = await NamedSqlReadTool.open(
        factory: databaseFactoryFfi,
        databasePath: path,
        definition: definition,
        sql: 'SELECT id, title FROM tasks WHERE title LIKE ? ORDER BY id',
        parameterNames: ['title'],
        maxRows: 2,
      );
      final result =
          await tool.execute(_context('open_tasks', {'title': '%'}))
              as ToolSuccess;
      expect(result.data['row_count'], 2);
      expect(result.data['truncated'], true);
      expect(result.data['supports_statement_cancellation'], false);
      final injected =
          await tool.execute(_context('open_tasks', {'title': "' OR 1=1 --"}))
              as ToolSuccess;
      expect(injected.data['row_count'], 0);
      await tool.close();
      expect(database.isOpen, true);
      expect(await database.query('tasks'), hasLength(4));
    },
  );

  test(
    'read tool enforces bytes and catalog only exposes host-provided metadata',
    () async {
      final tool = await NamedSqlReadTool.open(
        factory: databaseFactoryFfi,
        databasePath: path,
        definition: ToolDefinition(
          name: 'preview',
          description: 'Preview',
          arguments: ValueSchema.object(),
        ),
        sql: "SELECT 'a long result value' AS content",
        maxResultBytes: 5,
      );
      try {
        final result =
            await tool.execute(_context('preview', {})) as ToolSuccess;
        expect(result.data['row_count'], 0);
        expect(result.data['truncated'], true);
        final catalog = SchemaCatalogTool({
          'relations': [
            {
              'name': 'tasks',
              'columns': ['title'],
            },
          ],
        });
        expect(
          (catalog.execute(_context('describe_schema', {})) as ToolSuccess).data
              .toString(),
          isNot(contains('ai_orchestration_runs')),
        );
      } finally {
        await tool.close();
      }
    },
  );

  test('read tool rejects arbitrary DML at registration', () async {
    await expectLater(
      NamedSqlReadTool.open(
        factory: databaseFactoryFfi,
        databasePath: path,
        definition: ToolDefinition(
          name: 'bad',
          description: 'Bad',
          arguments: ValueSchema.object(),
        ),
        sql: 'DELETE FROM tasks',
      ),
      throwsArgumentError,
    );
  });
}

ToolContext _context(String name, JsonMap arguments) => ToolContext(
  threadId: 'thread',
  runId: 'run',
  call: ToolCall(id: 'call', name: name, arguments: arguments),
  cancellation: CancellationToken(),
  deadline: DateTime.now().toUtc().add(const Duration(minutes: 1)),
);
