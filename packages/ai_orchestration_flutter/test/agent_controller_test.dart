import 'dart:async';
import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  test('cancel cannot cross into a new run between checkpoint loads', () async {
    final store = _LoadRaceStore();
    final release = Completer<void>();
    var calls = 0;
    final workflow = Workflow<int>(
      id: 'race',
      entryNode: 'wait',
      codec: IntCodec(),
      initialize: (previous, _) => previous ?? 0,
      nodes: {
        'wait': WorkflowNode(
          execute: (_, _) async {
            if (++calls == 1) {
              await release.future;
              return NodeResult(
                update: (value) => value + 1,
                transition: const Complete(),
              );
            }
            return Completer<NodeResult<int>>().future;
          },
        ),
      },
    );
    final runtime = AgentRuntime(store: store);
    final controller = AgentController(
      runtime: runtime,
      workflow: workflow,
      threadId: 'race',
    );
    addTearDown(controller.dispose);
    await controller.start();
    final original = runtime.attach('race')!;
    late RunHandle newer;
    store.afterLoad = () async {
      store.afterLoad = () async {
        release.complete();
        await original.done;
        newer = await runtime.start(workflow: workflow, threadId: 'race');
      };
    };
    expect(await controller.cancel(), false);
    expect(controller.state.error?.code, 'conflict');
    expect(newer.snapshot.runId, isNot(original.snapshot.runId));
    expect(newer.snapshot.status, RunStatus.running);
    expect(runtime.attach('race'), same(newer));
    await runtime.cancel('race', expectedRevision: newer.snapshot.revision);
  });

  test('cancel retries a checkpoint race only for the same live run', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final store = _LoadRaceStore();
    final workflow = Workflow<int>(
      id: 'race',
      entryNode: 'first',
      codec: IntCodec(),
      initialize: (_, _) => 0,
      nodes: {
        'first': WorkflowNode(
          destinations: {'wait'},
          execute: (_, _) async {
            entered.complete();
            await release.future;
            return NodeResult(
              update: (value) => value + 1,
              transition: const ContinueAt('wait'),
            );
          },
        ),
        'wait': WorkflowNode(
          execute: (_, _) => Completer<NodeResult<int>>().future,
        ),
      },
    );
    final controller = AgentController(
      runtime: AgentRuntime(store: store),
      workflow: workflow,
      threadId: 'race',
    );
    addTearDown(controller.dispose);
    await controller.start();
    await entered.future;
    store.afterLoad = () async {
      release.complete();
      await until(controller, (state) => state.data == 1);
    };
    expect(await controller.cancel(), true);
    expect(controller.state.status, RunStatus.cancelled);
    expect(controller.state.error?.code, 'cancelled');
  });

  test(
    'projects typed state and supports later turns on the same thread',
    () async {
      final controller = AgentController(
        runtime: AgentRuntime(store: MemoryCheckpointStore()),
        workflow: counterWorkflow(),
        threadId: 'counter',
      );
      addTearDown(controller.dispose);
      expect(await controller.start(), true);
      await controller.completion;
      await until(controller, (state) => state.status == RunStatus.completed);
      expect(controller.state.data, 1);
      expect(controller.state.canStart, true);
      expect(await controller.start(), true);
      await controller.completion;
      await until(controller, (state) => state.data == 2);
    },
  );

  test(
    'restores persistent questions and invalid responses do not consume them',
    () async {
      final store = MemoryCheckpointStore();
      final workflow = questionWorkflow();
      final first = AgentController(
        runtime: AgentRuntime(store: store),
        workflow: workflow,
        threadId: 'q',
      );
      await first.start();
      await first.completion;
      await until(first, (state) => state.pendingInput != null);
      final id = first.state.pendingInput!.request.id;
      first.dispose();
      final restored = AgentController(
        runtime: AgentRuntime(store: store),
        workflow: workflow,
        threadId: 'q',
      );
      addTearDown(restored.dispose);
      expect(await restored.restore(), true);
      final pending = restored.state.pendingInput!;
      expect(pending.request.id, id);
      expect(await restored.submitInput(pending, 123), false);
      expect(restored.state.error!.code, 'validation');
      expect(restored.state.pendingInput!.request.id, id);
      expect(await restored.submitInput(pending, 'Strength'), true);
      await restored.completion;
      await until(restored, (state) => state.pendingInput != null);
      expect(restored.state.data, 1);
      expect(restored.state.error, null);
    },
  );

  test('stale form callbacks cannot answer the next interrupt', () async {
    final controller = AgentController(
      runtime: AgentRuntime(store: MemoryCheckpointStore()),
      workflow: questionWorkflow(),
      threadId: 'q',
    );
    addTearDown(controller.dispose);
    await controller.start();
    await controller.completion;
    await until(controller, (state) => state.pendingInput != null);
    final old = controller.state.pendingInput!;
    await controller.submitInput(old, 'First');
    await controller.completion;
    await until(controller, (state) => state.pendingInput != null);
    final current = controller.state.pendingInput!;
    expect(current.request.id, isNot(old.request.id));
    expect(await controller.submitInput(old, 'Stale answer'), false);
    expect(controller.state.pendingInput!.request.id, current.request.id);
    expect(await controller.submitInput(current, 'Second'), true);
    await controller.completion;
    await until(controller, (state) => state.status == RunStatus.completed);
    expect(controller.state.data, 2);
  });

  test(
    'detach and reattach preserve accumulated in-flight text without cancelling',
    () async {
      final model = ControlledModel();
      final runtime = AgentRuntime(
        store: MemoryCheckpointStore(),
        model: model,
      );
      final workflow = chatWorkflow(
        id: 'chat',
        modelId: 'demo',
        systemPrompt: 'Test',
        tools: ToolRegistry([]),
      );
      final first = AgentController.chat(
        runtime: runtime,
        workflow: workflow,
        threadId: 'chat',
      );
      final second = AgentController.chat(
        runtime: runtime,
        workflow: workflow,
        threadId: 'chat',
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await first.start(input: {'text': 'Hello'});
      model.output.add(const ModelText('Hello '));
      await until(first, (state) => state.streamingText == 'Hello ');
      first.detach();
      expect(first.state.hasLiveRun, true);
      expect(first.state.needsRecovery, false);
      model.output.add(const ModelText('world'));
      await Future<void>.delayed(Duration.zero);
      expect(await second.restore(), true);
      await until(second, (state) => state.streamingText == 'Hello world');
      expect(second.state.isAttached, true);
      model.output.add(ModelFinished(ModelFinishReason.stop));
      await model.output.close();
      await second.completion;
      await until(second, (state) => state.status == RunStatus.completed);
      expect(second.state.data!.messages.last.text, 'Hello world');
      expect(second.state.streamingText, isEmpty);
    },
  );

  test('disposing a controller never cancels the underlying run', () async {
    final model = ControlledModel();
    final runtime = AgentRuntime(store: MemoryCheckpointStore(), model: model);
    final workflow = chatWorkflow(
      id: 'chat',
      modelId: 'demo',
      systemPrompt: 'Test',
      tools: ToolRegistry([]),
    );
    final controller = AgentController.chat(
      runtime: runtime,
      workflow: workflow,
      threadId: 'chat',
    );
    await controller.start(input: {'text': 'Hello'});
    final handle = runtime.attach('chat')!;
    controller.dispose();
    model.output.add(const ModelText('Still running'));
    model.output.add(ModelFinished(ModelFinishReason.stop));
    await model.output.close();
    expect((await handle.done).status, RunStatus.completed);
    final reopened = AgentController.chat(
      runtime: runtime,
      workflow: workflow,
      threadId: 'chat',
    );
    addTearDown(reopened.dispose);
    await reopened.restore();
    expect(reopened.state.data!.messages.last.text, 'Still running');
  });

  test(
    'dispose during async start does not attach or notify a dead view',
    () async {
      final store = GateStore();
      final runtime = AgentRuntime(store: store);
      final controller = AgentController(
        runtime: runtime,
        workflow: counterWorkflow(),
        threadId: 'counter',
      );
      var notifications = 0;
      controller.addListener(() {
        notifications++;
      });
      final accepted = controller.start();
      final beforeDispose = notifications;
      controller.dispose();
      store.gate.complete();
      expect(await accepted, true);
      final handle = runtime.attach('counter')!;
      expect((await handle.done).status, RunStatus.completed);
      expect(notifications, beforeDispose);
    },
  );

  test('local command serialization rejects duplicate submissions', () async {
    final store = GateStore();
    final controller = AgentController(
      runtime: AgentRuntime(store: store),
      workflow: counterWorkflow(),
      threadId: 'counter',
    );
    addTearDown(controller.dispose);
    final first = controller.start();
    expect(controller.state.isCommandPending, true);
    expect(await controller.start(), false);
    store.gate.complete();
    expect(await first, true);
    await controller.completion;
    expect(controller.state.isCommandPending, false);
  });

  test('detach during async start requires an explicit reattachment', () async {
    final store = GateStore();
    final controller = AgentController(
      runtime: AgentRuntime(store: store),
      workflow: counterWorkflow(),
      threadId: 'counter',
    );
    addTearDown(controller.dispose);
    final started = controller.start();
    controller.detach();
    store.gate.complete();
    expect(await started, true);
    expect(controller.state.isAttached, false);
    expect(controller.completion, null);
    expect(await controller.restore(), true);
    await controller.completion;
    await until(controller, (state) => state.status == RunStatus.completed);
    expect(controller.state.data, 1);
  });

  test('a stale controller cannot cancel a newer run on the thread', () async {
    final runtime = AgentRuntime(store: MemoryCheckpointStore());
    final workflow = questionWorkflow();
    final old = AgentController(
      runtime: runtime,
      workflow: workflow,
      threadId: 'q',
    );
    final current = AgentController(
      runtime: runtime,
      workflow: workflow,
      threadId: 'q',
    );
    addTearDown(old.dispose);
    addTearDown(current.dispose);
    await old.start();
    await old.completion;
    await old.cancel();
    old.detach();
    await current.start();
    await current.completion;
    final runId = current.state.checkpoint!.runId;
    expect(await old.cancel(), false);
    expect(old.state.error!.code, 'stale_run');
    final saved = await runtime.inspect('q');
    expect(saved!.runId, runId);
    expect(saved.status, RunStatus.suspended);
  });

  test('orphaned running checkpoints require explicit safe recovery', () async {
    final store = MemoryCheckpointStore();
    await store.save(
      RunCheckpoint(
        threadId: 'counter',
        runId: 'old',
        workflowId: 'counter',
        workflowVersion: 1,
        revision: 0,
        nextNode: 'count',
        status: RunStatus.running,
        state: {'value': 4},
        limits: const RunLimits().toJson(),
      ),
      expectedRevision: null,
    );
    final controller = AgentController(
      runtime: AgentRuntime(store: store),
      workflow: counterWorkflow(replaySafe: true),
      threadId: 'counter',
    );
    addTearDown(controller.dispose);
    await controller.restore();
    expect(controller.state.needsRecovery, true);
    expect(controller.state.data, 4);
    expect(await controller.recover(), true);
    await controller.completion;
    await until(controller, (state) => state.status == RunStatus.completed);
    expect(controller.state.data, 5);
  });

  test(
    'workflow mismatch is visible and does not execute the old checkpoint',
    () async {
      final runtime = AgentRuntime(store: MemoryCheckpointStore());
      final old = AgentController(
        runtime: runtime,
        workflow: counterWorkflow(),
        threadId: 'counter',
      );
      await old.start();
      await old.completion;
      old.dispose();
      final current = AgentController(
        runtime: runtime,
        workflow: counterWorkflow(version: 2),
        threadId: 'counter',
      );
      addTearDown(current.dispose);
      expect(await current.restore(), false);
      expect(current.state.error!.code, 'workflow_version');
      expect(current.state.data, null);
    },
  );

  test(
    'storage completion errors are observed and rendered as safe failures',
    () async {
      final controller = AgentController(
        runtime: AgentRuntime(store: FailingSaveStore()),
        workflow: counterWorkflow(),
        threadId: 'counter',
      );
      addTearDown(controller.dispose);
      await controller.start();
      await expectLater(controller.completion!, throwsStateError);
      await until(controller, (state) => state.error != null);
      expect(
        controller.state.error!.message,
        isNot(contains('private database')),
      );
      expect(controller.state.needsRecovery, true);
    },
  );

  test('explicit cancellation clears a persisted input request', () async {
    final controller = AgentController(
      runtime: AgentRuntime(store: MemoryCheckpointStore()),
      workflow: questionWorkflow(),
      threadId: 'q',
    );
    addTearDown(controller.dispose);
    await controller.start();
    await controller.completion;
    expect(await controller.cancel(), true);
    expect(controller.state.status, RunStatus.cancelled);
    expect(controller.state.pendingInput, null);
  });

  test(
    'chat convenience restores artifacts from saved workflow state',
    () async {
      final artifact = Artifact(
        id: 'summary',
        type: 'expense.summary',
        payload: {'total': 42},
      );
      final model = ScriptedModel([
        [
          ModelToolCall(ToolCall(id: 'report-1', name: 'report')),
          ModelFinished(ModelFinishReason.toolCalls),
        ],
        [const ModelText('Ready'), ModelFinished(ModelFinishReason.stop)],
      ]);
      final workflow = chatWorkflow(
        id: 'chat',
        modelId: 'demo',
        systemPrompt: 'Test',
        tools: ToolRegistry([
          CallbackTool('report', (_) => ToolSuccess({}, artifacts: [artifact])),
        ]),
      );
      final runtime = AgentRuntime(
        store: MemoryCheckpointStore(),
        model: model,
      );
      final first = AgentController.chat(
        runtime: runtime,
        workflow: workflow,
        threadId: 'chat',
      );
      await first.start(input: {'text': 'Report'});
      await first.completion;
      first.dispose();
      final restored = AgentController.chat(
        runtime: runtime,
        workflow: workflow,
        threadId: 'chat',
      );
      addTearDown(restored.dispose);
      await restored.restore();
      expect(restored.state.artifacts.single.type, 'expense.summary');
      expect(restored.state.artifacts.single.payload['total'], 42);
    },
  );
}

class _LoadRaceStore extends MemoryCheckpointStore {
  Future<void> Function()? afterLoad;
  @override
  Future<RunCheckpoint?> load(String threadId) async {
    final checkpoint = await super.load(threadId);
    final hook = afterLoad;
    afterLoad = null;
    await hook?.call();
    return checkpoint;
  }
}
