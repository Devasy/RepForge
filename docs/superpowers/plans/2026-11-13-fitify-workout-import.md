# Fitify workout import implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task by task.

**Goal:** Let a FitifySync user import real workout sets into RepForge history and muscle analysis.

**Architecture:** Use the installed Health Connector to read paginated, own-source-filtered exercise sessions. Strictly decode the FitifySync v1 notes contract and map source codes to existing or downloaded catalogue exercises. Persist imported provenance with the session and prevent export loops, duplicate imports and silent replacement of local edits. SQLite v11 stores resistance/stretch maps on exercises, removing the activation join table.

**Tech stack:** Existing Flutter/Dart, Health Connector 3.11.1 and SQLite/Hive backends. No new dependencies.

**Spec:** User's RepForge/FitifySync handoff and decisions in this chat; FitifySync PR #6 notes contract; AndroidX ExerciseSessionRecord, ExerciseSegment, Metadata and HealthConnectClient references.

## Global constraints

- Resistance and stretch are independent scores on a 1–10 scale; preserve legacy decimal precision (95 becomes 9.5).
- Preserve old backups, exercise overrides, repeated sets, rest-relative indices and reconstructed timing provenance.
- Read only com.fitifysync.app; do not infer identity from generic segment types or ambiguous names.
- Missing external loads remain unknown; never infer bodyweight, measured duration or RPE from catalogue scores.
- Imports are explicit foreground actions. Ask only for exercise-read and optional supported history permissions.
- Unknown/malformed workouts stay out of analytics and remain reported; do not partially import them.

## Review focus

- Upgrading v9/v10 databases and old backups must preserve exact independent weights and stretch edits.
- A denied permission, partial read or failed page must not become a successful empty import.
- Repeated source versions must not duplicate history; edited imported workouts must not be overwritten silently.
- Rest indices must resolve against the native segment list, including multiple sets of the same movement.
- Source code missing from the downloaded catalogue must not receive a guessed muscle assignment.

### Task 1: Canonical intensity storage

Files: models/models.dart, services/sqlite_storage_service.dart, Coach SQL instructions and storage tests.

- [x] Add failing v10 migration/new-backup tests for 9.5 resistance, stretch preservation and absence of the activation table.
- [x] Add canonical Exercise.resistanceIntensities with legacy constructor/backup compatibility; update SQLite v11 save/load/migration and Coach SQL guidance.
- [x] Run storage, backup, intensity and Coach tests.

### Task 2: Source reads and deterministic conversion

Files: new services/fitify_workout_import.dart; existing HC interface/service; importer tests.

- [x] Test strict schema, indices/rests, source origin, repeated sets, unknown codes, unsupported versions and missing load handling.
- [x] Add exercise-read/history permission methods and paginated source-filtered reads to existing HC abstraction.
- [x] Convert complete valid workouts to history sessions, preserving raw notes/segments and source identity/version.

### Task 3: Persistence, analytics and usable UI

Files: WorkoutSession import provenance, SQLite/Hive serialization, WorkoutProvider, HealthSyncManager, Profile import widget and tests.

- [x] Test idempotent import, newer source updates, local-edit conflicts, persistence failures, backup roundtrip and recovery inputs.
- [x] Save through existing storage; refresh provider/history caches and analytics; never re-export imported records.
- [x] Add Profile action to preview/import a selected date range, download the catalogue when needed and display unresolved/errors honestly.
- [ ] Run affected tests and analysis, then full suite and Android debug build.
- [ ] Review, push to r2.2.3 and obtain a testable debug artefact. Device verification remains a separate live check.
