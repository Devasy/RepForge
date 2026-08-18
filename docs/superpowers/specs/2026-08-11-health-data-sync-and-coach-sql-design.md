# Health Data Sync (Sleep + HR) into SQLite — Design Spec

**Date:** 2026-08-11
**Status:** Approved
**Feature area:** Storage layer (`lib/services/`) + AI Coach SQL tool (`lib/services/ai/`)

---

## 1. Problem

The AI Coach's `run_sql_query` tool (added in `docs/superpowers/specs/2026-08-08-sqlite-migration-and-coach-sql-tool-design.md`) can query workouts, sets, targets, and PRs directly — but health data (sleep stages, heart rate, resting HR, HRV) is fetched live from Health Connect on every request via `HealthConnectService`/`HealthHistoryManager` and is never persisted. This means the coach cannot join health data against workout data in a single SQL query (e.g. "average sleep the night before a PR attempt" or "HR trend across the last 8 weeks of leg day sessions") — each half of the question requires a separate tool call and the model has to reconcile the join itself, unreliably.

This spec adds three SQLite tables that mirror Health Connect data, plus a sync service that keeps them populated, so `run_sql_query` can join across workout and health data directly.

---

## 2. Goal

1. Persist sleep sessions (with stage breakdown) and HR-related samples (raw heart rate, resting heart rate, HRV RMSSD) into the same SQLite database `SqliteStorageService` already owns.
2. Keep this data reasonably fresh via sync-on-app-launch (throttled) plus a manual "Sync now" action — no background service.
3. Extend `run_sql_query`'s schema description so the coach can query and join the new tables.
4. Keep the existing live `get_health_metrics` coach tool as-is, for "right now" freshness the synced tables won't have until the next sync.

Non-goals: no background/periodic sync (WorkManager or equivalent), no downsampling/compaction of old raw samples, no changes to `IStorageService`'s method signatures (this feature is additive on `SqliteStorageService` directly, matching how `SqlQueryService` already bypasses that interface), no UI beyond one manual sync button.

---

## 3. Schema

Added to the same database `SqliteStorageService` manages, created in `onCreate` (and via a migration step for existing installs already past `onCreate` — see §6).

```sql
-- Raw heart rate, resting heart rate, and HRV RMSSD samples all share the
-- same {time, value} shape from Health Connect; one EAV-style table avoids
-- three near-identical tables and keeps the coach's query surface simple
-- ("WHERE type = 'heart_rate'") instead of three tables to remember.
CREATE TABLE health_samples (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,           -- 'heart_rate' | 'resting_heart_rate' | 'hrv_rmssd'
  timestamp TEXT NOT NULL,      -- ISO8601
  value REAL NOT NULL
);
CREATE UNIQUE INDEX idx_health_samples_unique ON health_samples(type, timestamp);
CREATE INDEX idx_health_samples_type_ts ON health_samples(type, timestamp);

CREATE TABLE sleep_sessions (
  id TEXT PRIMARY KEY,          -- synthetic: the start_ts ISO string
  start_ts TEXT NOT NULL,
  end_ts TEXT NOT NULL,
  light_min INTEGER,
  deep_min INTEGER,
  rem_min INTEGER,
  awake_min INTEGER
);
CREATE INDEX idx_sleep_sessions_start ON sleep_sessions(start_ts);

CREATE TABLE sleep_stage_intervals (
  sleep_session_id TEXT NOT NULL REFERENCES sleep_sessions(id),
  start_ts TEXT NOT NULL,
  end_ts TEXT NOT NULL,
  stage TEXT NOT NULL           -- 'deep' | 'rem' | 'light' | 'awake'
);
CREATE INDEX idx_sleep_stage_session ON sleep_stage_intervals(sleep_session_id);
```

Sync watermarks (one ISO8601 timestamp per data stream, e.g. key `health_sync.heart_rate`) are stored as ordinary rows in the existing `settings` table — no new table needed for that.

`sleep_sessions.id` is derived from `start_ts` so re-syncing the same session (e.g. after a Health Connect correction) is a natural upsert target, not a duplicate.

---

## 4. `HealthSyncService`

New file: `lib/services/health_sync_service.dart`.

```dart
class HealthSyncService {
  HealthSyncService(this._hc, this._db);

  final IHealthConnectService _hc;
  final SqliteStorageService _db;

  Future<void> sync({bool force = false}) async { ... }
}
```

- **Throttle:** skip if the most recent sync (tracked via a `health_sync.last_run` watermark) was less than 30 minutes ago, unless `force: true`.
- **Per-stream incremental fetch with look-back:** for each of `sleep`, `heart_rate`, `resting_heart_rate`, `hrv_rmssd`: read that stream's watermark from `settings` (default `now - 90 days` if absent — the agreed backfill window). Fetch from `watermark - 3 days` through `now` — the 3-day look-back re-pulls recent data even though it was already synced, to catch late corrections Health Connect or the watch itself makes to recent records (e.g. a sleep session Health Connect revises the next morning). Anything before the look-back window is assumed final and is never re-fetched.
- **Upsert:**
  - `health_samples`: `INSERT OR REPLACE` keyed by the `(type, timestamp)` unique index — naturally idempotent and self-correcting.
  - `sleep_sessions` / `sleep_stage_intervals`: for each `SleepPeriod` in the fetch window, delete-then-reinsert `sleep_stage_intervals` for that session id and upsert the `sleep_sessions` row — same delete/reinsert-child-rows pattern the original migration spec already uses for `sets`/`exercise_logs`.
  - After all four streams succeed, advance each stream's watermark to `now` and the `last_run` throttle marker to `now`.
- **Failure handling:** any exception (permission not granted, Health Connect unavailable, one stream fails) is caught per-stream — a failed stream's watermark is left untouched so the next sync retries it, and does not block the other streams or crash the caller. Matches the existing best-effort caching posture in `HealthHistoryManager._readCachedHrDay`.

### Wiring

Only constructed when the active backend is `SqliteStorageService` — mirrors the existing guard in `main.dart:191-192` (`_storageService is SqliteStorageService ? SqlQueryService(...) : null`). Health data has no meaning under the pre-migration Hive fallback path.

- `AppInitializer` calls `sync()` once after both `HealthConnectService` and `SqliteStorageService` are ready, fire-and-forget (does not block first frame).
- A "Sync now" button is added to the existing health-permissions area of the Profile screen, calling `sync(force: true)`.

---

## 5. Coach SQL Tool Update

`CoachToolService`'s embedded schema description (used by `run_sql_query`, §7 of the original migration spec) gets the three new tables appended in the same one-line-per-table/column format as the existing schema text, so the model can join them against `sessions`, `exercise_logs`, and `sets` without a separate discovery call.

`get_health_metrics` (the existing live Health Connect tool) is unchanged — it remains the source for "right now" data that the synced tables won't have until the next app-open or manual sync.

---

## 6. Migration for Existing Installs

Existing SQLite installs (already past `onCreate`) need the three new tables added without a fresh install. `SqliteStorageService.init()` bumps `_dbVersion` and adds an `onUpgrade` step that runs the `CREATE TABLE`/`CREATE INDEX` statements from §3 if the new tables don't already exist (`CREATE TABLE IF NOT EXISTS`, safe to run unconditionally on upgrade). No data migration needed — these are brand-new tables with no prior data to carry forward; the first post-upgrade sync populates them via the normal 90-day backfill path.

---

## 7. Testing

- **`HealthSyncService`** (new test file, in-memory DB via `sqflite_common_ffi` + a fake `IHealthConnectService`):
  - First sync with no prior watermark backfills the full 90-day window.
  - Second sync only re-fetches from `watermark - 3 days` onward (verify the fake service receives the narrower range).
  - Re-running sync is idempotent: no duplicate rows in `health_samples` or `sleep_sessions`, and changed values from a "corrected" fake response overwrite the prior row.
  - A sync attempted less than 30 minutes after the last one is skipped unless `force: true`.
  - An exception thrown by the fake health service for one stream doesn't propagate, doesn't advance that stream's watermark, and doesn't block the other streams from syncing.
- **`SqliteStorageService`**: extend the existing test file to cover the new upsert methods and the `onUpgrade` path (open a v-1 schema DB, run `init()`, assert the new tables exist).
- **`run_sql_query`**: extend `sql_query_service_test.dart` with a join query across `sessions`, `sets`, `sleep_sessions`, and `health_samples`, confirming the schema and join work end-to-end.

---

## 8. Rollout Notes

- No new dependencies — reuses `sqflite`, `sqflite_common_ffi` (test), and the existing `IHealthConnectService`.
- No changes to `IStorageService`, `MockStorageService`, or any manager/provider — additive on `SqliteStorageService` only, same boundary `SqlQueryService` already uses.
- `CLAUDE.md`'s "6 boxes" / schema references would benefit from a follow-up doc note once this ships, but that's out of scope here (same deferral pattern as the original migration spec, §9).
