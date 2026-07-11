// tool_registry.dart — Registry for discovering and dispatching agent tools.
//
// Collects all available tools, provides their specs to the model, and
// resolves tool calls by name. The runtime uses this instead of hard-coding
// tool knowledge.

import 'agent_tool.dart';
import 'tool_spec.dart';

/// A registry of [AgentTool]s available for a run.
class ToolRegistry {
  final Map<String, AgentTool> _tools;

  ToolRegistry(Iterable<AgentTool> tools)
      : _tools = {for (final t in tools) t.id: t};

  /// Empty registry (no tools available).
  const ToolRegistry.empty() : _tools = const {};

  /// All tool specs, for passing to the model.
  List<ToolSpec> get specs => _tools.values.map((t) => t.spec).toList();

  /// All registered tool IDs.
  Iterable<String> get ids => _tools.keys;

  /// All registered tools.
  Iterable<AgentTool> get tools => _tools.values;

  /// Number of registered tools.
  int get length => _tools.length;

  /// Whether a tool with [id] is registered.
  bool has(String id) => _tools.containsKey(id);

  /// Look up a tool by id, or null if not found.
  AgentTool? find(String id) => _tools[id];

  /// Look up a tool by id; throws if not found.
  AgentTool require(String id) {
    final tool = _tools[id];
    if (tool == null) {
      throw StateError('ToolRegistry: no tool registered with id "$id"');
    }
    return tool;
  }

  /// Generate a display label for a tool call, using tool metadata
  /// and the call arguments.
  String toolLabel(String toolId, Map<String, Object?> args) {
    final tool = _tools[toolId];
    if (tool == null) return toolId;

    // Use the progress label template if available.
    final template = tool.metadata.progressLabel;
    if (template != null) {
      var label = template;
      for (final entry in args.entries) {
        label = label.replaceAll('{${entry.key}}', '${entry.value}');
      }
      return label;
    }

    return tool.metadata.displayName;
  }
}
