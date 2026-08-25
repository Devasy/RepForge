# Samsung Health Integration — Design Notes

## Status: exploratory (not implemented)

This is an analysis of what a "Samsung Health integration" would actually mean for
RepForge, given the app already talks to **Android Health Connect**
(`lib/services/health_connect_service.dart`, `health_connector: ^3.9.1`). It is
written to decide *what to build*, not as a spec ready to implement.

## The key fact: Samsung Health already writes into Health Connect

Since Samsung Health app version ≥ 6.29 on One UI 6 / Android 14+, Samsung Health
syncs most of its data into Health Connect automatically (this replaced the old
"Samsung Health SDK vs. Google Fit" split). Health Connect is now Samsung's own
recommended integration surface for third-party apps — Samsung's developer docs
point external apps at Health Connect rather than a private Samsung SDK for
mainstream health data.

That means **RepForge already has a Samsung Health integration today**, on any
Samsung phone where the user has Samsung Health installed and has granted it
Health Connect write access (the default on modern Samsung devices):

| Data RepForge already reads via Health Connect | Samsung Health source |
|---|---|
| Sleep sessions + stages (`readSleepSessions`) | Samsung Health sleep tracking (watch or phone) |
| Resting heart rate (`readRestingHeartRate`) | Galaxy Watch |
| HRV (`readHrvRmssd`) | Galaxy Watch |
| Raw heart-rate samples (`readHeartRateSamples`) | Galaxy Watch |
| Workout sessions RepForge **writes out** (`syncWorkoutSession`) | Shows up in Samsung Health's own workout history |

This is why `HealthConnectService._segmentTypeMap` already maps `'plank'` to
`ExerciseSegmentType.plank` — a plank logged in RepForge is written to Health
Connect as a proper exercise segment that Samsung Health (and any other Health
Connect reader) understands, timed duration included.

## What Health Connect does *not* give us from Samsung Health

A few Samsung Health metrics either aren't modeled as Health Connect record
types at all, or are gated behind partner approval:

- **Stress score** (Samsung's proprietary metric) — no Health Connect record type.
- **Body composition** (Galaxy Watch BIA: body fat %, skeletal muscle mass,
  body water) — Health Connect has `BodyFatRecord`/`LeanBodyMassRecord`, but
  Samsung Health does not currently populate them from watch BIA scans.
- **Blood oxygen (SpO2)**, **skin temperature**, **ECG** — present in Health
  Connect's type list, but whether Samsung Health backfills them depends on
  watch model, region, and firmware; not reliable enough to build against.
- **Samsung Health's own step/activity goals and challenges** — social/gamification
  data, not exposed via Health Connect at all.

Getting these would require the separate **Samsung Health Data SDK** (device
data on-phone) or **Samsung Health Sensor SDK** (direct Galaxy Watch sensor
access), both of which:

1. Require a Samsung Developer Partner application and per-app approval.
2. Only work on Samsung devices — every other Android OEM is Health-Connect-only.
3. Would need a maintained companion Wear OS/Tizen app to reach watch sensors.

Given RepForge already targets vendor-neutral Health Connect (works identically
on Pixel, Samsung, OnePlus, etc.) and ships via F-Droid with a
byte-for-byte-reproducible build (see `CLAUDE.md`'s note on the F-Droid release),
taking a Samsung-only proprietary SDK dependency would be a significant
architectural and distribution regression for a narrow metric set.

## Recommendation

**Don't integrate the Samsung Health SDK.** Instead, widen the existing
Health-Connect-based integration, which benefits Samsung Health users (the
majority of the wearables install base) for free and keeps working for every
other OEM:

### Phase 1 — extend `HealthReadType` / `IHealthConnectService`
Add read support for record types Health Connect already standardizes and that
Samsung Health commonly populates:
- `StepsRecord` — daily step count, useful as an activity/recovery signal
  alongside the existing sleep + HRV readiness inputs (`ReadinessManager`).
- `ActiveCaloriesBurnedRecord` / `TotalCaloriesBurnedRecord` — surfaces calories
  burned per workout next to volume in `WorkoutSummaryScreen`.
- `WeightRecord` — if the user logs weigh-ins in Samsung Health (or a Samsung
  smart scale), pull it into `SettingsProvider.userBodyWeight` instead of manual
  entry, which also feeds the assisted-bodyweight volume calculations already
  in `WorkoutSet.calculateVolume`.

Each is additive to the existing `HealthReadType` enum and
`grantedReadTypes()`/`requestReadPermissions()` pattern — no new plugin, no new
permission model, same partial-grant handling already in place.

### Phase 2 — surface it
- Add steps/active-calories tiles to the readiness/analytics screens the same
  way sleep and HRV are shown today.
- Expose the new metrics to the AI coach via a `coach_tool_service.dart` tool
  (e.g. extend `get_health_metrics` or add `get_activity_metrics`) so questions
  like "how many steps did I average this week" work through the existing
  function-calling path.

### Phase 3 (only if there's real demand) — evaluate the Samsung SDK
If users specifically want stress score or BIA body composition, revisit the
Samsung Health Data SDK then, as a Samsung-only optional enhancement layered on
top of (not replacing) the Health Connect path — e.g. a
`SamsungHealthService implements IHealthConnectService` variant selected only
when the device is Samsung and the SDK is available, falling back to the
existing Health Connect implementation everywhere else.

## Non-goals

- Replacing `health_connector`/Health Connect as the primary integration.
- A Samsung-specific UI path (Samsung Health branding, deep links into the
  Samsung Health app) — out of scope until Phase 3 is justified.
- Wear OS / Tizen companion app development.
