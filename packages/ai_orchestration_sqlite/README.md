# ai_orchestration_sqlite

SQLite bindings for `ai_orchestration`, using `sqflite_common` contracts. Flutter apps can supply their sqflite database/factory; desktop tests and examples use `sqflite_common_ffi`. This package has no Flutter or application-domain dependency.

## Durable checkpoints

```dart
final store = SqliteCheckpointStore(database, namespace: 'assistant');
await store.initialize();
final runtime = AgentRuntime(store: store, model: provider);
```

The host owns and closes the connection. The store owns only its namespaced metadata, checkpoint and operation tables. Initialization is transactional/idempotent, rejects an unsupported schema version, and leaves the host's migration version alone. Checkpoints use an atomic revision check. Reopen the database, rebuild the same workflow/version, inspect the thread and resume its pending interrupt.

## Local write deduplication

Inside an application write tool:

```dart
final result = await store.executeOnce(
  operationId: context.operationId,
  arguments: context.call.toJson(),
  cancellation: context.cancellation,
  deadline: context.deadline,
  action: (transaction) async {
    final id = await transaction.insert('expenses', {'amount': 25});
    return {'id': id};
  },
);
return ToolSuccess(result);
```

The mutation and receipt use the **same SQLite transaction**. A repeated operation ID returns its recorded result; reuse with different arguments fails. Exceptions, invalid results and cancellation/deadline checks roll back the local transaction. Pass the supplied transaction through application repositories: using a separate application connection does not provide atomic deduplication and can deadlock if it re-enters this transaction's connection.

This guarantee does not cover external API calls, other databases, or a newly generated operation ID. A checkpoint plus a separate remote write is not an exactly-once transaction. The host still reconciles a crashed side-effecting node before recovery.

The example fingerprints the tool name and arguments deliberately. An operation ID is scoped to the run, model invocation and native call ID, so reusing it for a different tool must conflict even if the argument values match. Removing the tool name could incorrectly reuse a different mutation's receipt.

## Reading application data

`SchemaCatalogTool` exposes only host-selected metadata: tables/views, columns, units, relationships and available query tools. It does not enumerate all tables or automatically expose checkpoint/settings data.

`NamedSqlReadTool.open` takes a trusted, application-owned SELECT template and declared parameter names. It opens an independent read-only connection with `singleInstance: false`; closing it does not close the host's read/write connection. Model arguments are bound as scalar values and cannot replace SQL text. Model-written SQL and arbitrary DML are deliberately outside this slice.

Results identify the query, returned row count, rows and truncation. `maxRows` is capped at 500. `maxResultBytes` bounds the encoded rows payload, excluding envelope metadata; blobs are represented as base64 objects. These result limits do **not** bound native database work or allocations for a single large row. The connection does not support interrupting native statements, and the tool reports `supports_statement_cancellation: false`. Keep registered queries reviewed and bounded; runtime cancellation can stop awaiting a query but cannot terminate a native SQLite scan.

The host chooses whether application data and orchestration data share a database. In-memory SQLite databases cannot be independently reopened as the same data source; use a file database for these read tools.

Run `dart run example/task_assistant.dart` for a complete second-domain consumer with a real SQLite query and persistent checkpoints. Its model is scripted; live providers are separate adapters.
