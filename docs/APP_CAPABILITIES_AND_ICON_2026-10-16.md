# RepForge capabilities and minimal icon redesign

Source review snapshot: commit `c10f924` plus the local icon work. The PR retains newer main-branch application changes.

Reviewed against the local source on 16 October 2026. This is a code-based feature review, not a claim that every feature was exercised on a device. The existing graph in `graphify-out/graph.json` helped locate relationships; current source takes precedence over that older graph. No AI behavior or health calculations were changed for the icon redesign.

**Latest icon follow-up, 16 October:** the current launcher is **Rounded Signal v7**. It preserves the rounded components and restrained depth approved in v6 while restoring violet/cyan on a dark `#07070A` canvas at the user's request. Editable source: `workout-logger/assets/icon/repforge_signal_v7.svg`. Launcher/store assets and the themed silhouette match v7. The themed asset has no baked-in background; the proof sheet shows a dark themed example, while the actual colors follow Android's launcher theme. The orange/light v6 and original v5 sources remain preserved. The app's interior theme was not changed. The v5 section below records the original design pass.

## Product identity

RepForge combines three jobs: record strength training, understand performance in the context of recovery, and ask an AI coach to investigate or help organise training. Its distinguishing capability is the path from personal records to a grounded answer and a generated visual: local workout/health data → tools or SQL → Gemini → text or a native A2UI dashboard.

The icon should communicate strength and a connected data signal at a glance. Trying to include a brain, chart, health heart, dumbbell, and agent nodes separately would obscure that identity at launcher sizes.

## Feature map

| Area | Implemented capabilities | Main source |
|---|---|---|
| Home | Training overview, activity/consistency, recovery/readiness, entry into workouts | `screens/home_screen.dart`, `screens/widgets/dashboard_widgets.dart` |
| Active workout | Start/resume training, move between exercises, enter/edit/remove sets, rest timer, save session | `services/managers/active_workout_manager.dart`, `screens/workout_flow_screen.dart` |
| Load fidelity | Weight/reps, timed exercises, assisted and added bodyweight loads, dropsets, attachment handles, set timestamps | `models/models.dart`, `screens/widgets/exercise_input_section.dart` |
| Exercise library | Built-in catalogue, custom exercises, exercise overrides, muscle activation, guides and movement demonstrations | `services/managers/exercise_manager.dart`, `data/`, `screens/exercise_guide_screen.dart` |
| Routines | Create, edit, reorder and reuse ordered exercise lists; default handles | `services/managers/routine_manager.dart`, `screens/widgets/routine_creator.dart` |
| Programs | Design, import, save, view and delete multi-week training programs | `services/managers/program_manager.dart`, `screens/programs/` |
| AI program generation | Natural-language program generation, preview and saving flow | `screens/ai_program_generator_screen.dart`, `services/ai/gemini_ai_service.dart` |
| History | Session list/calendar, session details and editing, workout summaries | `services/managers/history_manager.dart`, `screens/history_screen.dart` |
| Analytics | Volume progression, exercise performance, estimated 1RM, muscle focus, activity heatmaps | `services/managers/analytics_manager.dart`, `screens/analytics_screen.dart` |
| Records and goals | Personal records by exercise/handle, weight/reps/volume/duration records, targets, completion estimates | `services/managers/pr_manager.dart`, `services/managers/target_manager.dart` |
| Local recommendations | Growth fitting, recovery estimates, next-set recommendations, plateau/deload logic, readiness and session fatigue adjustments | `services/ml_service.dart`, `services/strategies/`, `services/utils/` |
| Recovery | Per-muscle recovery and daily baseline-relative sleep/resting-HR/HRV readiness | `services/managers/readiness_manager.dart`, `services/utils/readiness_calculator.dart` |
| Health details | Sleep/stages, overnight HR distributions, HR day/range views, workout HR analysis | `services/managers/health_history_manager.dart`, `models/sleep_hr_models.dart`, `models/workout_hr_models.dart` |
| AI coach | Streaming chat, saved conversations, retry handling, image attachments, tool calls, data-backed dashboards | `viewmodels/ai_coach_view_model.dart`, `screens/ai_coach_screen.dart` |
| Routine optimizer | Investigate routine performance, clarify preferences, propose changes, let the user select changes, apply | `viewmodels/routine_optimizer_view_model.dart`, `services/gemini_context_builder.dart` |
| Persistence | SQLite with migration from Hive and fallback handling; relational workout and health tables | `main.dart`, `services/sqlite_storage_service.dart`, `services/storage_migration_service.dart` |
| Portability | Validated backup import/export, share/file flows | `services/backup_codec.dart`, `screens/profile_screen.dart` |
| Preferences | kg/lb display conversion, training increments, profile/body figure, Gemini model/thinking/tool-round settings | `services/settings_provider.dart`, `screens/widgets/profile_sections.dart` |
| Maintenance | Release/changelog presentation, debug log collection | `services/release_service.dart`, `services/debug_log_buffer.dart` |

Paths in the tables are relative to `workout-logger/lib/` unless otherwise stated. The accompanying [source function index](SOURCE_FUNCTION_INDEX_2026-10-16.md) covers declarations across the current Dart library, including implementation helpers. It is a navigation aid, not a behavioral proof for each function.

## Agentic AI: actual reach

`GeminiContextBuilder.buildCoachSystemPrompt` supplies instructions and the A2UI vocabulary, rather than embedding all workout records. `AiCoachViewModel` builds the conversation, sends image/text content, streams results, records tool activity and persists messages. `GeminiAiService` resolves tool calls, returns their results to the model, and continues toward a final answer.

The default tool-resolution budget is **5 rounds**, adjustable from **3 to 25**. A round can include multiple tool calls. This is bounded, user-initiated tool use; no background autonomous agent scheduler was established by this review.

The coach advertises **15 regular tools**, plus SQL when the SQLite service is available:

| Tool | Questions/actions enabled |
|---|---|
| `get_muscle_group_volume` | Compare training volume across muscles and over time |
| `get_exercise_performance` | Session/set history, progress, estimated 1RM, best duration, latest loads |
| `get_workouts_in_range` | Workout counts, total volume and session breakdown in a chosen period |
| `get_routine_performance` | Routine usage, exercises and volume progression |
| `get_personal_records` | Best weight, reps, set volume or timed hold |
| `get_goal_progress` | Current versus target values and estimated completion |
| `get_muscle_recovery` | Ready/recovering/fatigued muscle groups |
| `get_all_routines` | Discover available routines before analysing or changing them |
| `create_routine` | Create a named routine with ordered catalogue exercises |
| `update_routine` | Change a saved routine and its exercise configuration |
| `add_custom_exercise` | Add an exercise missing from the catalogue |
| `update_exercise` | Update an exercise definition/override |
| `get_health_metrics` | Sleep sessions and stage totals |
| `analyze_health_workout_correlation` | Sleep hours/deep sleep versus volume, duration or a chosen exercise's maximum weight; paired points and descriptive/regression statistics |
| `get_sleeping_hr_analytics` | Nightly percentiles, mean/min/max, standard deviation, variance and trend |
| `run_sql_query` | Custom read-only joins, filters and aggregations over local relational data |

The optimizer separately exposes `ask_user_questions`. Its instructions explicitly ask the user to select proposed changes before applying them. In ordinary coach chat, write tools may run when the user clearly requests the change; the prompt asks the coach to confirm what it did. The comment at the top of `coach_tool_service.dart` still describes a read-only tool set even though the implementation now includes writes.

Image attachment handling accepts JPEG, PNG and WebP up to 5 MB. The prompt covers form/equipment/label interpretation. This is image-based advice, not measured video motion analysis or a persisted nutrition tracking pipeline.

## Broad question answering through data

SQL extends the coach beyond prewritten question categories. The model can join sessions, exercise logs, sets, exercises, muscle activation, routines, targets, personal records and synced health tables. This makes exploratory questions plausible without a dedicated tool for every question.

`SqlQueryService` uses a separate read-only database connection, accepts a single SELECT/WITH statement, rejects mutation keywords and restricted settings/schema access, and caps returned rows at **200 by default / 500 maximum**. These are application safeguards, not a security audit. The row cap limits returned records, not database work; expensive scans/joins are still possible because this implementation does not impose a query execution timeout.

For broad questions, aggregate in SQL before returning rows. A count, daily average or grouped trend can describe a large history with few result rows. Computing a full-history statistic from a truncated list of raw rows would be misleading. Availability also depends on SQLite being active, health permissions, imported history and model/tool performance.

### Useful questions supported by the current records

These are examples of the data's scope, not promises that every wording will succeed. Custom SQL questions require correct joins, units and date attribution. Charts need an explicit request or the model choosing an A2UI answer.

| Scope | Example questions |
|---|---|
| Workout history | How many workouts did I complete this month? What was my weekly volume? Which week was most consistent? What was my longest session? |
| Exercise progression | How has my bench progressed? What did I squat last session? What is my best estimated 1RM? Which exercise has stalled? |
| Set patterns via SQL | At a fixed weight, are my reps rising? How often do I use dropsets? How do my attachment handles compare? How has my assisted load changed? |
| Timed work | What is my longest plank? How has hold duration changed? Which timed exercises have improved most? |
| Routine analysis | Which routine do I use most? Compare volume in my push sessions. Which exercises occur in several routines? What changed after I edited my routine?* |
| Muscle balance | Compare chest and back volume. Which muscles received the least work recently? Show a muscle-volume distribution. Which muscles are recovered today? |
| Goals and records | Which targets are nearly complete? What are my recent PRs? How far am I from my weight target? What is my estimated target date? |
| Sleep | Show my last 14 nights. What is my average sleep duration? How much deep versus REM sleep was recorded? Which nights were shortest? |
| Overnight HR | Is my sleeping HR trending up? Show P5, P25 and mean by night. Which nights had the greatest variability? What was my overnight HR floor? |
| Health/workout joins | Is sleep associated with workout volume? Compare deep sleep with bench maximum weight. Compare volume after short and long sleep. Is resting HR associated with session duration?** |
| Detailed joins | What was average HR during each workout? Compare HR across recorded sleep stages. Compare HRV on workout and rest days. Does my next-day resting HR vary after high-volume days?** |
| Training actions | Create a three-day routine using my exercises. Add a custom exercise. Replace an exercise in my routine. Optimise my routine after reviewing its performance. |

*Historical routine edits are not a versioned event stream. Compare only what session records actually preserve; a saved routine's current configuration does not prove its old configuration.

**These extend beyond the dedicated sleep-correlation tool and require SQL or further computation/interpretation. Meaningful comparisons need enough paired observations, an explicit time window and consistent night-to-training-day attribution. Association does not establish that a health metric caused a performance change.

## GenUI / A2UI

This repository implements its own constrained native rendering pipeline under `lib/genui/`; it does not let the model execute arbitrary Flutter code. `defaultA2UiRegistry` registers eight component specifications:

| Component | Role |
|---|---|
| `GridContainer` | Compose multiple cards/charts |
| `StatCard` | A KPI with supporting detail |
| `DynamicChart` | Line, bar or pie series |
| `DataListGroup` | Records, rankings and session lists |
| `MetricGauge` | A bounded score/progress value |
| `ScatterPlot` | Paired observations and correlation visuals |
| `RadarChart` | Multiple dimensions in one profile |
| `FilterChips` | Display the scope/window of an answer |

The same registry provides model-facing schemas, parser lookup and rendering. The parser tolerates numeric strings, aliases and several envelope forms. Unusable UI can fall back to prose/Markdown. The prompt asks the model to retrieve real data before making a dashboard.

**Current interaction limit:** `FilterChips` is explicitly non-interactive. There is no general A2UI action contract wired through the renderer. The generated answer can visualise an investigation, but tapping its scope labels does not launch another investigation. This is a concrete next step if richer interactive exploration is desired.

## Health Connect integration

The app service uses the `health_connector` package. The Samsung SDK archives and vendor source folders elsewhere in the repository do not establish a direct Samsung integration in the app: no direct Samsung references were found in its Dart/native app sources.

**Read:** sleep sessions/stages, heart-rate series, resting heart rate and HRV RMSSD. Partial read permission grants are supported.

**Write:** strength-training exercise sessions with titles/notes and exercise segments, repetitions, rest intervals and weight where supported. Exercise labels are carried in notes; unmapped exercises fall back to an appropriate generic segment. Unsupported segment weight triggers a retry without weight. Segment timing can be estimated when precise set timing is missing; it is not always measured exercise timing.

**Persistence:** `HealthDataSyncService` imports three sample streams plus sleep/stage data into SQLite. Initial backfill is 90 days, subsequent sync overlaps the prior 3 days, normal runs are throttled to 30 minutes, and concurrent callers share an in-flight run. Streams fail independently and ungranted permissions do not advance their watermarks. This cadence is a throttle around sync calls, not evidence of a scheduled background sync every 30 minutes.

**Readiness:** sleep/resting-HR/HRV components are scored relative to personal baselines. Default weights are 50% / 30% / 20%, renormalised over available components. Each component needs at least 5 baseline samples; very short sleep has an additional cap. Muscle recovery and daily readiness are related but separate estimates.

**Not currently available as general SQL health data:** steps, calories, nutrition, body temperature, blood glucose, SpO2 and arbitrary other Health Connect record types. A label photo does not turn those into persistent health records. Missing, ungranted or not-yet-imported records cannot support an answer.

## Highest-value capability improvements (proposals only)

Source-level issues to account for before promising arbitrary analytics:

- **Rolling sleep-window mismatch:** `_getHealthMetrics` selects week granularity only for windows up to 7 days; larger requests take the final N bars of the current calendar month. `HealthHistoryManager.rangeFor` defines month as the whole calendar month, including future zero-filled slots. Therefore a request such as "last 14 nights" in the middle of a month can include future dates and omit recent nights. Fetch and trim by actual date, including the previous month when needed.
- **Multiple workouts on one day:** `_analyzeHealthWorkoutCorrelation` stores a single `m['y']` per date and overwrites it for each session. On a two-session day, volume and duration are not summed, and exercise maximum weight is not necessarily the daily maximum. The result can depend on session order. Aggregate sessions per day before pairing with sleep.
- **Overnight statistical definition:** `get_sleeping_hr_analytics` calculates some mean/variance/P25 values from segment-average HR values. These are not necessarily sample-weighted whole-night statistics. Label the definition or calculate consistently from the underlying observations before presenting them as interchangeable.

These observations follow directly from implementation; they were not reproduced on a connected device during this task. No analytics fixes are bundled into the icon change.

1. Advertise `run_sql_query` explicitly in the coach system instructions as the fallback for unfamiliar cross-table questions, with examples of aggregating before returning rows.
2. Keep its schema documentation exact: the tool description refers once to `workout_sessions.date`, while the actual advertised table is `sessions`. Correct that wording before expanding SQL prompting.
3. Return query provenance with answers: window, record/paired-day count, missing days, sync freshness and units. This helps users judge whether an answer is representative.
4. Add a bounded query execution strategy and a more structured SQL policy if expanding data access. A read-only connection protects writes but does not bound computation.
5. Add an A2UI `onAction` contract for date-window changes and follow-up questions; retain non-interactive scope chips until it exists.
6. Expand health streams only for clear questions and with matching permissions, models, sync, schemas, prompt documentation and validation. Merely shipping the connector's source does not expose all of its types to the coach.
7. Add provenance/versioning where retrospective questions need it, such as routine changes. Avoid inferring old routines from their current definitions.

These are recommendations from source inspection, not changes included in this task.

## Minimal icon: Signal v5

The mark has violet weight plates with clipped corners and a cyan pulse connecting them. The plates retain the strength/forge identity; the signal carries connected health and data. It deliberately abstracts the AI capability into the signal rather than adding a separate robot/brain/sparkle symbol.

- Palette: existing violet `#7C3AED`, data cyan `#00C2D4`, background `#07070A`; monochrome uses the same silhouette.
- Shape: four flat plate silhouettes plus one continuous signal stroke. No text, glow, extrusion, texture or tiny nodes.
- Editable source: `workout-logger/assets/icon/repforge_signal_v5.svg`.
- Masters: opaque 1024px legacy/store master and transparent 1024px adaptive foreground.
- Android: five legacy PNG densities, five adaptive foreground densities, Android 8+ adaptive XML and Android 13+ monochrome XML.
- Adaptive padding lives in the SVG; the configured additional inset is zero. The master is enlarged 18% for legacy/store visibility.
- Store listing: 512px `fastlane/metadata/android/en-US/images/icon.png`.
- Rebuild: `node scripts/generate_signal_icon.cjs` with `sharp` available. This is the canonical generator because it also preserves the themed vector/Android 13 override.

Previous v2/v3/v4 source files remain available. Existing staged changes were not reset or committed.

## Validation performed

- Dart AST inventory: 154 library files, 2,135 named declarations, zero parser diagnostics. This is parsing, not full static analysis or runtime test coverage.
- Icon inspection: 24/36/48/64/96px sizes, circular/rounded masks and themed appearance in `repforge_signal_v5_proof.png`.
- Asset checks: 1024px masters, opaque background, genuine foreground alpha, all five legacy/adaptive density dimensions, 512px store asset and well-formed XML.
- Adaptive safe area: all non-transparent foreground pixels fit within the central 66.7% safe circle (maximum radius 313.99px; allowed 341.33px on the 1024px source).
- Android resources compiled and linked successfully with AAPT2 and the Android 37 platform using a minimal launcher manifest.
- `git diff --check` passed. No connected-device install or full application build was performed.
