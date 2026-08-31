// tool_executor.dart — Executes tool calls with event emission.
//
// Wraps ToolRegistry dispatch with AgentEvent emission so the runtime
// doesn't need to manually emit start/end events for every tool call.

import '../agent_event.dart';
import 'agent_tool.dart';
import 'tool_registry.dart';
import 'tool_result.dart';

/// Executes tools from the registry, emitting activity events.
class ToolExecutor {
  final ToolRegistry _registry;

  ToolExecutor(this._registry);

  /// Execute a tool call by name, emitting start/end events.
  ///
  /// Returns the [ToolResult] from the tool. If the tool is not found,
  /// returns an error result.
  Future<ToolResult> execute(
    String toolId,
    Map<String, Object?> args, {
    required String callId,
    void Function(AgentEvent)? emit,
  }) async {
    final tool = _registry.find(toolId);
    if (tool == null) {
      return ToolResult(data: {'error': 'Unknown tool: $toolId'});
    }

    final label = _registry.toolLabel(toolId, args);

    emit?.call(AgentToolActivity(toolId, isStart: true, label: label));
    emit?.call(AgentStatusUpdate('Fetching $label…'));

    try {
      final result = await tool.execute(
        ToolExecutionContext(args: args, callId: callId),
      );

      emit?.call(AgentToolActivity(toolId, isStart: false, label: label));

      // Forward any events the tool itself produced.
      for (final event in result.events) {
        emit?.call(event);
      }

      return result;
    } catch (e) {
      emit?.call(AgentToolActivity(toolId, isStart: false, label: label));
      emit?.call(AgentStatusUpdate('Error fetching $label'));
      return ToolResult(data: {'error': '$e'});
    }
  }
}
