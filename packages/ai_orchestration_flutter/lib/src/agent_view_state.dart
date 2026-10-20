import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:flutter/foundation.dart';

@immutable
class AgentControllerFailure {
  final String code;
  final String message;
  const AgentControllerFailure(this.code, this.message);

  factory AgentControllerFailure.from(Object error) => switch (error) {
    OrchestrationException(:final code, :final message) =>
      AgentControllerFailure(code, message),
    ArgumentError() || FormatException() => const AgentControllerFailure(
      'invalid_input',
      'The supplied input or workflow state is invalid.',
    ),
    _ => const AgentControllerFailure(
      'bridge_failed',
      'The run could not be loaded or updated. Please try again.',
    ),
  };
}

@immutable
class PendingAgentInput {
  final String threadId;
  final String runId;
  final int revision;
  final InputRequest request;
  const PendingAgentInput({
    required this.threadId,
    required this.runId,
    required this.revision,
    required this.request,
  });
}

@immutable
class ActiveAgentTool {
  final String callId;
  final String name;
  const ActiveAgentTool({required this.callId, required this.name});
}

@immutable
class AgentViewState<S> {
  final String threadId;
  final RunCheckpoint? checkpoint;
  final S? data;
  final String streamingText;
  final String statusText;
  final List<ActiveAgentTool> activeTools;
  final List<Artifact> artifacts;
  final bool isAttached;
  final bool hasLiveRun;
  final bool isCommandPending;
  final AgentControllerFailure? error;
  AgentViewState({
    required this.threadId,
    this.checkpoint,
    this.data,
    this.streamingText = '',
    this.statusText = '',
    List<ActiveAgentTool> activeTools = const [],
    List<Artifact> artifacts = const [],
    this.isAttached = false,
    this.hasLiveRun = false,
    this.isCommandPending = false,
    this.error,
  }) : activeTools = List.unmodifiable(activeTools),
       artifacts = List.unmodifiable(artifacts);

  RunStatus? get status => checkpoint?.status;
  bool get isRunning => status == RunStatus.running;
  bool get needsRecovery =>
      status == RunStatus.running && !hasLiveRun && !isCommandPending;
  bool get canStart =>
      !isCommandPending &&
      status != RunStatus.running &&
      status != RunStatus.suspended;
  PendingAgentInput? get pendingInput {
    final saved = checkpoint;
    final request = saved?.interrupt;
    if (saved == null ||
        saved.status != RunStatus.suspended ||
        request == null) {
      return null;
    }
    return PendingAgentInput(
      threadId: saved.threadId,
      runId: saved.runId,
      revision: saved.revision,
      request: request,
    );
  }
}
