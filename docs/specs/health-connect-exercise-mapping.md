# Health Connect exercise and muscle mapping

Target release: `r2.2.3`.

## What is implemented

Profile contains **Import saved workouts from Health Connect**. Choose dates,
preview sessions from connected apps and import them into normal workout history.
Used extended-library exercises retain names, tracking types and muscle profiles
offline, including after a restart or missing catalogue cache.

The foreground reader requests exercise-read access independently of workout
export/readiness settings. It reads all origins except RepForge, follows every page,
and fails a partial read instead of reporting an empty successful result. Dates
older than the recent four-week window require supported and granted Health
Connect history access. It caps a read at 2,000 workouts; choose shorter dates
for larger histories. No background-read permission is requested.

## Source identity and conversion

Ordinary Health Connect sessions require no custom notes payload. Supported native
segment types map to existing exercises; ambiguous types are not guessed into
specific movements. Summaries and raw provenance are retained when exercise details
are unavailable, with a preview warning. Source-scoped IDs prevent collisions.
Versionless records can update untouched imports when their source content changes.

An internal adapter decodes `fitifysync.exercise_segments` v1 for richer details. Each item
requires a unique integer `segment_index`, string `code` and `name`, and
`timing_kind: reconstructed`. Indices address the complete native segment list,
including rests. Every active segment must be identified. Empty/malformed notes,
unsupported versions, invalid intervals and unresolved codes are reported per
workout; no partial workout is saved.

Match verified source codes to bundled built-in mappings, then `fitify:<code>`
exercise IDs from the downloaded catalogue. Names and generic native segment
types are not sufficient to guess a variant. Consecutive sets share a log;
returning to an exercise later in a circuit retains its original order.

Preserve native reps, duration and timestamps and the original notes/segments.
Timings are reconstructed, including durations estimated upstream by FitifySync;
they must not be used as measured per-exercise heart-rate boundaries. Read a
native weight when present. Otherwise keep load mode `unknown`, with no inferred
bodyweight or kilogram volume. Duration and reps remain usable. Catalogue
resistance/stretch scores are not RPE, measured EMG or evidence of growth.

## History and analysis

Local IDs use source client record identity (falling back to Health Connect
record ID). Source provenance and the last imported content snapshot travel with
the session through SQLite, Hive and backups. Repeated source versions are
skipped. A newer source version can replace an untouched imported workout;
locally edited imports are retained and reported as conflicts. Saves are
serialized and confirmed before updating caches/counts. Imported workouts are
never exported back to Health Connect, including manual history sync paths.

Saved workouts feed normal history and resistance-based recovery. Where a week
contains unknown loads, Home and Analytics muscle maps show **weighted sets**:
completed sets multiplied by independent resistance score / 10. This is training
exposure, separate from tonnage. Stretch scores do not increase resistance or
recovery load. Unknown loads do not fit weight/tonnage trends or one-rep maxima.

## SQLite v12 and backup compatibility

`exercises.resistance_intensities` and `stretch_intensities` contain independent
muscle-ID maps. The v11 migration converts each old activation weight / 10 in
Dart, preserving decimals (95 becomes 9.5), and drops the activation join table.
The v12 migration repairs PR rows split by the old colon-delimited exercise/handle
parser, retaining best values and legitimate handle variants. Canonical exercise IDs
are opaque; composite IDs are decoded only at legacy boundaries. Timed imported sets
display like native holds without a missing-load label. Session timestamp metadata
and set rows load in one SQLite snapshot.
No Android SQLite JSON extension is required for migration or app queries.
`Exercise.resistanceIntensities` is canonical; a computed `muscleActivations`
adapter supports existing callers. New backups write canonical maps; old
activation-list backups remain readable. User edits and stretch overrides stay
intact. Coach schemas expose resistance/stretch inputs; legacy pending proposals
remain executable for backward compatibility. Coach SQL guidance describes the
new schema and excludes unknown loads from tonnage.

## Current limits and live verification

This first flow is manual foreground import, not background synchronization or
automatic source deletion handling. Deleting a record in Health Connect does
not delete saved RepForge history. Unresolved workouts stay in Health Connect
for a later retry after catalogue/source fixes. The imported session model does
not add source calorie totals; heart-rate/readiness reads use their existing
separate paths.

JVM/Flutter checks do not prove device permission behavior, exact source
Firestore timestamp semantics, or display/import support in another app. Verify
on the actual phone with the updated FitifySync build and the RepForge test APK
before calling the complete on-device flow verified.

## Android references

- [ExerciseSessionRecord](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSessionRecord.md.txt)
- [ExerciseSegment](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/ExerciseSegment.md.txt)
- [Metadata](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata.md.txt)
- [HealthConnectClient](https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient.md.txt)
- [Reading, pagination and history access](https://developer.android.com/health-and-fitness/health-connect/read-data)
