// synthesize_artifacts_node.dart — Converts tool outputs into typed artifacts.
//
// Scans the last tool results for chart-worthy data and produces
// AgentArtifacts. For now, passes through; future versions can auto-detect
// chart-worthy data from tool outputs.

import '../agent_context.dart';
import '../agent_node.dart';
import '../agent_run_state.dart';
import '../agent_trace.dart';

class SynthesizeArtifactsNode implements AgentNode {
  @override
  String get id => 'synthesize_artifacts';

  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    ctx.trace.add(TraceEntry.now(
      nodeId: id,
      type: 'enter',
      data: {'artifactCount': state.artifacts.length},
    ));

    final updatedState = state.copyWith(
      phase: AgentPhase.synthesizing,
    );
    ctx.updateState(updatedState);

    // Future: auto-detect chart-worthy data from tool results.
    // For now, artifacts are produced directly by tools (ShowGraphTool, etc.)

    ctx.trace.add(TraceEntry.now(
      nodeId: id,
      type: 'exit',
      data: {'artifactCount': state.artifacts.length},
    ));

    return const NextNode('complete');
  }
}
