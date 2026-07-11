// agent_run_state.dart — Mutable state carried through an agent graph execution.
//
// Each node reads and updates this state. The runtime manages transitions
// and emits events based on state changes.

import '../provider/model_message.dart';
import 'agent_artifact.dart';

/// The current phase of an agent run.
enum AgentPhase {
  idle,
  planning,
  modelStep,
  executingTools,
  synthesizing,
  interrupted,
  complete,
  error,
}

/// A record of a tool invocation within a run (for tracing/display).
class ToolInvocation {
  final String toolId;
  final String? label;
  final Map<String, Object?> args;
  final Map<String, Object?>? result;
  final DateTime startedAt;
  final DateTime? completedAt;

  const ToolInvocation({
    required this.toolId,
    this.label,
    required this.args,
    this.result,
    required this.startedAt,
    this.completedAt,
  });

  ToolInvocation complete(Map<String, Object?> result) => ToolInvocation(
        toolId: toolId,
        label: label,
        args: args,
        result: result,
        startedAt: startedAt,
        completedAt: DateTime.now(),
      );
}

/// The mutable state of a single agent run, threaded through every node.
class AgentRunState {
  final String runId;
  final String graphId;
  final String userMessage;
  final List<ModelMessage> transcript;
  final List<ToolInvocation> toolCalls;
  final List<AgentArtifact> artifacts;
  final String? statusText;
  final Set<String> activeToolIds;
  final Map<String, Object?> workingMemory;
  final AgentPhase phase;
  final int round;
  final bool isComplete;

  const AgentRunState({
    required this.runId,
    required this.graphId,
    required this.userMessage,
    this.transcript = const [],
    this.toolCalls = const [],
    this.artifacts = const [],
    this.workingMemory = const {},
    this.activeToolIds = const {},
    this.statusText,
    this.phase = AgentPhase.idle,
    this.round = 0,
    this.isComplete = false,
  });

  AgentRunState copyWith({
    String? runId,
    String? graphId,
    String? userMessage,
    List<ModelMessage>? transcript,
    List<ToolInvocation>? toolCalls,
    List<AgentArtifact>? artifacts,
    String? statusText,
    Set<String>? activeToolIds,
    Map<String, Object?>? workingMemory,
    AgentPhase? phase,
    int? round,
    bool? isComplete,
  }) =>
      AgentRunState(
        runId: runId ?? this.runId,
        graphId: graphId ?? this.graphId,
        userMessage: userMessage ?? this.userMessage,
        transcript: transcript ?? this.transcript,
        toolCalls: toolCalls ?? this.toolCalls,
        artifacts: artifacts ?? this.artifacts,
        statusText: statusText ?? this.statusText,
        activeToolIds: activeToolIds ?? this.activeToolIds,
        workingMemory: workingMemory ?? this.workingMemory,
        phase: phase ?? this.phase,
        round: round ?? this.round,
        isComplete: isComplete ?? this.isComplete,
      );

  @override
  String toString() => 'AgentRunState($runId, phase=$phase, round=$round)';
}
