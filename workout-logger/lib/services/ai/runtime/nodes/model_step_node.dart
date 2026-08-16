// model_step_node.dart — Calls the model and routes based on its response.
//
// This is the core model interaction node. It:
// 1. Calls ModelRuntime.streamStep() with current transcript + tools
// 2. Emits AgentTextChunk for text deltas
// 3. Captures tool call intents
// 4. Transitions to execute_tools or synthesize_artifacts

import '../../agent_event.dart';
import '../../provider/model_message.dart';
import '../../provider/model_step.dart';
import '../agent_context.dart';
import '../agent_node.dart';
import '../agent_run_state.dart';
import '../agent_trace.dart';

class ModelStepNode implements AgentNode {
  @override
  String get id => 'model_step';

  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    final systemPrompt =
        state.workingMemory['systemPrompt'] as String? ?? '';

    // Check round limits.
    if (state.round >= ctx.policies.maxModelSteps) {
      ctx.emit(const AgentStatusUpdate('Reached maximum steps'));
      return const NextNode('complete');
    }

    ctx.trace.add(TraceEntry.now(
      nodeId: id,
      type: 'enter',
      data: {'round': state.round},
    ));

    final textBuffer = StringBuffer();
    final toolCalls = <ToolCallIntent>[];
    final rawModelParts = <Map<String, dynamic>>[];
    String finishReason = 'stop';

    try {
      await for (final step in ctx.model.streamStep(
        systemPrompt: systemPrompt,
        messages: state.transcript,
        tools: ctx.tools.specs,
      )) {
        switch (step) {
          case ModelTextDelta(:final text):
            textBuffer.write(text);
            ctx.emit(AgentTextChunk(text));

          case ModelToolCall(:final callId, :final toolName, :final args):
            toolCalls.add(ToolCallIntent(
              callId: callId,
              toolName: toolName,
              args: args,
            ));

          case ModelRawPart(:final part):
            rawModelParts.add(part);

          case ModelFinish(:final reason):
            finishReason = reason;
        }
      }
    } catch (e) {
      ctx.emit(AgentError('Model error: $e'));
      return const NextNode('error');
    }

    final assistantText = textBuffer.toString();

    // Build the assistant message with tool calls (if any) and raw parts.
    final assistantMsg = AssistantMessage(
      assistantText,
      toolCalls: toolCalls,
      rawParts: rawModelParts.isNotEmpty ? rawModelParts : null,
    );

    // Update state with new transcript entry.
    final updatedState = state.copyWith(
      transcript: [...state.transcript, assistantMsg],
      round: state.round + 1,
    );
    ctx.updateState(updatedState);

    ctx.trace.add(TraceEntry.now(
      nodeId: id,
      type: 'exit',
      data: {
        'textLength': assistantText.length,
        'toolCallCount': toolCalls.length,
        'finishReason': finishReason,
      },
    ));

    // Route based on what the model did.
    if (toolCalls.isNotEmpty) {
      return const NextNode('execute_tools');
    }

    // Check if the model should have used tools but didn't.
    if (_queryRequiresTools(state.userMessage) &&
        state.round <= 1 &&
        state.round < ctx.policies.maxModelSteps - 1) {
      // Re-prompt: add feedback and go back to model_step.
      ctx.emit(const AgentStatusUpdate(
          'Analyzing further with database tools…'));
      ctx.emit(const AgentTextChunk('\n\n'));

      final feedback = UserMessage(
        'You are answering a query about the user\'s progress or history, '
        'but you did not query their actual logged workouts. Please use the '
        'relevant tools (e.g. get_exercise_performance, get_workouts_in_range, '
        'get_personal_records) to retrieve the user\'s real data before answering.',
      );

      final reproState = updatedState.copyWith(
        transcript: [...updatedState.transcript, feedback],
      );
      ctx.updateState(reproState);

      return const NextNode('model_step');
    }

    // Final text answer — synthesize artifacts.
    return const NextNode('synthesize_artifacts');
  }

  /// Heuristic: does this user message likely need tool data?
  /// Ported from AgentOrchestrator._queryRequiresTools.
  bool _queryRequiresTools(String query) {
    final lower = query.toLowerCase();
    const keywords = [
      'progress', 'plateau', 'history', 'performance', 'record', 'goal',
      'compare', 'bench', 'squat', 'deadlift', 'weight', 'volume',
      'routine', 'recovery', 'how am i doing', 'what did i do', 'optimize',
    ];
    return keywords.any((k) => lower.contains(k));
  }
}
