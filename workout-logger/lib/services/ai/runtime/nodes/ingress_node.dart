// ingress_node.dart — Entry node that validates input and initializes state.

import '../../agent_event.dart';
import '../../provider/model_message.dart';
import '../agent_context.dart';
import '../agent_node.dart';
import '../agent_run_state.dart';

/// First node in every graph. Validates input, seeds the transcript with the
/// user message, and transitions to the planner node.
class IngressNode implements AgentNode {
  @override
  String get id => 'ingress';

  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    ctx.emit(const AgentStatusUpdate('Thinking…'));

    // Seed the transcript with the user message.
    final updatedState = state.copyWith(
      phase: AgentPhase.planning,
      transcript: [
        ...state.transcript,
        UserMessage(state.userMessage),
      ],
    );
    ctx.updateState(updatedState);

    return const NextNode('planner');
  }
}
