// model_message.dart — SDK-agnostic message types for model conversations.
//
// Replaces direct use of google_generative_ai's Content type so the runtime
// and tools never depend on a specific provider SDK. The GeminiProviderAdapter
// translates these to/from the Gemini wire format.

/// Sealed base for all messages in a model conversation.
sealed class ModelMessage {
  const ModelMessage();
}

/// A message from the user.
class UserMessage extends ModelMessage {
  final String text;
  const UserMessage(this.text);

  @override
  String toString() => 'UserMessage("${text.length > 40 ? '${text.substring(0, 40)}…' : text}")';
}

/// A message from the model (assistant).
class AssistantMessage extends ModelMessage {
  final String text;
  final List<ToolCallIntent> toolCalls;

  /// Raw parts preserved for Gemini's thought_signature round-trip.
  /// Only populated by the Gemini provider adapter; other providers leave null.
  final List<Map<String, dynamic>>? rawParts;

  const AssistantMessage(
    this.text, {
    this.toolCalls = const [],
    this.rawParts,
  });

  @override
  String toString() => 'AssistantMessage("${text.length > 40 ? '${text.substring(0, 40)}…' : text}")';
}

/// Tool results being fed back to the model after execution.
class ToolResultMessage extends ModelMessage {
  final List<ToolCallResult> results;
  const ToolResultMessage(this.results);

  @override
  String toString() => 'ToolResultMessage(${results.length} results)';
}

/// A tool call the model intends to make (captured from ModelToolCall steps).
class ToolCallIntent {
  final String callId;
  final String toolName;
  final Map<String, Object?> args;

  const ToolCallIntent({
    required this.callId,
    required this.toolName,
    required this.args,
  });

  @override
  String toString() => 'ToolCallIntent($toolName, $callId)';
}

/// The result of executing a single tool call.
class ToolCallResult {
  final String callId;
  final String toolName;
  final Map<String, Object?> data;

  const ToolCallResult({
    required this.callId,
    required this.toolName,
    required this.data,
  });

  @override
  String toString() => 'ToolCallResult($toolName, $callId)';
}
