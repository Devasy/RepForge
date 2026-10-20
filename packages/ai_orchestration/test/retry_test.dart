import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test(
    'retry repeats only a failed replay-safe node and preserves identity and budgets',
    () async {
      var attempts = 0;
      final workflow = intWorkflow(
        WorkflowNode(
          replaySafe: true,
          execute: (_, _) {
            if (attempts++ == 0) {
              throw const OrchestrationException('network', 'Retry later.');
            }
            return NodeResult(
              update: (value) => value + 1,
              transition: const Complete(),
            );
          },
        ),
      );
      final runtime = AgentRuntime(store: MemoryCheckpointStore());
      final failed = await (await runtime.start(
        workflow: workflow,
        threadId: 'retry',
      )).done;
      final completed = await (await runtime.retry(
        workflow: workflow,
        threadId: 'retry',
        expectedRevision: failed.revision,
      )).done;
      expect(completed.runId, failed.runId);
      expect(completed.status, RunStatus.completed);
      expect(completed.state['value'], 1);
      expect(completed.steps, failed.steps + 1);
      expect(completed.failure, null);
      await expectLater(
        runtime.retry(
          workflow: workflow,
          threadId: 'retry',
          expectedRevision: failed.revision,
        ),
        throwsA(isA<CheckpointConflict>()),
      );
    },
  );

  test(
    'retry refuses failed mutations and does not reset exhausted budgets',
    () async {
      final workflow = intWorkflow(
        WorkflowNode(execute: (_, _) => throw StateError('Failed write')),
      );
      final runtime = AgentRuntime(store: MemoryCheckpointStore());
      final failed = await (await runtime.start(
        workflow: workflow,
        threadId: 'write',
      )).done;
      await expectLater(
        runtime.retry(
          workflow: workflow,
          threadId: 'write',
          expectedRevision: failed.revision,
        ),
        throwsA(
          isA<OrchestrationException>().having(
            (e) => e.code,
            'code',
            'unsafe_retry',
          ),
        ),
      );
      final safe = intWorkflow(
        WorkflowNode(
          replaySafe: true,
          execute: (_, _) => throw StateError('Failed request'),
        ),
      );
      final limited = AgentRuntime(
        store: MemoryCheckpointStore(),
        limits: const RunLimits(maxSteps: 1),
      );
      final first = await (await limited.start(
        workflow: safe,
        threadId: 'limit',
      )).done;
      final retry = await (await limited.retry(
        workflow: safe,
        threadId: 'limit',
        expectedRevision: first.revision,
      )).done;
      expect(retry.status, RunStatus.exhausted);
      expect(retry.steps, 1);
    },
  );

  test(
    'imported chat history is used only for the first turn and turn boundaries persist',
    () async {
      final model = ScriptedModel([answer('First'), answer('Second')]);
      final workflow = chatWorkflow(
        id: 'import',
        modelId: 'test',
        systemPrompt: 'Test',
        tools: ToolRegistry([]),
        initialMessages: [
          ModelMessage(role: 'user', text: 'Old question'),
          ModelMessage(role: 'assistant', text: 'Old answer'),
        ],
      );
      final runtime = AgentRuntime(
        store: MemoryCheckpointStore(),
        model: model,
      );
      final first = await turn(runtime, workflow, text: 'New question');
      expect(const ChatStateCodec().decode(first.state).turnStart, 2);
      final second = await turn(runtime, workflow, text: 'Next question');
      expect(model.requests.last.messages.map((m) => m.text), [
        'Old question',
        'Old answer',
        'New question',
        'First',
        'Next question',
      ]);
      expect(const ChatStateCodec().decode(second.state).turnStart, 4);
    },
  );

  test(
    'nullable schema annotations retain validation and reject invalid annotations',
    () {
      final schema = ValueSchema({
        'type': 'integer',
        'nullable': true,
        'description': 'Optional count',
        'minimum': 1,
      });
      schema.validate(null);
      schema.validate(2);
      expect(
        () => schema.validate('2'),
        throwsA(isA<OrchestrationException>()),
      );
      expect(() => schema.validate(0), throwsA(isA<OrchestrationException>()));
      expect(
        () => ValueSchema({'type': 'integer', 'nullable': 'yes'}),
        throwsArgumentError,
      );
    },
  );
}
