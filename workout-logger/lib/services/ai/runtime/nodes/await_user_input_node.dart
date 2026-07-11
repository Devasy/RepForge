// await_user_input_node.dart — Suspend node for human-in-the-loop.
//
// This node is NOT reached via normal graph traversal. Instead, when
// ExecuteToolsNode detects an interrupt tool, it returns InterruptRun.
// The runtime suspends the run and emits AgentInterrupted.
//
// When runtime.resume() is called, this node processes the user's response
// and transitions back to model_step.

import '../../agent_event.dart';
import '../../provider/model_message.dart';
import '../agent_context.dart';
import '../agent_node.dart';
import '../agent_run_state.dart';
import '../agent_trace.dart';

class AwaitUserInputNode implements AgentNode {
  @override
  String get id => 'await_user_input';

  /// Called by the runtime after resume() provides user input.
  ///
  /// The [state] at this point has the user's response in workingMemory
  /// under 'resumePayload', set by the runtime.
  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    final payload =
        state.workingMemory['resumePayload'] as Map<String, Object?>?;

    ctx.trace.add(TraceEntry.now(
      nodeId: id,
      type: 'resume',
      data: {'hasPayload': payload != null},
    ));

    if (payload == null) {
      ctx.emit(const AgentError('No user response received'));
      return const NextNode('error');
    }

    // Feed the user's answers back as a tool result message so the model
    // can see them and continue.
    final answers = payload['answers'] as List<Object?>? ?? [];
    final answerData = <String, Object?>{'answers': answers};

    final updatedState = state.copyWith(
      phase: AgentPhase.modelStep,
      transcript: [
        ...state.transcript,
        ToolResultMessage([
          ToolCallResult(
            callId: 'user_response',
            toolName: 'ask_user_questions',
            data: answerData,
          ),
        ]),
      ],
      workingMemory: {
        ...state.workingMemory,
        'resumePayload': null, // Clear
      },
    );
    ctx.updateState(updatedState);

    ctx.emit(const AgentStatusUpdate('Processing your answers…'));

    return const NextNode('model_step');
  }
}
