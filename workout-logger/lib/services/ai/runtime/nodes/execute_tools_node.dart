// execute_tools_node.dart — Dispatches tool calls through the ToolRegistry.
//
// Processes all tool call intents from the last model step, executes them
// via ToolExecutor, and appends results to the transcript. Routes to
// await_user_input if an interrupt tool was called.

import '../../agent_event.dart';
import '../../provider/model_message.dart';
import '../../tools/tool_executor.dart';
import '../../tools/tool_metadata.dart';
import '../agent_artifact.dart';
import '../agent_context.dart';
import '../agent_interrupt.dart';
import '../agent_node.dart';
import '../agent_run_state.dart';
import '../agent_trace.dart';
import '../../../../models/models.dart';

class ExecuteToolsNode implements AgentNode {
  @override
  String get id => 'execute_tools';

  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    // Find the last assistant message to get tool call intents.
    final lastMsg = state.transcript.lastOrNull;
    if (lastMsg is! AssistantMessage || lastMsg.toolCalls.isEmpty) {
      return const NextNode('model_step');
    }

    final toolCallIntents = lastMsg.toolCalls;
    final executor = ToolExecutor(ctx.tools);
    final callResults = <ToolCallResult>[];
    final newArtifacts = <AgentArtifact>[];
    final newInvocations = <ToolInvocation>[];
    PendingQuestions? interruptPayload;

    ctx.emit(const AgentStatusUpdate('Executing tools…'));

    final updatedState = state.copyWith(
      phase: AgentPhase.executingTools,
    );
    ctx.updateState(updatedState);

    for (final intent in toolCallIntents) {
      ctx.trace.add(TraceEntry.now(
        nodeId: id,
        type: 'tool_call',
        data: {'tool': intent.toolName, 'callId': intent.callId},
      ));

      final invocation = ToolInvocation(
        toolId: intent.toolName,
        label: ctx.tools.toolLabel(intent.toolName, intent.args),
        args: intent.args,
        startedAt: DateTime.now(),
      );

      final result = await executor.execute(
        intent.toolName,
        intent.args,
        callId: intent.callId,
        emit: ctx.emit,
      );

      callResults.add(ToolCallResult(
        callId: intent.callId,
        toolName: intent.toolName,
        data: result.data,
      ));

      newArtifacts.addAll(result.artifacts);
      newInvocations.add(invocation.complete(result.data));

      ctx.trace.add(TraceEntry.now(
        nodeId: id,
        type: 'tool_result',
        data: {
          'tool': intent.toolName,
          'callId': intent.callId,
          'dataKeys': result.data.keys.toList(),
        },
      ));

      // Check if this was an interrupt tool.
      final tool = ctx.tools.find(intent.toolName);
      if (tool != null && tool.metadata.kind == ToolKind.interrupt) {
        // Extract PendingQuestions from QuestionFormArtifact.
        for (final artifact in result.artifacts) {
          if (artifact is QuestionFormArtifact) {
            interruptPayload = artifact.questions;
          }
        }
      }
    }

    // Append tool results to transcript.
    final stateWithResults = state.copyWith(
      transcript: [
        ...state.transcript,
        ToolResultMessage(callResults),
      ],
      toolCalls: [...state.toolCalls, ...newInvocations],
      artifacts: [...state.artifacts, ...newArtifacts],
      phase: AgentPhase.executingTools,
    );
    ctx.updateState(stateWithResults);

    // Emit artifact-ready events.
    for (final artifact in newArtifacts) {
      ctx.emit(AgentArtifactReady(artifact));
    }

    // If an interrupt tool was called, suspend the run.
    if (interruptPayload != null) {
      return InterruptRun(AwaitUserQuestions(interruptPayload));
    }

    // Otherwise, go back to model_step for the model to process tool results.
    return const NextNode('model_step');
  }
}
