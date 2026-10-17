import 'dart:async';

import 'checkpoint.dart';
import 'json.dart';
import 'model.dart';
import 'schema.dart';
import 'tool.dart';
import 'workflow.dart';

enum RunEventType {
  started,
  resumed,
  nodeStarted,
  textDelta,
  toolStarted,
  toolCompleted,
  artifact,
  checkpoint,
  interrupted,
  completed,
  failed,
  cancelled,
  exhausted,
}

class RunEvent {
  final String threadId;
  final String runId;
  final int sequence;
  final RunEventType type;
  final String? nodeId;
  final String? callId;
  final JsonMap data;
  RunEvent({
    required this.threadId,
    required this.runId,
    required this.sequence,
    required this.type,
    this.nodeId,
    this.callId,
    JsonMap data = const {},
  }) : data = jsonObject(data);
}

class RunHandle {
  final StreamController<RunEvent> _events = StreamController.broadcast();
  final Completer<RunCheckpoint> _done = Completer();
  final CancellationToken _cancellation = CancellationToken();
  RunCheckpoint _snapshot;
  RunHandle._(this._snapshot);
  RunCheckpoint get snapshot => _snapshot;
  Stream<RunEvent> get events => _events.stream;
  Future<RunCheckpoint> get done => _done.future;
}

class AgentRuntime {
  final CheckpointStore store;
  final ModelProvider? model;
  final RunLimits limits;
  final Map<String, RunHandle> _active = {};
  AgentRuntime({
    required this.store,
    this.model,
    this.limits = const RunLimits(),
  }) {
    limits.validate();
  }

  Future<RunCheckpoint?> inspect(String threadId) => store.load(threadId);
  RunHandle? attach(String threadId) => _active[threadId];

  Future<RunHandle> start<S>({
    required Workflow<S> workflow,
    required String threadId,
    JsonMap input = const {},
  }) async {
    if (threadId.isEmpty) {
      throw ArgumentError('A stable thread ID is required.');
    }
    final previous = await store.load(threadId);
    if (_active.containsKey(threadId) ||
        previous?.status == RunStatus.running ||
        previous?.status == RunStatus.suspended) {
      throw const OrchestrationException(
        'busy',
        'Thread has an unfinished run.',
      );
    }
    if (previous != null) _validateWorkflow(workflow, previous);
    final state = workflow.initialize(
      previous == null ? null : workflow.codec.decode(previous.state),
      jsonObject(input),
    );
    final checkpoint = RunCheckpoint(
      threadId: threadId,
      runId: newIdentifier(),
      workflowId: workflow.id,
      workflowVersion: workflow.version,
      revision: (previous?.revision ?? -1) + 1,
      nextNode: workflow.entryNode,
      status: RunStatus.running,
      state: workflow.codec.encode(state),
      limits: limits.toJson(),
    );
    await store.save(checkpoint, expectedRevision: previous?.revision);
    return _launch(workflow, checkpoint, RunEventType.started);
  }

  Future<RunHandle> resume<S>({
    required Workflow<S> workflow,
    required String threadId,
    required String runId,
    required String interruptId,
    required int expectedRevision,
    required Object? value,
  }) async {
    final checkpoint = await _load(workflow, threadId, expectedRevision);
    final request = checkpoint.interrupt;
    if (checkpoint.runId != runId ||
        checkpoint.status != RunStatus.suspended ||
        request?.id != interruptId) {
      throw const OrchestrationException(
        'invalid_resume',
        'No matching pending interrupt.',
      );
    }
    request!.responseSchema.validate(value);
    final resumed = checkpoint.update({
      'revision': checkpoint.revision + 1,
      'status': RunStatus.running.name,
      'interrupt': null,
      'resumeInput': ResumeInput(request, value).toJson(),
    });
    await store.save(resumed, expectedRevision: expectedRevision);
    return _launch(workflow, resumed, RunEventType.resumed);
  }

  /// Only call after the previous executor has stopped; this is not a lease.
  Future<RunHandle> recover<S>({
    required Workflow<S> workflow,
    required String threadId,
    required int expectedRevision,
  }) async {
    final checkpoint = await _load(workflow, threadId, expectedRevision);
    if (_active.containsKey(threadId) ||
        checkpoint.status != RunStatus.running ||
        workflow.nodes[checkpoint.nextNode]?.replaySafe != true) {
      throw const OrchestrationException(
        'unsafe_recovery',
        'This node requires host reconciliation before recovery.',
      );
    }
    final recovered = checkpoint.update({'revision': checkpoint.revision + 1});
    await store.save(recovered, expectedRevision: expectedRevision);
    return _launch(workflow, recovered, RunEventType.resumed);
  }

  Future<RunCheckpoint> cancel(
    String threadId, {
    required int expectedRevision,
  }) async {
    final checkpoint = await store.load(threadId);
    if (checkpoint == null || checkpoint.revision != expectedRevision) {
      throw const CheckpointConflict();
    }
    final active = _active[threadId];
    if (active != null) {
      active._cancellation.cancel();
      return active.done;
    }
    if (checkpoint.status != RunStatus.suspended &&
        checkpoint.status != RunStatus.running) {
      return checkpoint;
    }
    final cancelled = checkpoint.update({
      'revision': checkpoint.revision + 1,
      'status': RunStatus.cancelled.name,
      'interrupt': null,
      'resumeInput': null,
    });
    await store.save(cancelled, expectedRevision: expectedRevision);
    return cancelled;
  }

  Future<RunCheckpoint> _load<S>(
    Workflow<S> workflow,
    String threadId,
    int revision,
  ) async {
    final checkpoint = await store.load(threadId);
    if (checkpoint == null || checkpoint.revision != revision) {
      throw const CheckpointConflict();
    }
    _validateWorkflow(workflow, checkpoint);
    return checkpoint;
  }

  void _validateWorkflow<S>(Workflow<S> workflow, RunCheckpoint checkpoint) {
    if (checkpoint.workflowId != workflow.id ||
        checkpoint.workflowVersion != workflow.version) {
      throw const OrchestrationException(
        'workflow_version',
        'Checkpoint needs an explicit workflow migration.',
      );
    }
    if (!workflow.nodes.containsKey(checkpoint.nextNode)) {
      throw const OrchestrationException(
        'invalid_node',
        'Checkpoint continuation is unavailable.',
      );
    }
  }

  RunHandle _launch<S>(
    Workflow<S> workflow,
    RunCheckpoint checkpoint,
    RunEventType event,
  ) {
    final handle = RunHandle._(checkpoint);
    _active[checkpoint.threadId] = handle;
    unawaited(
      Future<void>(() async {
        final execution = _Execution<S>(this, workflow, handle);
        try {
          execution.emit(event);
          await execution.drive();
          handle._done.complete(handle.snapshot);
        } catch (error, stack) {
          handle._done.completeError(error, stack);
        } finally {
          execution.stopped = true;
          if (identical(_active[checkpoint.threadId], handle)) {
            _active.remove(checkpoint.threadId);
          }
          unawaited(handle._events.close());
        }
      }),
    );
    return handle;
  }
}

class _Execution<S> implements NodeContext {
  final AgentRuntime runtime;
  final Workflow<S> workflow;
  final RunHandle handle;
  late final RunLimits limits = RunLimits.fromJson(handle.snapshot.limits)
    ..validate();
  final Stopwatch _clock = Stopwatch()..start();
  late final int _previousMicros = handle.snapshot.activeMicroseconds;
  late int _modelCalls = handle.snapshot.modelCalls;
  late int _toolCalls = handle.snapshot.toolCalls;
  late int _steps = handle.snapshot.steps;
  late int _sequence = handle.snapshot.sequence;
  bool stopped = false;
  _Execution(this.runtime, this.workflow, this.handle);
  @override
  String get threadId => handle.snapshot.threadId;
  @override
  String get runId => handle.snapshot.runId;
  @override
  ResumeInput? get resumeInput => handle.snapshot.resumeInput;
  @override
  CancellationToken get cancellation => handle._cancellation;
  Duration get _remaining =>
      limits.activeTimeout -
      Duration(microseconds: _previousMicros + _clock.elapsedMicroseconds);
  @override
  DateTime get deadline => DateTime.now().toUtc().add(_remaining);

  void _check() {
    cancellation.check();
    if (stopped) {
      throw const OrchestrationException('cancelled', 'Executor has stopped.');
    }
    if (_remaining <= Duration.zero) {
      throw const OrchestrationException(
        'exhausted',
        'Active run deadline exceeded.',
      );
    }
  }

  void emit(RunEventType type, {String? callId, JsonMap data = const {}}) {
    if (stopped) return;
    handle._events.add(
      RunEvent(
        threadId: threadId,
        runId: runId,
        sequence: ++_sequence,
        type: type,
        nodeId: handle.snapshot.nextNode,
        callId: callId,
        data: data,
      ),
    );
  }

  @override
  Future<T> wait<T>(Future<T> operation) {
    final result = Completer<T>();
    operation.then(
      (value) {
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    try {
      _check();
    } catch (error, stack) {
      result.completeError(error, stack);
      return result.future;
    }
    final timer = Timer(_remaining, () {
      if (!result.isCompleted) {
        result.completeError(
          const OrchestrationException(
            'exhausted',
            'Active run deadline exceeded.',
          ),
        );
      }
    });
    unawaited(
      cancellation.whenCancelled.then((_) {
        if (!result.isCompleted) {
          result.completeError(
            const OrchestrationException('cancelled', 'Run cancelled.'),
          );
        }
      }),
    );
    return result.future.whenComplete(timer.cancel);
  }

  Future<void> _save(JsonMap changes, RunEventType event) async {
    final previous = handle.snapshot;
    final updated = previous.update({
      ...changes,
      'revision': previous.revision + 1,
      'steps': _steps,
      'modelCalls': _modelCalls,
      'toolCalls': _toolCalls,
      'sequence': _sequence + 1,
      'activeMicroseconds': _previousMicros + _clock.elapsedMicroseconds,
    });
    await runtime.store.save(updated, expectedRevision: previous.revision);
    handle._snapshot = updated;
    emit(
      event,
      data: {'revision': updated.revision, 'status': updated.status.name},
    );
  }

  Future<void> drive() async {
    try {
      while (true) {
        _check();
        if (_steps >= limits.maxSteps) {
          throw const OrchestrationException(
            'exhausted',
            'Node step budget exceeded.',
          );
        }
        final checkpoint = handle.snapshot;
        final current = await runtime.store.load(threadId);
        if (current?.revision != checkpoint.revision) {
          throw const CheckpointConflict();
        }
        _check();
        final node = workflow.nodes[checkpoint.nextNode]!;
        _steps++;
        emit(RunEventType.nodeStarted);
        final state = workflow.codec.decode(checkpoint.state);
        final result = await wait(Future.sync(() => node.execute(this, state)));
        _check();
        final target = switch (result.transition) {
          ContinueAt(:final nodeId) || SuspendAt(:final nodeId) => nodeId,
          Complete() => null,
        };
        if (target != null && !node.destinations.contains(target)) {
          throw const OrchestrationException(
            'invalid_transition',
            'Node returned an undeclared destination.',
          );
        }
        final updatedState = workflow.codec.encode(result.update(state));
        switch (result.transition) {
          case ContinueAt(:final nodeId):
            await _save({
              'state': updatedState,
              'nextNode': nodeId,
              'resumeInput': null,
            }, RunEventType.checkpoint);
          case SuspendAt(:final nodeId, :final request):
            await _save({
              'state': updatedState,
              'nextNode': nodeId,
              'resumeInput': null,
              'status': RunStatus.suspended.name,
              'interrupt': request.toJson(),
            }, RunEventType.interrupted);
            return;
          case Complete():
            await _save({
              'state': updatedState,
              'resumeInput': null,
              'status': RunStatus.completed.name,
            }, RunEventType.completed);
            return;
        }
      }
    } on CheckpointConflict {
      cancellation.cancel();
      rethrow;
    } catch (error) {
      cancellation.cancel();
      final failure = error is OrchestrationException
          ? error
          : const OrchestrationException(
              'execution_failed',
              'A node, provider, or tool failed.',
            );
      final status = switch (failure.code) {
        'cancelled' => RunStatus.cancelled,
        'exhausted' => RunStatus.exhausted,
        _ => RunStatus.failed,
      };
      await _save(
        {
          'status': status.name,
          'failure': {'code': failure.code, 'message': failure.message},
        },
        switch (status) {
          RunStatus.cancelled => RunEventType.cancelled,
          RunStatus.exhausted => RunEventType.exhausted,
          _ => RunEventType.failed,
        },
      );
    }
  }

  @override
  Future<ModelReply> callModel(ModelRequest request) async {
    _check();
    if (_modelCalls >= limits.maxModelCalls) {
      throw const OrchestrationException(
        'exhausted',
        'Model call budget exceeded.',
      );
    }
    final provider = runtime.model;
    if (provider == null) {
      throw const OrchestrationException(
        'model_unavailable',
        'No model provider is configured.',
      );
    }
    _modelCalls++;
    final iterator = StreamIterator(provider.stream(request, cancellation));
    final textBuffer = StringBuffer();
    final calls = <ToolCall>[];
    ModelFinished? finish;
    try {
      while (await wait(iterator.moveNext())) {
        _check();
        if (finish != null) {
          throw const OrchestrationException(
            'model_protocol',
            'Received data after model completion.',
          );
        }
        switch (iterator.current) {
          case ModelText(:final text):
            emit(RunEventType.textDelta, data: {'text': text});
            textBuffer.write(text);
          case ModelToolCall(:final call):
            if (calls.any((existing) => existing.id == call.id)) {
              throw const OrchestrationException(
                'model_protocol',
                'Duplicate native tool call ID.',
              );
            }
            calls.add(call);
          case ModelFinished():
            finish = iterator.current as ModelFinished;
        }
      }
    } finally {
      unawaited(
        iterator.cancel().then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        ),
      );
    }
    if (finish == null ||
        (finish.reason == ModelFinishReason.toolCalls) != calls.isNotEmpty) {
      throw const OrchestrationException(
        'model_protocol',
        'Missing or inconsistent model finish.',
      );
    }
    if (finish.reason == ModelFinishReason.blocked ||
        finish.reason == ModelFinishReason.length) {
      throw const OrchestrationException(
        'model_incomplete',
        'The model could not finish this response.',
      );
    }
    return ModelReply(textBuffer.toString(), calls, finish);
  }

  @override
  Future<ToolOutcome> executeTool(ToolCall call) async {
    _check();
    final tool = workflow.tools.require(call.name);
    tool.definition.arguments.validate(call.arguments);
    final context = ToolContext(
      threadId: threadId,
      runId: runId,
      call: call,
      cancellation: cancellation,
      deadline: deadline,
      modelCallIndex: _modelCalls,
    );
    final authorization = await wait(
      Future.sync(() => workflow.authorize(tool.definition, context)),
    );
    _check();
    if (authorization == ToolAuthorization.deny) {
      throw const OrchestrationException(
        'tool_denied',
        'Application policy denied this tool.',
      );
    }
    final resume = resumeInput;
    final matching = resume?.request.callId == call.id;
    final approval = matching && resume!.request.kind == 'tool_approval';
    if (approval &&
        resume.request.payload['fingerprint'] != canonicalJson(call.toJson())) {
      throw const OrchestrationException(
        'approval_mismatch',
        'The operation changed after approval was requested.',
      );
    }
    if (approval && resume.value != true) {
      return ToolSuccess({'approved': false, 'skipped': true});
    }
    if (matching && !approval) {
      return ToolSuccess({'response': resume!.value});
    }
    if (authorization == ToolAuthorization.requireApproval) {
      if (!approval) {
        return ToolNeedsInput(
          InputRequest(
            kind: 'tool_approval',
            callId: call.id,
            responseSchema: ValueSchema.boolean(),
            payload: {
              'tool': call.name,
              'arguments': call.arguments,
              'fingerprint': canonicalJson(call.toJson()),
            },
          ),
        );
      }
    }
    if (_toolCalls >= limits.maxToolCalls) {
      throw const OrchestrationException(
        'exhausted',
        'Tool call budget exceeded.',
      );
    }
    _toolCalls++;
    emit(RunEventType.toolStarted, callId: call.id, data: {'tool': call.name});
    final outcome = await wait(Future.sync(() => tool.execute(context)));
    _check();
    if (outcome is ToolNeedsInput) {
      if (outcome.request.kind == 'tool_approval') {
        throw const OrchestrationException(
          'reserved_interrupt',
          'Tool approval requests are owned by the executor.',
        );
      }
      return ToolNeedsInput(outcome.request.forCall(call.id));
    }
    final success = outcome as ToolSuccess;
    emit(
      RunEventType.toolCompleted,
      callId: call.id,
      data: {'tool': call.name},
    );
    for (final artifact in success.artifacts) {
      emit(RunEventType.artifact, callId: call.id, data: artifact.toJson());
    }
    return success;
  }
}
