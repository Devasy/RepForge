import 'dart:async';
import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:test/test.dart';
import 'support.dart';

void main() {
  test(
    'event-only hosts do not receive an uncaught completion error',
    () async {
      final errors = <Object>[];
      await runZonedGuarded(() async {
        final runtime = AgentRuntime(store: _FailingSaveStore());
        final handle = await runtime.start(
          workflow: intWorkflow(
            WorkflowNode(
              execute: (_, _) => NodeResult(
                update: (value) => value + 1,
                transition: const Complete(),
              ),
            ),
          ),
          threadId: 'event-only',
        );
        await handle.events.drain<void>();
        await Future<void>.delayed(Duration.zero);
        expect(errors, isEmpty);
        await expectLater(handle.done, throwsStateError);
      }, (error, _) => errors.add(error));
      expect(errors, isEmpty);
    },
  );

  test(
    'typed updates are committed and next turn initializes from prior state',
    () async {
      final workflow = intWorkflow(
        WorkflowNode(
          execute: (_, _) => NodeResult(
            update: (value) => value + 1,
            transition: const Complete(),
          ),
        ),
      );
      final runtime = AgentRuntime(store: MemoryCheckpointStore());
      final first = await (await runtime.start(
        workflow: workflow,
        threadId: 'a',
      )).done;
      final second = await (await runtime.start(
        workflow: workflow,
        threadId: 'a',
      )).done;
      expect(first.state['value'], 1);
      expect(second.state['value'], 2);
      expect(first.runId, isNot(second.runId));
      expect(second.revision, greaterThan(first.revision));
    },
  );

  test('graph validation rejects missing destinations', () {
    expect(
      () => intWorkflow(
        WorkflowNode(
          destinations: {'missing'},
          execute: (_, _) => NodeResult(
            update: (value) => value,
            transition: const Complete(),
          ),
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'undeclared dynamic transition fails without committing its state update',
    () async {
      final workflow = intWorkflow(
        WorkflowNode(
          execute: (_, _) => NodeResult(
            update: (value) => value + 10,
            transition: const ContinueAt('missing'),
          ),
        ),
      );
      final finalState = await (await AgentRuntime(
        store: MemoryCheckpointStore(),
      ).start(workflow: workflow, threadId: 'a')).done;
      expect(finalState.status, RunStatus.failed);
      expect(finalState.state['value'], 0);
      expect(finalState.failure!['code'], 'invalid_transition');
    },
  );

  test('only one concurrent start can claim a thread', () async {
    final gate = Completer<NodeResult<int>>();
    final workflow = intWorkflow(WorkflowNode(execute: (_, _) => gate.future));
    final store = MemoryCheckpointStore();
    final runtime = AgentRuntime(store: store);
    final other = AgentRuntime(store: store);
    final handle = await runtime.start(workflow: workflow, threadId: 'a');
    await expectLater(
      other.start(workflow: workflow, threadId: 'a'),
      throwsA(isA<OrchestrationException>()),
    );
    gate.complete(
      NodeResult(update: (value) => value, transition: const Complete()),
    );
    expect((await handle.done).status, RunStatus.completed);
  });

  test('multiple interrupt rounds survive coordinator recreation', () async {
    final store = MemoryCheckpointStore();
    final workflow = intWorkflow(
      WorkflowNode(
        destinations: {'count'},
        execute: (context, state) {
          if (state < 2) {
            return NodeResult(
              update: (value) => value + 1,
              transition: SuspendAt(
                'count',
                InputRequest(
                  responseSchema: ValueSchema.string(),
                  payload: {'round': state},
                ),
              ),
            );
          }
          expect(context.resumeInput!.value, 'second');
          return NodeResult(
            update: (value) => value + 1,
            transition: const Complete(),
          );
        },
      ),
    );
    final first = await (await AgentRuntime(
      store: store,
    ).start(workflow: workflow, threadId: 'a')).done;
    expect(first.status, RunStatus.suspended);
    final second = await (await AgentRuntime(store: store).resume(
      workflow: workflow,
      threadId: 'a',
      runId: first.runId,
      interruptId: first.interrupt!.id,
      expectedRevision: first.revision,
      value: 'first',
    )).done;
    expect(second.status, RunStatus.suspended);
    expect(second.interrupt!.id, isNot(first.interrupt!.id));
    final third = await (await AgentRuntime(store: store).resume(
      workflow: workflow,
      threadId: 'a',
      runId: second.runId,
      interruptId: second.interrupt!.id,
      expectedRevision: second.revision,
      value: 'second',
    )).done;
    expect(third.status, RunStatus.completed);
    expect(third.state['value'], 3);
  });

  test(
    'resume validates revision, request, workflow version and response before claiming',
    () async {
      final store = MemoryCheckpointStore();
      final workflow = intWorkflow(
        WorkflowNode(
          destinations: {'count'},
          execute: (_, _) => NodeResult(
            update: (value) => value,
            transition: SuspendAt(
              'count',
              InputRequest(responseSchema: ValueSchema.boolean()),
            ),
          ),
        ),
      );
      final runtime = AgentRuntime(store: store);
      final paused = await (await runtime.start(
        workflow: workflow,
        threadId: 'a',
      )).done;
      Future<RunHandle> resume({
        int? revision,
        String? id,
        Object? value = true,
      }) => runtime.resume(
        workflow: workflow,
        threadId: 'a',
        runId: paused.runId,
        interruptId: id ?? paused.interrupt!.id,
        expectedRevision: revision ?? paused.revision,
        value: value,
      );
      await expectLater(
        resume(revision: 999),
        throwsA(isA<CheckpointConflict>()),
      );
      await expectLater(
        resume(id: 'wrong'),
        throwsA(isA<OrchestrationException>()),
      );
      await expectLater(
        resume(value: 'yes'),
        throwsA(isA<OrchestrationException>()),
      );
      expect((await store.load('a'))!.revision, paused.revision);
      final changed = Workflow(
        id: workflow.id,
        version: 2,
        entryNode: workflow.entryNode,
        codec: workflow.codec,
        initialize: workflow.initialize,
        nodes: workflow.nodes,
      );
      await expectLater(
        runtime.resume(
          workflow: changed,
          threadId: 'a',
          runId: paused.runId,
          interruptId: paused.interrupt!.id,
          expectedRevision: paused.revision,
          value: true,
        ),
        throwsA(isA<OrchestrationException>()),
      );
    },
  );

  test(
    'cancellation stops a hung node and ignores its late state result',
    () async {
      final entered = Completer<void>();
      final gate = Completer<NodeResult<int>>();
      final workflow = intWorkflow(
        WorkflowNode(
          execute: (_, _) {
            entered.complete();
            return gate.future;
          },
        ),
      );
      final store = MemoryCheckpointStore();
      final runtime = AgentRuntime(store: store);
      final handle = await runtime.start(workflow: workflow, threadId: 'a');
      await entered.future;
      expect(identical(runtime.attach('a'), handle), isTrue);
      final cancelled = await runtime.cancel(
        'a',
        expectedRevision: handle.snapshot.revision,
      );
      expect(cancelled.status, RunStatus.cancelled);
      gate.complete(
        NodeResult(update: (_) => 999, transition: const Complete()),
      );
      await Future<void>.delayed(Duration.zero);
      expect((await store.load('a'))!.state['value'], 0);
    },
  );

  test('active timeout and node budget end as exhausted', () async {
    final workflow = intWorkflow(
      WorkflowNode(execute: (_, _) => Completer<NodeResult<int>>().future),
    );
    final result = await (await AgentRuntime(
      store: MemoryCheckpointStore(),
      limits: const RunLimits(activeTimeout: Duration(milliseconds: 30)),
    ).start(workflow: workflow, threadId: 'a')).done;
    expect(result.status, RunStatus.exhausted);
    final looping = intWorkflow(
      WorkflowNode(
        destinations: {'count'},
        execute: (_, _) => NodeResult(
          update: (value) => value + 1,
          transition: const ContinueAt('count'),
        ),
      ),
    );
    final bounded = await (await AgentRuntime(
      store: MemoryCheckpointStore(),
      limits: const RunLimits(maxSteps: 2),
    ).start(workflow: looping, threadId: 'b')).done;
    expect(bounded.status, RunStatus.exhausted);
    expect(bounded.state['value'], 2);
  });

  test(
    'checkpoint save rejects stale compare-and-set and freezes state',
    () async {
      final source = <String, Object?>{
        'nested': <String, Object?>{'value': 1},
      };
      final checkpoint = RunCheckpoint(
        threadId: 'a',
        runId: 'run',
        workflowId: 'counter',
        workflowVersion: 1,
        revision: 0,
        nextNode: 'count',
        status: RunStatus.running,
        state: source,
        limits: const RunLimits().toJson(),
      );
      (source['nested']! as JsonMap)['value'] = 9;
      expect((checkpoint.state['nested']! as JsonMap)['value'], 1);
      final store = MemoryCheckpointStore();
      await store.save(checkpoint, expectedRevision: null);
      await expectLater(
        store.save(checkpoint, expectedRevision: null),
        throwsA(isA<CheckpointConflict>()),
      );
    },
  );

  test('recovery refuses non-replay-safe nodes', () async {
    final store = MemoryCheckpointStore();
    await store.save(
      RunCheckpoint(
        threadId: 'a',
        runId: 'run',
        workflowId: 'counter',
        workflowVersion: 1,
        revision: 0,
        nextNode: 'count',
        status: RunStatus.running,
        state: {'value': 0},
        limits: const RunLimits().toJson(),
      ),
      expectedRevision: null,
    );
    final workflow = intWorkflow(
      WorkflowNode(
        execute: (_, _) => NodeResult(
          update: (value) => value + 1,
          transition: const Complete(),
        ),
      ),
    );
    await expectLater(
      AgentRuntime(
        store: store,
      ).recover(workflow: workflow, threadId: 'a', expectedRevision: 0),
      throwsA(isA<OrchestrationException>()),
    );
    final safe = intWorkflow(
      WorkflowNode(
        replaySafe: true,
        execute: (_, _) => NodeResult(
          update: (value) => value + 1,
          transition: const Complete(),
        ),
      ),
    );
    final recovered = await (await AgentRuntime(
      store: store,
    ).recover(workflow: safe, threadId: 'a', expectedRevision: 0)).done;
    expect(recovered.state['value'], 1);
  });
}

class _FailingSaveStore extends MemoryCheckpointStore {
  @override
  Future<void> save(
    RunCheckpoint checkpoint, {
    required int? expectedRevision,
  }) async {
    if (expectedRevision != null) throw StateError('Storage unavailable');
    await super.save(checkpoint, expectedRevision: expectedRevision);
  }
}
