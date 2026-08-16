// coach_graph.dart — Graph definition for the AI coach flow.
//
// ingress → planner → model_step ←→ execute_tools → synthesize_artifacts → complete

import '../runtime/agent_graph.dart';
import '../runtime/nodes/ingress_node.dart';
import '../runtime/nodes/planner_node.dart';
import '../runtime/nodes/model_step_node.dart';
import '../runtime/nodes/execute_tools_node.dart';
import '../runtime/nodes/synthesize_artifacts_node.dart';
import '../runtime/nodes/complete_node.dart';
import '../runtime/nodes/error_node.dart';
import '../../gemini_context_builder.dart';

/// Build the coach graph with the given user settings.
AgentGraph buildCoachGraph({
  String? userName,
  String unitLabel = 'kg',
}) =>
    AgentGraph(
      id: 'coach',
      entryNodeId: 'ingress',
      nodes: {
        'ingress': IngressNode(),
        'planner': PlannerNode(
          promptBuilder: GeminiContextBuilder.buildCoachSystemPrompt,
          userName: userName,
          unitLabel: unitLabel,
        ),
        'model_step': ModelStepNode(),
        'execute_tools': ExecuteToolsNode(),
        'synthesize_artifacts': SynthesizeArtifactsNode(),
        'complete': CompleteNode(),
        'error': ErrorNode(),
      },
    );
