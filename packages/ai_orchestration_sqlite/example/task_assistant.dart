import 'dart:io';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_sqlite/ai_orchestration_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TaskModel implements ModelProvider {
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (request.messages.last.role == 'user') {
      yield ModelToolCall(ToolCall(id: 'tasks-1', name: 'list_open_tasks'));
      yield ModelFinished(ModelFinishReason.toolCalls);
    } else {
      final rows = request.messages.last.result!['rows']! as List<Object?>;
      yield ModelText('You have ${rows.length} open tasks.');
      yield ModelFinished(ModelFinishReason.stop);
    }
  }
}

Future<void> main() async {
  sqfliteFfiInit();
  final directory = await Directory.systemTemp.createTemp('task_assistant_');
  final path = '${directory.path}/tasks.db';
  final database = await databaseFactoryFfi.openDatabase(path);
  NamedSqlReadTool? query;
  try {
    await database.execute(
      'CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT, done INTEGER)',
    );
    await database.insert('tasks', {
      'title': 'Ship the reusable engine',
      'done': 0,
    });
    final store = SqliteCheckpointStore(database);
    await store.initialize();
    query = await NamedSqlReadTool.open(
      factory: databaseFactoryFfi,
      databasePath: path,
      definition: ToolDefinition(
        name: 'list_open_tasks',
        description: 'List unfinished tasks.',
        arguments: ValueSchema.object(),
        replaySafe: true,
      ),
      sql: 'SELECT id, title FROM tasks WHERE done = 0 ORDER BY id',
    );
    final workflow = chatWorkflow(
      id: 'task-assistant',
      modelId: 'demo',
      systemPrompt: 'Use the task query before answering.',
      tools: ToolRegistry([query]),
    );
    final handle = await AgentRuntime(store: store, model: TaskModel()).start(
      workflow: workflow,
      threadId: 'tasks',
      input: {'text': 'What do I need to finish?'},
    );
    final result = await handle.done;
    print(const ChatStateCodec().decode(result.state).messages.last.text);
  } finally {
    await query?.close();
    await database.close();
    await directory.delete(recursive: true);
  }
}
