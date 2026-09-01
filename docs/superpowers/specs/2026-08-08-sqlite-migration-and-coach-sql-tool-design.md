# Hive → SQLite Migration + Coach SQL Query Tool — Design Spec

**Date:** 2026-08-08
**Status:** Approved
**Feature area:** Storage layer (`lib/services/`) + AI Coach tools (`lib/services/ai/`)

---

## 1. Problem

The AI Coach (`CoachToolService`) currently exposes ~15 narrow, purpose-built tools (`get_exercise_performance`, `get_workouts_in_range`, etc.), each hand-wrapping a specific `WorkoutProvider`/`PRManager` query. This is fine for known question shapes but can't answer arbitrary analytical questions the model wasn't given a preset tool for (e.g. ad-hoc joins, unusual aggregations, novel filters).

The fix — a generic SQL query tool — is a poor fit for the current storage layer: RepForge persists to **Hive**, a key-value store with no query language. Any SQL tool would need a translation layer.

Two paths were considered:
- **Ephemeral snapshot**: build a throwaway in-memory SQLite mirror on every coach tool call, rebuilt from Hive-backed in-memory lists each time.
- **Real migration**: replace Hive with SQLite as the actual persistence backend, so the coach's SQL tool queries live data directly with no translation step.

This spec chooses the second path. `IStorageService` (`lib/services/interfaces/storage_service_interface.dart`) is already a clean DIP boundary — every method takes/returns plain Dart models, no Hive types leak through — so a `SqliteStorageService implements IStorageService` swap is architecturally sound without touching any manager, `WorkoutProvider`, or screen. `MockStorageService` already fulfills the same interface, so the existing test suite is unaffected by the backend swap.

This is two dependent efforts: (A) migrate the storage backend, (B) add the coach's SQL tool on top of it. (A) is materially riskier — it touches real user data — and is the majority of this spec.

---

## 2. Goal

1. Replace Hive with SQLite (`sqflite`) as RepForge's persistence backend, via a new `SqliteStorageService implements IStorageService`, with a safe, reversible, one-time migration for existing installs.
2. Add `run_sql_query` to `CoachToolService`: the model submits a read-only SQL `SELECT`, executed against a dedicated read-only connection to the live database, results returned as JSON rows.

Non-goals: no UI changes, no new user-facing features, no change to any existing `IStorageService` method signature or manager/provider code.

---

## 3. Package Choice: `sqflite`

Considered `sqlite3` (FFI, synchronous) vs `sqflite` (platform channel, async). Chose **`sqflite`**:

- `IStorageService` is entirely `Future`-based already. `sqflite` runs DB work on a native background thread and returns via `Future` naturally — no extra isolate-management code. `sqlite3` is synchronous on the calling isolate; matching the same non-blocking behavior would require hand-rolling a background isolate, which is unjustified complexity at this app's data scale.
- `sqflite` supports `rawQuery(sql, args)` / `rawInsert` / `rawUpdate`, so the coach's arbitrary-SQL tool works identically to how it would under `sqlite3`. No capability is lost.
- No native binary bundling (`sqlite3_flutter_libs`) needed; uses the OS-provided SQLite.

**Known tradeoff:** `sqflite` uses the Android-bundled SQLite version rather than a pinned one, so very old devices could lack newer SQL features (e.g. window functions, SQLite 3.25+/Android 9+). Accepted as low risk for this app's scale and audience.

**Test dependency:** add `sqflite_common_ffi` (dev dependency) — required to run `sqflite`-backed code under `flutter test`, since plain `sqflite` needs a real platform binding unavailable off-device.

---

## 4. Schema

All tables live in one SQLite database file, created in `onCreate`.

```sql
CREATE TABLE exercises (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,          -- 'compound' | 'isolation'
  is_custom INTEGER NOT NULL DEFAULT 0,
  available_handles TEXT           -- JSON array or NULL
);

CREATE TABLE muscle_groups (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  growth_rate REAL NOT NULL DEFAULT 0,
  last_updated TEXT NOT NULL
);

CREATE TABLE exercise_muscle_activations (
  exercise_id TEXT NOT NULL REFERENCES exercises(id),
  muscle_group_id TEXT NOT NULL,
  activation_percentage INTEGER NOT NULL
);

CREATE TABLE routines (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE routine_exercises (
  routine_id TEXT NOT NULL REFERENCES routines(id),
  exercise_id TEXT NOT NULL,
  position INTEGER NOT NULL
);

CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  routine_id TEXT,
  duration_min INTEGER NOT NULL,
  notes TEXT,
  hc_synced_at TEXT
);

CREATE TABLE exercise_logs (
  id TEXT PRIMARY KEY,              -- synthetic: '${session_id}_${index}'
  session_id TEXT NOT NULL REFERENCES sessions(id),
  exercise_id TEXT NOT NULL,
  notes TEXT,
  handle TEXT
);

CREATE TABLE sets (
  id TEXT PRIMARY KEY,              -- synthetic: '${exercise_log_id}_${index}'
  exercise_log_id TEXT NOT NULL REFERENCES exercise_logs(id),
  weight REAL NOT NULL,
  reps INTEGER NOT NULL,
  is_dropset INTEGER NOT NULL DEFAULT 0,
  drops_json TEXT,                  -- JSON array of {id, weight, reps} or NULL
  time_taken INTEGER,
  timestamp TEXT NOT NULL,
  assist_weight REAL,
  extra_weight REAL,
  handle TEXT
);

CREATE TABLE targets (
  id TEXT PRIMARY KEY,
  exercise_id TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_value REAL NOT NULL,
  current_value REAL NOT NULL DEFAULT 0,
  estimated_completion_date TEXT,
  created_at TEXT NOT NULL,
  is_completed INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE personal_records (
  exercise_id TEXT PRIMARY KEY,
  best_weight REAL NOT NULL,
  best_reps INTEGER NOT NULL,
  best_volume REAL NOT NULL,
  achieved_at TEXT NOT NULL
);

CREATE TABLE training_programs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  total_weeks INTEGER NOT NULL,
  author TEXT,
  is_imported INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  phases_json TEXT NOT NULL,        -- List<TrainingPhase>.toJson()
  weeks_json TEXT NOT NULL          -- List<ProgramWeek>.toJson()
);

CREATE TABLE conversations (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'coach',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  messages_json TEXT NOT NULL       -- List<ChatMessage>.toJson()
);

CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE INDEX idx_sets_exercise_log ON sets(exercise_log_id);
CREATE INDEX idx_exercise_logs_session ON exercise_logs(session_id);
CREATE INDEX idx_exercise_logs_exercise ON exercise_logs(exercise_id);
CREATE INDEX idx_sessions_date ON sessions(date);
```

**Deliberately not fully normalized:** `training_programs` (phases/weeks/days/exercises) and `conversations` (messages) are stored as JSON-blob columns rather than exploded into child tables. Both are always read/written as a whole object via existing `toJson()`/`fromJson()` methods, never queried piecemeal by any manager or by the coach's SQL tool. Normalizing them would add several more tables for no query benefit — YAGNI.

---

## 5. `SqliteStorageService`

New file: `lib/services/sqlite_storage_service.dart`, `class SqliteStorageService implements IStorageService`.

- `init()`: opens the database (`openDatabase`), runs `onCreate` (schema above) on first creation.
- Every `IStorageService` method gets a real implementation: entity writes that touch multiple tables (e.g. `saveWorkoutSession` → `sessions` + `exercise_logs` + `sets`) run inside a single `db.transaction()` — delete-then-reinsert child rows for the given parent id, so updates and inserts share one code path.
- `exportAllData()` / `importData()` keep their existing JSON contract (used by the migration below and by the user-facing export/import feature) — implemented by reading/writing through the same model `toJson()`/`fromJson()` methods already used elsewhere.

No changes to `IStorageService`'s method signatures.

---

## 6. Migration & Cutover

**Goal:** existing installs upgrade from Hive to SQLite exactly once, safely, with no possibility of a half-migrated state.

1. On app start, `AppInitializer` (in `main.dart`) checks `settings['storage_migrated_v1']` **in the existing Hive settings box** (the migration hasn't happened yet at this point, so Hive is still authoritative for this check).
2. If unset: instantiate both the existing `StorageService` (Hive) and a fresh `SqliteStorageService`. For every entity type, read via the existing, already-correct Hive read methods (`getAllWorkoutSessions()`, `getAllRoutines()`, `getAllTargets()`, `getAllMuscleGroups()`, `getCustomExercises()`, `getAllTrainingPrograms()`, `getAllPersonalRecords()`, `getAllConversations()`, plus raw settings keys) and write each into `SqliteStorageService` through its normal write methods. This trusts only the new write path — reads reuse logic that already works.
3. Only if every entity type migrates without throwing: write `storage_migrated_v1 = true` into the Hive settings box.
4. From that point on (this launch and all future launches), `AppInitializer` hands `WorkoutProvider` a `SqliteStorageService` instead of `StorageService`.
5. If migration throws partway through anything, the flag is never set. The app falls back to `StorageService` (Hive) for that launch, and retries the full migration on the next app start. There is no partial-migration state a user can get stuck in.
6. **Hive boxes are never deleted.** They remain on disk indefinitely as a passive backup — the data volume for a personal fitness log is small, so the disk cost is negligible next to the safety value.

This keeps the app in exactly one of two well-defined states at all times: fully on Hive, or fully on SQLite.

---

## 7. Coach SQL Tool: `run_sql_query`

Added to `CoachToolService.buildTools()` / `handleCall()`, alongside (not replacing) the existing curated tools.

- **Connection:** a dedicated **read-only** `sqflite` connection (`openReadOnlyDatabase`) to the same database file used by `SqliteStorageService`. This is the real safety boundary — the OS/SQLite layer itself refuses writes on this connection, regardless of what SQL text is submitted.
- **Text validation (defense-in-depth, not the primary guard):** trim the query, strip a single trailing `;`, reject if a second `;` remains (multi-statement), reject case-insensitively if it doesn't start with `SELECT` or `WITH`, reject if it contains `insert|update|delete|drop|alter|create|attach|detach|pragma|vacuum|replace|trigger` as a keyword.
- **Row cap:** wrap the model's query as `SELECT * FROM (<query>) LIMIT ?` with a default of 200, model-adjustable up to 500 — never trusts a `LIMIT` the model wrote itself.
- **Error handling:** any exception (syntax error, cap violation, etc.) returns `{'error': message}`, matching every other tool's contract — a bad query is a recoverable turn, not a crash.
- **Function description** embeds the full schema (table + column names, one line each) so the model always has it in context without a separate schema-discovery round trip.

---

## 8. Testing

- **`SqliteStorageService`**: new test file, run against an in-memory database via `sqflite_common_ffi` (`databaseFactory = databaseFactoryFfi`, `inMemoryDatabasePath`). Covers every `IStorageService` method, mirroring the existing `MockStorageService`-based test patterns for shape.
- **Migration**: seed a `StorageService` (Hive, using the existing test Hive setup) with representative data across every entity type, run the migration routine against a fresh in-memory `SqliteStorageService`, assert the data matches, assert the flag is set, assert re-running the migration is a no-op (skips already-migrated).
- **Existing test suite** (managers, `WorkoutProvider`, screens): unaffected — all depend on `IStorageService`/`MockStorageService`, never the concrete backend.
- **`run_sql_query`**: valid `SELECT` → correct JSON rows; non-`SELECT` → rejected with error; multi-statement → rejected; row cap enforced; schema-referencing query (e.g. a join across `sessions`/`exercise_logs`/`sets`) returns expected shape.

---

## 9. Rollout Notes

- `pubspec.yaml` additions: `sqflite` (runtime), `sqflite_common_ffi` (dev, for tests).
- `hive`/`hive_flutter` dependencies and `StorageService` (Hive) are **kept**, not removed — they remain the migration source and the pre-migration fallback path indefinitely (or until a future spec decides it's safe to drop them, informed by real-world migration success rates).
- No changes to `CLAUDE.md`'s documented Hive box list are needed for this spec beyond noting the SQLite migration exists; a follow-up doc update once this ships is reasonable but out of scope here.
