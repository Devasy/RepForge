# Reusable AI orchestration

This is the first implementation slice from the orchestration review. These packages are independent of RepForge's models, prompts, UI and database schema.

| Package | Implemented |
| --- | --- |
| `ai_orchestration` | Pure Dart graph coordinator, typed state updates, provider port, model/tool loop, schema validation, host tool policy, correlated events, interrupts, cancellation, execution limits and checkpoint port. |
| `ai_orchestration_sqlite` | Persistent SQLite checkpoints, revision checks, transaction-scoped operation deduplication, curated schema descriptions and named parameterized read tools. |
| `ai_orchestration_flutter` | Typed observable controller, attach/restore/detach lifecycle, input submission, artifact renderer registry and optional approval widgets. |

All packages are private `0.1.0` packages while the API settles. They inherit this repository's Apache-2.0 license. They can be used through path dependencies; only the Flutter bridge requires Flutter.

## Verify independently

Run in each pure Dart package:

```sh
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

For `ai_orchestration_flutter`, use `flutter pub get`, `flutter analyze --no-pub --fatal-infos` and `flutter test --no-pub`. Its widget tests include a full lifecycle/approval demo.

Run the credential-free examples:

```sh
# From ai_orchestration/
dart run example/expense_agent.dart
# From ai_orchestration_sqlite/
dart run example/task_assistant.dart
```

The expense example suspends for input and continues through a new runtime instance. The task example queries a real SQLite database and persists execution state. Their providers are deliberately scripted for deterministic examples. They demonstrate two domains using the same engine; they do not evaluate a live language model.

## Next implementation slices

1. Implement a Gemini adapter against `ModelProvider`, preserving native IDs, finish reasons, opaque continuation data, multimodal payloads, usage and typed failures. Keep transport retries inside that adapter and scoped to an individual request.
2. Adopt the packages in RepForge's current coach, then migrate the optimizer to an explicit application workflow. Preserve existing health/SQL tools, A2UI, attachments, settings and failure handling.
3. Add richer SQLite query planning only with driver-specific resource controls. The current query tools accept application-owned SQL templates, not arbitrary generated SQL. SQLite data access remains an ordinary registered tool; runtime checkpoint storage is a separate responsibility.

The Flutter bridge is implemented, but the existing app is not wired to these packages yet. Its screens and behavior remain unchanged in this slice.
