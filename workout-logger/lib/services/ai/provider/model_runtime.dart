// model_runtime.dart — Abstract provider contract for model access.
//
// This is the boundary between the agent runtime and the model provider.
// The runtime calls streamStep() for a single model pass; it owns the
// tool-call loop, retries, and multi-step execution. The provider just
// translates to/from its SDK's wire format.

import 'model_message.dart';
import 'model_step.dart';
import 'provider_metadata.dart';
import '../tools/tool_spec.dart';

/// Contract for a model provider backend (Gemini, OpenAI, etc.).
///
/// Implementations translate between our SDK-agnostic types and the
/// provider's native format. They do NOT execute tools or loop.
abstract class ModelRuntime {
  /// True once credentials have been supplied.
  bool get isConfigured;

  /// The model identifier currently in use (e.g. 'gemini-3.5-flash').
  String get currentModel;

  /// Provider capability metadata.
  ProviderMetadata get metadata;

  /// Execute a single model pass, yielding structured [ModelStep]s.
  ///
  /// The caller provides the full conversation [messages] (including any
  /// prior tool results) and the available [tools]. The provider streams
  /// text deltas, tool call intents, and a finish signal — but does NOT
  /// execute tools or loop.
  Stream<ModelStep> streamStep({
    required String systemPrompt,
    required List<ModelMessage> messages,
    required List<ToolSpec> tools,
  });
}
