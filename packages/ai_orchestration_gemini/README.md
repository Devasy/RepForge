# ai_orchestration_gemini

An optional pure Dart `ModelProvider` for Gemini's REST `streamGenerateContent` API. It does not execute tools or own workflow state. Apps supply credentials and a model ID; the runtime owns the model/tool loop.

```dart
final provider = GeminiModelProvider(
  apiKey: apiKey,
  generationConfig: (model) => {
    'thinkingConfig': {'thinkingLevel': 'low'},
  },
  onUsage: (usage) => recordUsage(usage),
);
final runtime = AgentRuntime(store: checkpointStore, model: provider);
```

Choose a thinking configuration supported by the selected model. Configuration is a host callback so fallback requests can rebuild it for their destination model. `fallbackModel` and `onModelChanged` are optional host policy; no fallback model list is built into the reusable package.

The adapter handles fragmented UTF-8/SSE framing, one candidate, non-thought text, native tool-call IDs, full opaque model parts (including thought signatures), usage metadata and explicit finish reasons. Legacy responses without native IDs receive separate internal identities; synthesized IDs are omitted from Gemini's function responses. Assistant continuation data lives in `ModelMessage.providerData`, so checkpoint/resume preserves it. Consecutive tool results are emitted together in one user turn, with each native ID paired with its original function name.

Attachments use `{'mimeType': 'image/png', 'data': base64Image}` and become inline data. The host chooses supported model/media combinations and applies upload limits. Generated images, audio output, server tools, multiple candidates and streamed partial function arguments are unsupported; unexpected response modalities fail explicitly. Provider continuation data belongs to this adapter and should not be transferred to another provider.

Transport retries are bounded: one retry per model for transient failures, with a cancellable delay. Daily quota exhaustion, unavailable models and pre-output timeouts advance to the host's next fallback immediately; exhausted transient retries also advance. Fallback cycles are rejected. The default timeout is 15 seconds per I/O wait and the whole model request has a 90-second budget, including fallback and backoff. Hosts can configure both limits. No consumed stream or tool execution is replayed.

`ModelStatus` events describe connection, retry and fallback progress for the host UI. `onDiagnostic` receives safe metadata (model IDs, attempt counts, error codes and timing), without prompts, tool arguments, response bodies or credentials. Cancellation closes the request-owned client and interrupts waits. An injected `clientFactory` must return a fresh, independently owned client for each attempt.

`generate(modelId: ..., body: ...)` uses the same policy for a single `generateContent` response. Supplied JSON generation settings are retained while the model-dependent configuration is rebuilt after fallback. Failures expose safe codes/messages through `GeminiFailure`; credentials are sent in the API-key header, outside URLs and checkpoints. Keep the key outside workflow state.

Run `dart test` for credential-free HTTP fixtures and a complete core/model/tool loop. These tests do not call a live model.

Protocol references: [Gemini API](https://ai.google.dev/api/generate-content), [thought signatures](https://ai.google.dev/gemini-api/docs/generate-content/thought-signatures).
