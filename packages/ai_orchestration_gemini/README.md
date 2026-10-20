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

Transport retries are bounded and apply only to rejected HTTP requests (429/5xx) before response output. The adapter honors bounded server retry delays and optional daily-quota fallback. It never retries a consumed stream or replays tools. Cancellation closes the request-owned client and interrupts waits; timeout defaults to 60 seconds per I/O wait. An injected `clientFactory` must return a fresh, independently owned client for each attempt. Failures expose safe codes/messages through `GeminiFailure`; credentials are sent in the API-key header, not URLs or checkpoints. Keep the key outside workflow state.

Run `dart test` for credential-free HTTP fixtures and a complete core/model/tool loop. These tests do not call a live model.

Protocol references: [Gemini API](https://ai.google.dev/api/generate-content), [thought signatures](https://ai.google.dev/gemini-api/docs/generate-content/thought-signatures).
