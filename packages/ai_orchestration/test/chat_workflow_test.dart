import 'dart:async';
import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:test/test.dart';
import 'support.dart';

void main() {
  test(
    'a rejected approval remains rejected if host policy later allows the tool',
    () async {
      var writes = 0;
      final tool = CallbackTool('write', (_) {
        writes++;
        return ToolSuccess({});
      }, effect: ToolEffect.write);
      final store = MemoryCheckpointStore();
      final model = ScriptedModel([
        calls([ToolCall(id: 'write', name: 'write')]),
        answer('Skipped'),
      ]);
      final paused = await turn(
        AgentRuntime(store: store, model: model),
        buildChat([
          tool,
        ], authorize: (_, _) => ToolAuthorization.requireApproval),
      );
      final result =
          await (await AgentRuntime(store: store, model: model).resume(
            workflow: buildChat([
              tool,
            ], authorize: (_, _) => ToolAuthorization.allow),
            threadId: paused.threadId,
            runId: paused.runId,
            interruptId: paused.interrupt!.id,
            expectedRevision: paused.revision,
            value: false,
          )).done;
      expect(result.status, RunStatus.completed);
      expect(writes, 0);
    },
  );

  test(
    'clarification followed by approval retains both interrupts across runtimes',
    () async {
      var writes = 0;
      final store = MemoryCheckpointStore();
      final model = ScriptedModel([
        calls([
          ToolCall(id: 'question', name: 'ask'),
          ToolCall(id: 'write', name: 'write'),
        ]),
        answer('Applied'),
      ]);
      final workflow = buildChat(
        [
          CallbackTool(
            'ask',
            (_) => ToolNeedsInput(
              InputRequest(responseSchema: ValueSchema.string()),
            ),
          ),
          CallbackTool('write', (_) {
            writes++;
            return ToolSuccess({'saved': true});
          }, effect: ToolEffect.write),
        ],
        authorize: (tool, _) => tool.effect == ToolEffect.write
            ? ToolAuthorization.requireApproval
            : ToolAuthorization.allow,
      );
      final first = await turn(
        AgentRuntime(store: store, model: model),
        workflow,
      );
      final second =
          await (await AgentRuntime(store: store, model: model).resume(
            workflow: workflow,
            threadId: first.threadId,
            runId: first.runId,
            interruptId: first.interrupt!.id,
            expectedRevision: first.revision,
            value: 'food',
          )).done;
      expect(second.status, RunStatus.suspended);
      expect(second.interrupt!.kind, 'tool_approval');
      expect(writes, 0);
      final third =
          await (await AgentRuntime(store: store, model: model).resume(
            workflow: workflow,
            threadId: second.threadId,
            runId: second.runId,
            interruptId: second.interrupt!.id,
            expectedRevision: second.revision,
            value: true,
          )).done;
      expect(third.status, RunStatus.completed);
      expect(writes, 1);
      expect(
        const ChatStateCodec()
            .decode(third.state)
            .messages
            .where((message) => message.role == 'tool')
            .map((message) => message.callId),
        ['question', 'write'],
      );
    },
  );

  test('artifact envelopes persist independently of the host UI', () async {
    final workflow = buildChat([
      CallbackTool(
        'report',
        (_) => ToolSuccess(
          {'ready': true},
          artifacts: [
            Artifact(
              id: 'report',
              type: 'expense.summary',
              version: 2,
              payload: {'total': 42},
            ),
          ],
        ),
      ),
    ]);
    final result = await turn(
      AgentRuntime(
        store: MemoryCheckpointStore(),
        model: ScriptedModel([
          calls([ToolCall(id: 'report', name: 'report')]),
          answer('Ready'),
        ]),
      ),
      workflow,
    );
    final artifact = const ChatStateCodec()
        .decode(result.state)
        .artifacts
        .single;
    expect(artifact.type, 'expense.summary');
    expect(artifact.version, 2);
    expect(artifact.payload['total'], 42);
  });

  test(
    'second model request includes prior conversation and attachments',
    () async {
      final model = ScriptedModel([answer('Hello Sam.'), answer('Sam.')]);
      final workflow = buildChat([]);
      final runtime = AgentRuntime(
        store: MemoryCheckpointStore(),
        model: model,
      );
      await (await runtime.start(
        workflow: workflow,
        threadId: 'a',
        input: {
          'text': 'My name is Sam.',
          'attachments': [
            {'mimeType': 'image/png', 'base64': 'AA=='},
          ],
        },
      )).done;
      final result = await turn(
        runtime,
        workflow,
        thread: 'a',
        text: 'What is my name?',
      );
      expect(result.status, RunStatus.completed);
      expect(model.requests.last.messages.map((message) => message.text), [
        'My name is Sam.',
        'Hello Sam.',
        'What is my name?',
      ]);
      expect(
        model.requests.last.messages.first.attachments.single['mimeType'],
        'image/png',
      );
    },
  );

  test('same-name tool calls preserve distinct native result IDs', () async {
    final model = ScriptedModel([
      calls([
        ToolCall(id: 'native-1', name: 'lookup'),
        ToolCall(id: 'native-2', name: 'lookup'),
      ]),
      answer('Done'),
    ]);
    final runtime = AgentRuntime(store: MemoryCheckpointStore(), model: model);
    final result = await turn(
      runtime,
      buildChat([
        CallbackTool('lookup', (_) => ToolSuccess({'value': 1})),
      ]),
    );
    expect(result.status, RunStatus.completed);
    expect(
      model.requests.last.messages
          .where((message) => message.role == 'tool')
          .map((message) => message.callId),
      ['native-1', 'native-2'],
    );
  });

  test(
    'question suspends before later write and resume completes original call once',
    () async {
      var writes = 0;
      final model = ScriptedModel([
        calls([
          ToolCall(id: 'ask-1', name: 'ask'),
          ToolCall(id: 'write-1', name: 'write'),
        ]),
        answer('Saved'),
      ]);
      final workflow = buildChat([
        CallbackTool(
          'ask',
          (_) => ToolNeedsInput(
            InputRequest(
              responseSchema: ValueSchema.string(),
              payload: {'label': 'Goal?'},
            ),
          ),
        ),
        CallbackTool('write', (_) {
          writes++;
          return ToolSuccess({'saved': true});
        }, effect: ToolEffect.write),
      ], authorize: (_, _) => ToolAuthorization.allow);
      final store = MemoryCheckpointStore();
      final paused = await turn(
        AgentRuntime(store: store, model: model),
        workflow,
      );
      expect(paused.status, RunStatus.suspended);
      expect(writes, 0);
      expect(
        const ChatStateCodec()
            .decode(paused.state)
            .messages
            .where((message) => message.role == 'tool'),
        isEmpty,
      );
      final resumedRuntime = AgentRuntime(
        store: store,
        model: model,
        limits: const RunLimits(maxModelCalls: 0, maxSteps: 1),
      );
      final handle = await resumedRuntime.resume(
        workflow: workflow,
        threadId: 'thread',
        runId: paused.runId,
        interruptId: paused.interrupt!.id,
        expectedRevision: paused.revision,
        value: 'Strength',
      );
      final result = await handle.done;
      expect(result.status, RunStatus.completed);
      expect(writes, 1);
      expect(result.modelCalls, 2);
      final results = model.requests.last.messages
          .where((message) => message.role == 'tool')
          .toList();
      expect(results.map((message) => message.callId), ['ask-1', 'write-1']);
      expect(results.first.result!['response'], 'Strength');
      await expectLater(
        resumedRuntime.resume(
          workflow: workflow,
          threadId: 'thread',
          runId: paused.runId,
          interruptId: paused.interrupt!.id,
          expectedRevision: paused.revision,
          value: 'Again',
        ),
        throwsA(isA<CheckpointConflict>()),
      );
      expect(writes, 1);
    },
  );

  test(
    'mutation policy requires approval and declined writes do not execute',
    () async {
      var writes = 0;
      final model = ScriptedModel([
        calls([ToolCall(id: 'write-1', name: 'write')]),
        answer('Skipped'),
      ]);
      final workflow = buildChat([
        CallbackTool('write', (_) {
          writes++;
          return ToolSuccess({'saved': true});
        }, effect: ToolEffect.write),
      ], authorize: (_, _) => ToolAuthorization.requireApproval);
      final runtime = AgentRuntime(
        store: MemoryCheckpointStore(),
        model: model,
      );
      final paused = await turn(runtime, workflow);
      expect(paused.status, RunStatus.suspended);
      expect(writes, 0);
      final result = await (await runtime.resume(
        workflow: workflow,
        threadId: 'thread',
        runId: paused.runId,
        interruptId: paused.interrupt!.id,
        expectedRevision: paused.revision,
        value: false,
      )).done;
      expect(result.status, RunStatus.completed);
      expect(writes, 0);
      expect(model.requests.last.messages.last.result!['skipped'], true);
    },
  );

  test(
    'approved writes execute once, using a stable operation identity',
    () async {
      String? operation;
      final model = ScriptedModel([
        calls([ToolCall(id: 'write-1', name: 'write')]),
        answer('Saved'),
      ]);
      final workflow = buildChat([
        CallbackTool('write', (context) {
          operation = context.operationId;
          return ToolSuccess({'saved': true});
        }, effect: ToolEffect.write),
      ], authorize: (_, _) => ToolAuthorization.requireApproval);
      final runtime = AgentRuntime(
        store: MemoryCheckpointStore(),
        model: model,
      );
      final paused = await turn(runtime, workflow);
      final result = await (await runtime.resume(
        workflow: workflow,
        threadId: 'thread',
        runId: paused.runId,
        interruptId: paused.interrupt!.id,
        expectedRevision: paused.revision,
        value: true,
      )).done;
      expect(result.status, RunStatus.completed);
      expect(operation, canonicalJson(['thread', paused.runId, 1, 'write-1']));
    },
  );

  test(
    'writes are denied by default and invalid arguments never reach tools',
    () async {
      var executions = 0;
      final write = CallbackTool('write', (_) {
        executions++;
        return ToolSuccess({});
      }, effect: ToolEffect.write);
      final model = ScriptedModel([
        calls([ToolCall(id: 'w', name: 'write')]),
      ]);
      final denied = await turn(
        AgentRuntime(store: MemoryCheckpointStore(), model: model),
        buildChat([write]),
      );
      expect(denied.failure!['code'], 'tool_denied');
      final query = CallbackTool(
        'query',
        (_) {
          executions++;
          return ToolSuccess({});
        },
        arguments: ValueSchema.object(
          properties: {'days': ValueSchema.integer(minimum: 1)},
          required: ['days'],
        ),
      );
      final invalid = await turn(
        AgentRuntime(
          store: MemoryCheckpointStore(),
          model: ScriptedModel([
            calls([
              ToolCall(id: 'q', name: 'query', arguments: {'days': 'many'}),
            ]),
          ]),
        ),
        buildChat([query]),
      );
      expect(invalid.failure!['code'], 'validation');
      expect(executions, 0);
    },
  );

  test('model and tool budgets are enforced independently', () async {
    final query = CallbackTool('query', (_) => ToolSuccess({}));
    final workflow = buildChat([query]);
    final toolLimited = await turn(
      AgentRuntime(
        store: MemoryCheckpointStore(),
        limits: const RunLimits(maxToolCalls: 0),
        model: ScriptedModel([
          calls([ToolCall(id: 'q', name: 'query')]),
        ]),
      ),
      workflow,
    );
    expect(toolLimited.status, RunStatus.exhausted);
    final modelLimited = await turn(
      AgentRuntime(
        store: MemoryCheckpointStore(),
        limits: const RunLimits(maxModelCalls: 1),
        model: ScriptedModel([
          calls([ToolCall(id: 'q', name: 'query')]),
        ]),
      ),
      workflow,
    );
    expect(modelLimited.status, RunStatus.exhausted);
    expect(modelLimited.toolCalls, 1);
  });

  test(
    'native IDs reused in different model passes have distinct operation identities',
    () async {
      final operations = <String>[];
      final tool = CallbackTool('lookup', (context) {
        operations.add(context.operationId);
        return ToolSuccess({});
      });
      final model = ScriptedModel([
        calls([ToolCall(id: 'provider-local-id', name: 'lookup')]),
        calls([ToolCall(id: 'provider-local-id', name: 'lookup')]),
        answer('Done'),
      ]);
      final result = await turn(
        AgentRuntime(store: MemoryCheckpointStore(), model: model),
        buildChat([tool]),
      );
      expect(result.status, RunStatus.completed);
      expect(operations.toSet(), hasLength(2));
    },
  );

  test(
    'partial or blocked model output does not become a successful assistant message',
    () async {
      for (final events in [
        <ModelEvent>[const ModelText('Partial')],
        <ModelEvent>[ModelFinished(ModelFinishReason.blocked)],
      ]) {
        final result = await turn(
          AgentRuntime(
            store: MemoryCheckpointStore(),
            model: ScriptedModel([events]),
          ),
          buildChat([]),
        );
        expect(result.status, RunStatus.failed);
        expect(const ChatStateCodec().decode(result.state).messages.length, 1);
      }
    },
  );

  test(
    'provider stream errors stay failures and do not leak raw diagnostics',
    () async {
      final result = await turn(
        AgentRuntime(store: MemoryCheckpointStore(), model: _FailingModel()),
        buildChat([]),
      );
      expect(result.status, RunStatus.failed);
      expect(result.failure!['message'], isNot(contains('secret')));
    },
  );

  test('typed terminal event and sequence survive suspension', () async {
    final runtime = AgentRuntime(
      store: MemoryCheckpointStore(),
      model: ScriptedModel([answer('Hi')]),
    );
    final handle = await runtime.start(
      workflow: buildChat([]),
      threadId: 'a',
      input: {'text': 'Hello'},
    );
    final eventsFuture = handle.events.toList();
    final result = await handle.done;
    final events = await eventsFuture;
    expect(events.last.type, RunEventType.completed);
    expect(events.every((event) => event.runId == result.runId), true);
    expect(events.map((event) => event.sequence).toSet().length, events.length);
    expect(events.last.sequence, result.sequence);
  });
}

class _FailingModel implements ModelProvider {
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    yield const ModelText('Partial');
    throw StateError('secret provider diagnostics');
  }
}
