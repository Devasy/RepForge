// agent_policies.dart — Configurable policies for the agent runtime.
//
// Guards against runaway loops, excessive model calls, and hung runs.

/// Policy configuration for an agent run.
class AgentPolicies {
  /// Maximum number of tool-execution rounds before forcing a final answer.
  final int maxToolRounds;

  /// Maximum number of model step calls in a single run.
  final int maxModelSteps;

  /// Overall timeout for a single run (null = no timeout).
  final Duration? runTimeout;

  const AgentPolicies({
    this.maxToolRounds = 5,
    this.maxModelSteps = 10,
    this.runTimeout,
  });

  @override
  String toString() =>
      'AgentPolicies(maxToolRounds=$maxToolRounds, maxModelSteps=$maxModelSteps)';
}
