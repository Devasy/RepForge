// model_step.dart — Structured output from a single model pass.
//
// The model runtime yields these steps so the agent runtime can react to each
// phase: streamed text deltas, tool call intents, and finish signals.
// This is the boundary between "what the model said" and "what we do about it."

/// Sealed base for all steps a single model pass can produce.
sealed class ModelStep {
  const ModelStep();
}

/// A chunk of streamed text from the model's reply.
class ModelTextDelta extends ModelStep {
  final String text;
  const ModelTextDelta(this.text);

  @override
  String toString() => 'ModelTextDelta("$text")';
}

/// The model wants to call a tool. Multiple tool calls may arrive in one pass.
class ModelToolCall extends ModelStep {
  final String callId;
  final String toolName;
  final Map<String, Object?> args;

  const ModelToolCall({
    required this.callId,
    required this.toolName,
    required this.args,
  });

  @override
  String toString() => 'ModelToolCall($toolName, $callId)';
}

/// The model has finished this pass.
class ModelFinish extends ModelStep {
  /// Why the model stopped: 'stop', 'tool_calls', 'max_tokens', 'safety'.
  final String reason;
  const ModelFinish(this.reason);

  @override
  String toString() => 'ModelFinish($reason)';
}

/// A raw part from the model's response, preserved for history round-tripping.
class ModelRawPart extends ModelStep {
  final Map<String, dynamic> part;
  const ModelRawPart(this.part);

  @override
  String toString() => 'ModelRawPart(keys: ${part.keys.join(', ')})';
}
