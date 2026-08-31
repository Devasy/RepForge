// tool_result.dart — Typed result from tool execution.
//
// Tools return structured data, optional artifacts (charts, tables), and
// optional events (status updates) so the runtime can feed data back to
// the model and emit UI events in one pass.

import '../agent_event.dart';
import '../runtime/agent_artifact.dart';

/// The result of executing an [AgentTool].
class ToolResult {
  /// JSON-serializable data to feed back to the model as the function response.
  final Map<String, Object?> data;

  /// Typed artifacts produced by this tool (e.g. a ChartArtifact).
  final List<AgentArtifact> artifacts;

  /// Events to emit to the UI during/after tool execution.
  final List<AgentEvent> events;

  const ToolResult({
    this.data = const {},
    this.artifacts = const [],
    this.events = const [],
  });

  @override
  String toString() => 'ToolResult(${data.keys}, ${artifacts.length} artifacts)';
}
