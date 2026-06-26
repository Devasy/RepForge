// agent_event.dart — Typed event stream for the agent orchestration layer.
//
// The AgentOrchestrator yields these events so consumers (ViewModels, UI) can
// react to each phase: streamed text, status updates, tool activity, retry
// waits, errors, and (future) chart data for visualization tools.

/// Sealed base for all events the agent orchestrator emits.
sealed class AgentEvent {
  const AgentEvent();
}

/// A chunk of streamed text from the model's reply.
class AgentTextChunk extends AgentEvent {
  final String text;
  const AgentTextChunk(this.text);

  @override
  String toString() => 'AgentTextChunk("$text")';
}

/// Human-readable status update shown in the UI while the agent is working
/// (e.g. "Fetching bench press data…", "Analyzing routine performance…").
class AgentStatusUpdate extends AgentEvent {
  final String status;
  const AgentStatusUpdate(this.status);

  @override
  String toString() => 'AgentStatusUpdate("$status")';
}

/// Indicates a tool call starting or finishing. The UI can render a list of
/// active tools so the user sees exactly where their answer is being built.
class AgentToolActivity extends AgentEvent {
  final String toolName;

  /// Human-readable label, e.g. "Bench Press performance" derived from args.
  final String? label;
  final bool isStart;

  const AgentToolActivity(
    this.toolName, {
    required this.isStart,
    this.label,
  });

  @override
  String toString() =>
      'AgentToolActivity($toolName, ${isStart ? "start" : "end"})';
}

/// Emitted when a rate limit (429) or transient error triggers a retry wait.
/// The UI shows a countdown: "Rate limit reached — retrying in 12s…"
class AgentRetryWait extends AgentEvent {
  final Duration remaining;
  final String reason;
  const AgentRetryWait(this.remaining, this.reason);

  @override
  String toString() =>
      'AgentRetryWait(${remaining.inSeconds}s, "$reason")';
}

/// An error the orchestrator could not recover from.
class AgentError extends AgentEvent {
  final String message;
  final bool isRetryable;
  const AgentError(this.message, {this.isRetryable = false});

  @override
  String toString() => 'AgentError("$message", retryable=$isRetryable)';
}

/// Future: a tool returns structured chart/graph data for inline visualization.
/// The spec follows a simple {type, title, labels, series} shape so a future
/// ChartRenderer widget can consume it without knowing which tool produced it.
class AgentChartData extends AgentEvent {
  final Map<String, Object?> chartSpec;
  const AgentChartData(this.chartSpec);

  @override
  String toString() => 'AgentChartData(${chartSpec.keys})';
}
