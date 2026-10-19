import 'dart:async';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:flutter/foundation.dart';

import 'agent_view_state.dart';
import 'run_observer.dart';

typedef ArtifactsOf<S> = Iterable<Artifact> Function(S state);

class AgentController<S> extends ChangeNotifier
    implements ValueListenable<AgentViewState<S>> {
  final AgentRuntime runtime;
  final Workflow<S> workflow;
  final String threadId;
  final ArtifactsOf<S>? artifactsOf;
  late AgentViewState<S> _value = AgentViewState(threadId: threadId);
  RunObserver? _observer;
  RunCheckpoint? _checkpoint;
  S? _data;
  List<Artifact> _savedArtifacts = const [];
  AgentControllerFailure? _commandError;
  AgentControllerFailure? _projectionError;
  bool _pending = false;
  bool _disposed = false;
  int _epoch = 0;

  AgentController({
    required this.runtime,
    required this.workflow,
    required this.threadId,
    this.artifactsOf,
  }) {
    if (threadId.isEmpty) {
      throw ArgumentError('A stable thread ID is required.');
    }
  }

  @override
  AgentViewState<S> get value => _value;
  AgentViewState<S> get state => _value;
  bool get isDisposed => _disposed;
  Future<RunCheckpoint>? get completion => _observer?.handle.done;

  static AgentController<ChatState> chat({
    required AgentRuntime runtime,
    required Workflow<ChatState> workflow,
    required String threadId,
  }) => AgentController(
    runtime: runtime,
    workflow: workflow,
    threadId: threadId,
    artifactsOf: (state) => state.artifacts,
  );

  Future<bool> start({JsonMap input = const {}}) => _command((epoch) async {
    final handle = await runtime.start(
      workflow: workflow,
      threadId: threadId,
      input: input,
    );
    _bind(handle, epoch);
  });

  Future<bool> restore() => _command((epoch) async {
    var handle = runtime.attach(threadId);
    if (handle != null) {
      _bind(handle, epoch);
      return;
    }
    final saved = await runtime.inspect(threadId);
    handle = runtime.attach(threadId);
    if (handle != null) {
      _bind(handle, epoch);
      return;
    }
    if (_disposed || epoch != _epoch) return;
    _removeObserver();
    _acceptCheckpoint(saved);
  });

  Future<bool> submitInput(PendingAgentInput pending, Object? response) =>
      _command((epoch) async {
        if (pending.threadId != threadId) {
          throw const OrchestrationException(
            'invalid_resume',
            'This input belongs to a different thread.',
          );
        }
        final handle = await runtime.resume(
          workflow: workflow,
          threadId: threadId,
          runId: pending.runId,
          interruptId: pending.request.id,
          expectedRevision: pending.revision,
          value: response,
        );
        _bind(handle, epoch);
      });

  /// Retries the saved failed node only when its workflow marks replay safe.
  Future<bool> retry() => _command((epoch) async {
    final saved = _checkpoint;
    if (saved == null) {
      throw const OrchestrationException(
        'missing_run',
        'No saved run was found.',
      );
    }
    _bind(
      await runtime.retry(
        workflow: workflow,
        threadId: threadId,
        expectedRevision: saved.revision,
      ),
      epoch,
    );
  });

  /// Host must first establish that the previous executor has stopped.
  Future<bool> recover() => _command((epoch) async {
    final saved = _checkpoint;
    if (saved == null) {
      throw const OrchestrationException(
        'missing_run',
        'No saved run was found.',
      );
    }
    final handle = await runtime.recover(
      workflow: workflow,
      threadId: threadId,
      expectedRevision: saved.revision,
    );
    _bind(handle, epoch);
  });

  Future<bool> cancel() => _command((epoch) async {
    final target = _checkpoint;
    final saved = await runtime.inspect(threadId);
    if (saved == null || target == null || target.runId != saved.runId) {
      throw const OrchestrationException(
        'stale_run',
        'Reload this thread before cancelling its run.',
      );
    }
    final cancelled = await runtime.cancel(
      threadId,
      expectedRevision: saved.revision,
    );
    if (_disposed || epoch != _epoch) return;
    _acceptCheckpoint(cancelled);
  });

  void detach() {
    _checkAlive();
    _epoch++;
    _removeObserver();
    _publish();
  }

  Future<bool> _command(Future<void> Function(int epoch) action) async {
    _checkAlive();
    if (_pending) return false;
    _pending = true;
    _commandError = null;
    final epoch = ++_epoch;
    _publish();
    try {
      await action(epoch);
      return _projectionError == null;
    } catch (error) {
      if (!_disposed && epoch == _epoch) {
        _commandError = AgentControllerFailure.from(error);
      }
      return false;
    } finally {
      _pending = false;
      if (!_disposed) _publish();
    }
  }

  void _bind(RunHandle handle, int epoch) {
    final observer = observeRun(handle);
    if (_disposed || epoch != _epoch) return;
    _removeObserver();
    _observer = observer;
    if (!observer.ended) observer.addListener(_observed);
    _acceptCheckpoint(observer.checkpoint);
  }

  void _observed() {
    if (_disposed) return;
    _acceptCheckpoint(_observer!.checkpoint);
    _publish();
  }

  void _acceptCheckpoint(RunCheckpoint? checkpoint) {
    if (identical(checkpoint, _checkpoint)) return;
    _checkpoint = checkpoint;
    _data = null;
    _savedArtifacts = const [];
    _projectionError = null;
    if (checkpoint == null) return;
    try {
      if (checkpoint.workflowId != workflow.id ||
          checkpoint.workflowVersion != workflow.version) {
        throw const OrchestrationException(
          'workflow_version',
          'This saved run needs an explicit workflow migration.',
        );
      }
      final decoded = workflow.codec.decode(checkpoint.state);
      _data = decoded;
      _savedArtifacts = List.unmodifiable(
        artifactsOf?.call(decoded) ?? const <Artifact>[],
      );
    } catch (error) {
      _projectionError = AgentControllerFailure.from(error);
    }
  }

  void _publish() {
    if (_disposed) return;
    final observer = _observer;
    final artifacts = {
      for (final artifact in _savedArtifacts) artifact.id: artifact,
      ...?observer?.artifacts,
    };
    final failure = _checkpoint?.failure;
    _value = AgentViewState(
      threadId: threadId,
      checkpoint: _checkpoint,
      data: _data,
      streamingText: observer?.streamingText ?? '',
      activeTools: observer?.activeTools.values.toList() ?? const [],
      artifacts: artifacts.values.toList(),
      isAttached: observer != null && !observer.ended,
      hasLiveRun: runtime.attach(threadId) != null,
      isCommandPending: _pending,
      error:
          _commandError ??
          _projectionError ??
          observer?.failure ??
          (failure == null
              ? null
              : AgentControllerFailure(
                  failure['code']! as String,
                  failure['message']! as String,
                )),
    );
    notifyListeners();
  }

  void _removeObserver() {
    _observer?.removeListener(_observed);
    _observer = null;
  }

  void _checkAlive() {
    if (_disposed) throw StateError('AgentController has been disposed.');
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    _removeObserver();
    super.dispose();
  }
}
