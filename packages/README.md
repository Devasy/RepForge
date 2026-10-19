# Reusable AI orchestration

This is the first implementation slice from the orchestration review. These packages are independent of RepForge's models, prompts, UI and database schema.

| Package | Implemented |
| --- | --- |
| `ai_orchestration` | Pure Dart graph coordinator, typed state updates, provider port, model/tool loop, schema validation, host tool policy, correlated events, interrupts, cancellation, execution limits and checkpoint port. |
| `ai_orchestration_sqlite` | Persistent SQLite checkpoints, revision checks, transaction-scoped operation deduplication, curated schema descriptions and named parameterized read tools. |
| `ai_orchestration_flutter` | Typed observable controller, attach/restore/detach lifecycle, input submission, artifact renderer registry and optional approval widgets. |
| `ai_orchestration_gemini` | Gemini REST streaming adapter, continuation/signature preservation, native tool correlation, usage, cancellation and request-scoped retry/fallback. |

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

## RepForge integration

RepForge's coach and optimizer now use application-scoped agent sessions and the Flutter bridge. The app supplies its existing analytics/health/SQL/domain tools through a registry, requires explicit approval for writes, persists optimizer questions and checkpoints, and keeps A2UI rendering in its existing message UI. Gemini settings, quota fallback and token accounting remain host-owned. View disposal detaches; process recreation restores committed questions/approvals. Interrupted running work requires an explicit stop and reconciliation instead of automatic write replay. Chat deletion removes its execution checkpoint. Portable backups contain conversations, not executable continuations.

SQLite data access remains an ordinary registered tool; runtime checkpoint storage is separate. The reusable read tools accept application-owned SQL templates. RepForge retains its existing read-only SQL tool and protections, including restrictions on orchestration/settings tables. Richer generated-query planning and native resource controls remain future work.
