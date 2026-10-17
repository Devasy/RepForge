# ai_orchestration

A pure Dart execution core for AI workflows. A consumer supplies a model provider, registered tools, a workflow, a checkpoint store and an authorization policy. There are no Flutter, provider-SDK, SQL-driver or RepForge imports.

## Smallest model/tool workflow

```dart
final workflow = chatWorkflow(
  id: 'my-assistant',
  version: 1,
  modelId: 'the-model-selected-by-the-host',
  systemPrompt: 'Use the registered tools before answering about app data.',
  tools: ToolRegistry(appTools),
);
final runtime = AgentRuntime(store: checkpointStore, model: modelProvider);
final run = await runtime.start(
  workflow: workflow,
  threadId: conversationId,
  input: {'text': userMessage},
);
final subscription = run.events.listen(renderEvent);
final snapshot = await run.done;
await subscription.cancel();
```

`ModelProvider.stream` makes one model invocation. Emit `ModelText`, complete `ModelToolCall` objects with native IDs, and exactly one `ModelFinished` event. Throw for transport failures. A missing, blocked or length-limited finish cannot become a successful assistant message. The core never retries an entire run automatically. Requests carry model ID, prompt, messages and advertised tool definitions; provider adapters implement capability checks and wire conversion. Attachment and provider-continuation maps are opaque JSON contracts agreed with the selected adapter, not an assertion of interchangeability between providers.

`chatWorkflow` retains prior messages and attachments, processes one tool call per checkpoint, completes input requests under their original call IDs and upserts artifacts by ID. It stops at input/approval requests before executing later tools from the same model response. Conversation size is bounded by `maxMessages`; compaction is explicitly host-owned.

## Application workflows

Use `Workflow<S>`, an immutable application state type and `StateCodec<S>` for domain-specific graphs. Each `WorkflowNode<S>` returns a `NodeResult<S>` containing a typed update and a `ContinueAt`, `SuspendAt` or `Complete` transition. Only the runtime applies the update. All possible destinations must be declared and present in the graph.

The codec converts state to finite JSON. The checkpoint freezes that JSON; connections, credentials, services and widgets belong outside state. The host must supply immutable decoded state. Change `Workflow.version` when state or graph compatibility changes. Restoring a different version fails explicitly; automatic migration is not implemented.

## Resume and lifecycle

```dart
final paused = await runtime.inspect(conversationId);
final resumed = await runtime.resume(
  workflow: workflow,
  threadId: paused!.threadId,
  runId: paused.runId,
  interruptId: paused.interrupt!.id,
  expectedRevision: paused.revision,
  value: userResponse,
);
final result = await resumed.done;
```

The persisted interrupt carries its payload, response schema and originating call ID. Resume checks workflow version, thread/run/interrupt identity, response schema and checkpoint revision before claiming the continuation. Repeated interrupts work through fresh runtime instances. Invalid or duplicate responses cannot consume a pending question or execute an approved write twice.

`RunHandle.events` is a transient broadcast subscription. Detaching does not cancel execution. Use `attach(threadId)` for a run active in this runtime, and `inspect` to reconstruct persisted state after recreation. Await `done` to distinguish completed, suspended, failed, cancelled and exhausted outcomes. Storage failures surface as errors from `done`; they are not reported as successful execution. Event sequence numbers are scoped to a run and checkpointed at boundaries; token events are not a replay log. Artifacts and interrupts are reconstructed from state/checkpoints.

Cancel active work through `runtime.cancel(threadId, expectedRevision: ...)`. Nodes, providers and tools receive a cancellation token and deadline. Timeouts stop awaiting work and prevent late state commits; they cannot preempt synchronous Dart code or native/external side effects. Provider implementations must stop transport on cancellation, and write tools must cooperate with the token. Checkpoint I/O uses the store driver's own I/O guarantees; an unresponsive store cannot be made durably terminal by a runtime timeout.

`recover` is an explicit host operation for a persisted running node marked `replaySafe`. First ensure the previous executor has stopped. This API is not a distributed lease. Side-effecting tool nodes cannot be recovered automatically: the application must reconcile uncertain work. `MemoryCheckpointStore` is for tests/examples; use a persistent store for process recreation. Multiple coordinators use revision checks, but cross-process ownership, worker leases and distributed execution are outside v1.

New turns on running or suspended threads are rejected. A new chat turn after a terminal failure marks any unresolved prior calls as having unknown outcomes. This maintains protocol pairing without claiming that an external operation completed or failed. The host must reconcile such actions; no mutation is automatically replayed.

## Tools, policies and schemas

An `AgentTool` advertises an immutable `ToolDefinition` and receives `ToolContext`. Arguments are validated before policy or execution. Duplicate tool names and unavailable calls are rejected. The default policy allows reads and denies writes. A host policy can allow a clearly requested operation, deny it, or require approval. Approval is bound to the pending call and its arguments, rechecked against the current policy, and persisted before execution.

Tools return `ToolSuccess` with JSON data and optional artifacts, or `ToolNeedsInput` with a generic `InputRequest`. Input requests describe data, not Flutter widgets. The `tool_approval` request kind is reserved for authorization. Render artifacts through host-registered handlers using their type/version; the core imposes no chart or UI framework.

`ValueSchema` supports types, enum, object properties/required/additionalProperties, array items/minItems/maxItems and numeric minimum/maximum. Unsupported keywords fail during registration rather than being silently ignored. It is a bounded vocabulary, not a complete JSON Schema implementation.

Tool failures are explicit run failures in this first version. Application-specific repair/error-to-model policies can be implemented as custom nodes. There are no automatic mutation retries. `ToolContext.operationId` scopes a receipt to thread, run, model invocation and native call ID. Native IDs may repeat across different model invocations without aliasing receipts. Custom nodes invoking tools outside model passes must use distinct call IDs for distinct logical operations.

Run limits count node steps, model requests and tool executions independently. Active execution time accumulates across resume; time waiting for user input is excluded. Limit exhaustion is a separate outcome. Limits are persisted with the run, so recreating the runtime cannot reset them.

See `example/expense_agent.dart` for a complete runnable consumer and the sibling SQLite package for durable storage.
