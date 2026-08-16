// optimizer_graph.dart — Graph definition for the routine optimizer flow.
//
// Like the coach graph but includes the await_user_input node for
// human-in-the-loop question/answer flows.
//
// ingress → planner → model_step ←→ execute_tools → synthesize_artifacts → complete
//                                 ↘ await_user_input ↗

import '../runtime/agent_graph.dart';
import '../runtime/nodes/ingress_node.dart';
import '../runtime/nodes/planner_node.dart';
import '../runtime/nodes/model_step_node.dart';
import '../runtime/nodes/execute_tools_node.dart';
import '../runtime/nodes/await_user_input_node.dart';
import '../runtime/nodes/synthesize_artifacts_node.dart';
import '../runtime/nodes/complete_node.dart';
import '../runtime/nodes/error_node.dart';
import '../../gemini_context_builder.dart';

/// Build the optimizer graph with the given user settings.
AgentGraph buildOptimizerGraph({
  String? userName,
  String unitLabel = 'kg',
}) =>
    AgentGraph(
      id: 'optimizer',
      entryNodeId: 'ingress',
      nodes: {
        'ingress': IngressNode(),
        'planner': PlannerNode(
          promptBuilder: GeminiContextBuilder.buildOptimizerSystemPrompt,
          userName: userName,
          unitLabel: unitLabel,
        ),
        'model_step': ModelStepNode(),
        'execute_tools': ExecuteToolsNode(),
        'await_user_input': AwaitUserInputNode(),
        'synthesize_artifacts': SynthesizeArtifactsNode(),
        'complete': CompleteNode(),
        'error': ErrorNode(),
      },
    );
