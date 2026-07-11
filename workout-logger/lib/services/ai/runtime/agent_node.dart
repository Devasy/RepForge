// agent_node.dart — Abstract node and result types for agent graphs.
//
// Each node in the graph implements execute() and returns one of:
// - NextNode(id) to transition to another node
// - CompleteRun() to end the run successfully
// - InterruptRun(interrupt) to suspend for human input

import 'agent_context.dart';
import 'agent_interrupt.dart';
import 'agent_run_state.dart';

/// Abstract base for all nodes in an agent graph.
abstract class AgentNode {
  /// Unique identifier for this node within its graph.
  String get id;

  /// Execute this node's logic and return the next transition.
  ///
  /// Nodes may read/update [state] via [ctx.updateState], emit events
  /// via [ctx.emit], and call the model or tools via [ctx].
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state);
}

/// Sealed result type: what should the runtime do after a node executes?
sealed class AgentNodeResult {
  const AgentNodeResult();
}

/// Transition to another node.
class NextNode extends AgentNodeResult {
  final String nodeId;
  const NextNode(this.nodeId);

  @override
  String toString() => 'NextNode($nodeId)';
}

/// The run completed successfully.
class CompleteRun extends AgentNodeResult {
  const CompleteRun();

  @override
  String toString() => 'CompleteRun()';
}

/// The run is suspended awaiting human input.
class InterruptRun extends AgentNodeResult {
  final AgentInterrupt interrupt;
  const InterruptRun(this.interrupt);

  @override
  String toString() => 'InterruptRun($interrupt)';
}
