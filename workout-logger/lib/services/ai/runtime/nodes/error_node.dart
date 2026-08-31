// error_node.dart — Terminal node for error states.

import '../../agent_event.dart';
import '../agent_context.dart';
import '../agent_node.dart';
import '../agent_run_state.dart';
import '../agent_trace.dart';

class ErrorNode implements AgentNode {
  @override
  String get id => 'error';

  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    final errorMsg = state.workingMemory['error'] as String? ?? 'Unknown error';

    ctx.trace.add(TraceEntry.now(
      nodeId: id,
      type: 'error',
      data: {'message': errorMsg},
    ));

    ctx.emit(AgentError(errorMsg));

    final updatedState = state.copyWith(
      phase: AgentPhase.error,
      isComplete: true,
    );
    ctx.updateState(updatedState);

    return const CompleteRun();
  }
}
