import 'dart:async';
import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';

class IntCodec implements StateCodec<int> {
  @override
  int decode(JsonMap json) => json['value']! as int;
  @override
  JsonMap encode(int state) => {'value': state};
}

Workflow<int> counterWorkflow({int version = 1, bool replaySafe = false}) =>
    Workflow(
      id: 'counter',
      version: version,
      entryNode: 'count',
      codec: IntCodec(),
      initialize: (previous, _) => previous ?? 0,
      nodes: {
        'count': WorkflowNode<int>(
          replaySafe: replaySafe,
          execute: (_, _) => NodeResult(
            update: (value) => value + 1,
            transition: const Complete(),
          ),
        ),
      },
    );

Workflow<int> questionWorkflow() => Workflow(
  id: 'questions',
  entryNode: 'ask',
  codec: IntCodec(),
  initialize: (_, _) => 0,
  nodes: {
    'ask': WorkflowNode<int>(
      destinations: {'answer'},
      execute: (_, state) => NodeResult(
        update: (value) => value,
        transition: state == 2
            ? const Complete()
            : SuspendAt(
                'answer',
                InputRequest(
                  responseSchema: ValueSchema.string(),
                  payload: {'question': 'Goal?'},
                ),
              ),
      ),
    ),
    'answer': WorkflowNode<int>(
      destinations: {'ask'},
      execute: (context, _) {
        if (context.resumeInput?.value is! String) {
          throw StateError('Missing answer.');
        }
        return NodeResult(
          update: (value) => value + 1,
          transition: const ContinueAt('ask'),
        );
      },
    ),
  },
);

class ControlledModel implements ModelProvider {
  final output = StreamController<ModelEvent>();
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) => output.stream;
}

class ScriptedModel implements ModelProvider {
  final List<List<ModelEvent>> turns;
  int _turn = 0;
  ScriptedModel(this.turns);
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    for (final event in turns[_turn++]) {
      yield event;
    }
  }
}

class CallbackTool implements AgentTool {
  @override
  final ToolDefinition definition;
  final FutureOr<ToolOutcome> Function(ToolContext context) action;
  CallbackTool(String name, this.action, {ToolEffect effect = ToolEffect.read})
    : definition = ToolDefinition(
        name: name,
        description: 'Test tool',
        arguments: ValueSchema.object(),
        effect: effect,
      );
  @override
  FutureOr<ToolOutcome> execute(ToolContext context) => action(context);
}

Future<void> until<S>(
  AgentController<S> controller,
  bool Function(AgentViewState<S>) predicate,
) async {
  if (predicate(controller.state)) return;
  final done = Completer<void>();
  void changed() {
    if (!done.isCompleted && predicate(controller.state)) done.complete();
  }

  controller.addListener(changed);
  try {
    await done.future.timeout(const Duration(seconds: 3));
  } finally {
    controller.removeListener(changed);
  }
}

class GateStore implements CheckpointStore {
  final CheckpointStore inner = MemoryCheckpointStore();
  final gate = Completer<void>();
  @override
  Future<RunCheckpoint?> load(String threadId) async {
    await gate.future;
    return inner.load(threadId);
  }

  @override
  Future<void> save(
    RunCheckpoint checkpoint, {
    required int? expectedRevision,
  }) => inner.save(checkpoint, expectedRevision: expectedRevision);
}

class FailingSaveStore implements CheckpointStore {
  final CheckpointStore inner = MemoryCheckpointStore();
  @override
  Future<RunCheckpoint?> load(String threadId) => inner.load(threadId);
  @override
  Future<void> save(
    RunCheckpoint checkpoint, {
    required int? expectedRevision,
  }) async {
    if (expectedRevision != null) {
      throw StateError('private database diagnostic');
    }
    await inner.save(checkpoint, expectedRevision: expectedRevision);
  }
}
