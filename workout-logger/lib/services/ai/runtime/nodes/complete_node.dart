// complete_node.dart — Terminal node that marks the run as complete.

import '../agent_context.dart';
import '../agent_node.dart';
import '../agent_run_state.dart';
import '../agent_trace.dart';

class CompleteNode implements AgentNode {
  @override
  String get id => 'complete';

  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    ctx.trace.add(TraceEntry.now(nodeId: id, type: 'complete'));

    final updatedState = state.copyWith(
      phase: AgentPhase.complete,
      isComplete: true,
    );
    ctx.updateState(updatedState);

    return const CompleteRun();
  }
}
