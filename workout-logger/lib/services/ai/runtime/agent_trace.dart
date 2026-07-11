// agent_trace.dart — Observability model for agent runs.
//
// Every node execution, tool invocation, retry, and interrupt is recorded
// as a TraceEntry. This is the "why did the graph do this?" answer.

/// A complete trace of a single agent run.
class AgentTrace {
  final String runId;
  final List<TraceEntry> entries;

  AgentTrace(this.runId) : entries = [];

  void add(TraceEntry entry) => entries.add(entry);

  @override
  String toString() => 'AgentTrace($runId, ${entries.length} entries)';
}

/// A single entry in the run trace.
class TraceEntry {
  final DateTime at;
  final String nodeId;
  final String type; // 'enter', 'exit', 'tool_call', 'tool_result', 'error', 'interrupt', 'resume'
  final Map<String, Object?> data;

  const TraceEntry({
    required this.at,
    required this.nodeId,
    required this.type,
    this.data = const {},
  });

  factory TraceEntry.now({
    required String nodeId,
    required String type,
    Map<String, Object?> data = const {},
  }) =>
      TraceEntry(at: DateTime.now(), nodeId: nodeId, type: type, data: data);

  @override
  String toString() => 'TraceEntry($nodeId, $type)';
}
