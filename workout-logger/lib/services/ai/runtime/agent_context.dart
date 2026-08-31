// agent_context.dart — Execution context passed to every node.
//
// Provides access to the model runtime, tool registry, event emitting,
// state updates, and policy configuration. Nodes use this instead of
// holding direct references to services.

import '../agent_event.dart';
import '../provider/model_runtime.dart';
import '../tools/tool_registry.dart';
import 'agent_policies.dart';
import 'agent_run_state.dart';
import 'agent_trace.dart';

/// Everything a node needs to do its job.
class AgentContext {
  /// The model provider for streaming model passes.
  final ModelRuntime model;

  /// Registry of available tools for this run.
  final ToolRegistry tools;

  /// Emit an event to the UI / consumer.
  final void Function(AgentEvent event) emit;

  /// Update the run state (called by nodes after mutations).
  final void Function(AgentRunState state) updateState;

  /// Policy constraints for this run.
  final AgentPolicies policies;

  /// The run trace for observability.
  final AgentTrace trace;

  const AgentContext({
    required this.model,
    required this.tools,
    required this.emit,
    required this.updateState,
    required this.policies,
    required this.trace,
  });
}
