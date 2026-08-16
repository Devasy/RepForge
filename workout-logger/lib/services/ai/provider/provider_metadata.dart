// provider_metadata.dart — Capability metadata for a model provider.
//
// Lets the runtime query what a provider supports without coupling to
// a specific SDK. Used by the planner node to decide tool strategies.

/// Describes the capabilities and identity of a model provider.
class ProviderMetadata {
  /// Provider identifier, e.g. 'gemini', 'openai', 'anthropic'.
  final String providerId;

  /// Specific model identifier, e.g. 'gemini-3.5-flash'.
  final String modelId;

  /// Whether this provider supports tool/function calling.
  final bool supportsToolCalling;

  /// Whether this provider supports streaming responses.
  final bool supportsStreaming;

  /// Maximum output tokens the model can produce, if known.
  final int? maxOutputTokens;

  const ProviderMetadata({
    required this.providerId,
    required this.modelId,
    this.supportsToolCalling = true,
    this.supportsStreaming = true,
    this.maxOutputTokens,
  });

  @override
  String toString() => 'ProviderMetadata($providerId/$modelId)';
}
