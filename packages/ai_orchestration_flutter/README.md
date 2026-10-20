# ai_orchestration_flutter

An optional Flutter bridge for `ai_orchestration`. It exposes run state through `ValueListenable`/`ChangeNotifier`, delegates all execution to the Dart core, and lets the host choose its screens and renderers. There are no database drivers, provider SDKs, application models, or state-management package dependencies.

## Controller

```dart
final controller = AgentController.chat(
  runtime: runtime,
  workflow: chatWorkflow,
  threadId: conversationId,
);
await controller.restore();
final accepted = await controller.start(input: {'text': userMessage});
if (accepted) {
  final segment = await controller.completion;
}
```

Use `AgentController<S>` for any typed `Workflow<S>`. Supply `artifactsOf: (state) => state.artifacts` if custom workflow state persists artifacts. The chat convenience supplies that projection for `ChatState`.

`start`, `restore`, `submitInput`, `cancel`, and `recover` return whether the command was accepted. They do not wait for the entire workflow. `completion` is the current execution segment's future; it ends on an interrupt as well as a terminal result, and changes after resume. Runtime failures appear in state; a checkpoint-store failure also remains an error on `completion`. Commands after controller disposal throw a lifecycle error.

The immutable `AgentViewState<S>` exposes decoded workflow `data`, the latest checkpoint/status, transient text, active tools, artifacts, pending input, command progress and safe failures. Render committed content from `data` and append `streamingText` only for the current checkpoint interval: streamed text clears when it has been committed, avoiding duplicate display. Collections are read-only. `error.code` can be mapped to the host's localized copy.

```dart
AgentRunBuilder<ChatState>(
  controller: controller,
  builder: (context, state) => YourChatView(state: state),
)
```

The controller can also be observed directly by Provider, Riverpod, Bloc integrations or `ValueListenableBuilder`; none is required by the package. The host owns the controller and its disposal.

## Attachment and lifecycle

- `restore()` loads a checkpoint and attaches if the runtime still owns an active handle. It validates workflow identity/version before decoding.
- `detach()` and `dispose()` unsubscribe the view. They never cancel execution. A lightweight per-handle observer continues tracking progress until that segment ends, then releases its stream subscription/notifier resources.
- A controller reopened against that runtime can recover observed in-flight text and activity. For a run started outside the bridge before any observer attached, only checkpoints and subsequent events are available; past token events are not replayed.
- Process recreation restores committed state and pending inputs through the runtime's `CheckpointStore`. The bridge has no persistence implementation of its own.
- A saved `running` checkpoint without a live handle reports `needsRecovery`. Recovery is explicit: first establish that the previous executor stopped and reconcile side effects. The bridge does not automatically replay a potentially mutating node.
- `cancel()` explicitly cancels the known run. It refuses to cancel a newer run that this controller has not loaded. The host decides whether navigation or app lifecycle changes should invoke it.

`isAttached` describes the controller's live subscription; `hasLiveRun` describes a handle still owned by this runtime. A deliberate detach from a live run is not a recovery condition. Async operations finishing after view disposal cannot reattach or notify that view.

## Input and approval

`PendingAgentInput` includes thread, run, checkpoint revision and interrupt identity. Keep that target with the form that rendered it:

```dart
AgentInputBuilder<ChatState>(
  controller: controller,
  builder: (context, pending, submit, busy) => YourQuestionForm(
    request: pending.request,
    isSubmitting: busy,
    onSubmit: submit,
  ),
)
```

The submit callback captures the original target. An old callback cannot answer a later question or a different thread. Invalid responses leave the pending request intact and expose a validation failure. Core schema validation and authorization remain authoritative.

`AgentApprovalPrompt` is an optional Material helper for boolean `tool_approval` requests. The host must provide the details to review. It has explicit Approve/Decline actions, blocks duplicate taps and keeps an accepted response disabled until the request changes. Labels are configurable for localization. Generic forms remain host-owned; the bridge does not prescribe question layouts or automatically approve anything.

## Artifacts

```dart
final registry = ArtifactRegistry([
  ArtifactRenderer(
    type: 'expense.summary',
    version: 1,
    payloadSchema: ValueSchema.object(
      properties: {'total': ValueSchema.integer()},
      required: ['total'],
    ),
    builder: (context, artifact) => Text('Total: ${artifact.payload['total']}'),
  ),
]);
AgentArtifactView(artifact: artifact, registry: registry);
```

The registry validates type/version and payload before calling a renderer. Duplicate registrations fail. Unknown versions or malformed payloads use a fallback, which the host can replace/localize through `fallbackBuilder`. Exceptions in application renderer code remain application errors. There is no mandatory chart library or A2UI dependency; either can be a host renderer.

## SQL is an ordinary tool

Register a SQLite data tool alongside HTTP tools and domain commands in the workflow's `ToolRegistry`. The controller treats them alike. `SqliteCheckpointStore` is a separate optional runtime-storage backend, not a model-callable tool. The Flutter bridge neither opens connections nor chooses SQL permissions.

## Example and verification

`example/main.dart` demonstrates a controller-owned panel, explicit approval, a custom artifact renderer, and hiding/reopening the panel without losing the pending request. Its model is scripted and its store is in memory, so no credentials are required. The widget smoke test exercises the complete example. Embed that entrypoint in a Flutter runner to launch it; the package does not include generated platform projects.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub --fatal-infos
flutter test --no-pub
```

`retry()` delegates to the runtime's failed-node retry, with the captured checkpoint revision. It preserves budgets and is permitted only for replay-safe failed nodes. The host still chooses whether to offer a retry after earlier side effects.

The sibling Gemini adapter and RepForge app are separate consumers of the bridge and core; this package has no provider or application dependency.
