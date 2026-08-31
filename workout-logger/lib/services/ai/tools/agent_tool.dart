// agent_tool.dart — Abstract contract for self-describing agent tools.
//
// Each tool carries its own schema (ToolSpec), metadata (ToolMetadata),
// and execution logic. The ToolRegistry collects them; the runtime
// dispatches through the registry.

import 'tool_metadata.dart';
import 'tool_result.dart';
import 'tool_spec.dart';

/// Context passed to a tool's execute method.
class ToolExecutionContext {
  /// The arguments the model passed to this tool call.
  final Map<String, Object?> args;

  /// Unique call ID for correlating with the model's tool_call intent.
  final String callId;

  const ToolExecutionContext({
    required this.args,
    required this.callId,
  });
}

/// Contract for a self-describing, executable agent tool.
abstract class AgentTool {
  /// Unique tool identifier (matches the function name the model calls).
  String get id;

  /// Rich metadata for display, routing, and tracing.
  ToolMetadata get metadata;

  /// SDK-agnostic schema declaration sent to the model.
  ToolSpec get spec;

  /// Execute this tool with the given context and return a typed result.
  Future<ToolResult> execute(ToolExecutionContext ctx);
}
