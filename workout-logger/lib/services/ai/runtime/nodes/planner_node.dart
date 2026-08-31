// planner_node.dart — Decides tool availability and system prompt for the run.

import '../../agent_event.dart';
import '../agent_context.dart';
import '../agent_node.dart';
import '../agent_run_state.dart';

/// Planning node. Sets up the system prompt, decides which tools are
/// active, and seeds working memory with run-specific context.
///
/// The [promptBuilder] function is injected so the same PlannerNode class
/// works for both the coach and optimizer graphs.
class PlannerNode implements AgentNode {
  final String Function({String? userName, String unitLabel}) promptBuilder;
  final String? userName;
  final String unitLabel;

  PlannerNode({
    required this.promptBuilder,
    this.userName,
    this.unitLabel = 'kg',
  });

  @override
  String get id => 'planner';

  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    final systemPrompt = promptBuilder(
      userName: userName,
      unitLabel: unitLabel,
    );

    // Store the system prompt and tool list in working memory so
    // the ModelStepNode can access them.
    final updatedState = state.copyWith(
      phase: AgentPhase.modelStep,
      workingMemory: {
        ...state.workingMemory,
        'systemPrompt': systemPrompt,
        'activeToolIds': ctx.tools.ids.toSet(),
      },
      activeToolIds: ctx.tools.ids.toSet(),
    );
    ctx.updateState(updatedState);

    ctx.emit(const AgentStatusUpdate('Planning response…'));

    return const NextNode('model_step');
  }
}
