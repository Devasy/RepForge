# UX analysis and roadmap

## Scope and evidence

This is a source-code and repository-screenshot audit, not an instrumented usability study or a device-tested prototype. The repository screenshots predate some code improvements. Findings below distinguish observed behavior from proposals. Do not treat illustrative mockup data, copy, spacing, or charts as production requirements without checking the real data model.

Product direction: retain RepForge's dark surfaces and purple identity, while making the next useful action obvious and reducing repeated input. Preserve offline workout logging, local data ownership, optional AI, existing advanced workout features, and diagnostics.

## 1. Action-focused Home

Observed: Home is a long dashboard containing a streak hero, readiness, sleep, heart rate, stats, heatmap, muscle volume, insights, and recent workouts. Start opens a routine selector. Resume is already supported.

Proposal: prioritize one adaptive action card:

| State | Card | Primary action |
| --- | --- | --- |
| Active workout | Current exercise and logged progress | Resume workout |
| Active program | Next eligible program session | Start session |
| Routine user | Explicitly pinned or recently used routine | Start routine |
| New user | Clear starting choices | Start a workout |
| Planned rest day | Weekly consistency and next session | View plan |

Keep Choose another accessible. Below the hero, show compact weekly progress, optional recovery, and recent workouts. Keep detailed analytics in Progress. Display a reason for the chosen session. Schedule behavior must account for local dates, completed/skipped sessions, and user overrides; do not invent a schedule from list order.

## 2. Accurate next-workout selection

Observed: Routines uses `routines.first` for a card labeled Up next / Today. That is not evidence of today's schedule.

Proposal: choose the next program session where valid, otherwise an explicitly pinned routine, otherwise the most recently used routine with an honest label. Use Choose a workout when no choice is justified. Distinguish next program session from scheduled today. Make weekly consistency the primary motivation measure; rest days should not imply failure.

## 3. Faster and more accurate set logging

Observed: values are prefilled, previous-session sets are shown, Log set owns the bottom primary action, and superset advancement exists. Initialization uses the latest current-session set or the last previous-session set.

Proposal: offer the corresponding previous-session set as a default, with intentional current-session edits taking precedence. Define precedence for routine targets, last-session values, manual values, and progression suggestions. Match exercise, equipment/handle, load mode, and relevant set position. Handle missing history and unequal set counts explicitly.

Place the matching last-session reference beside inputs. Offer tap-to-copy, immediate Undo, and editing of completed sets. Distinguish Previous session from Suggested progression. Consider per-exercise weight increments with global fallback. Preserve kg/lb conversions, assisted and weighted bodyweight semantics, duration-based exercises, dropsets, superset order, and historical load encoding.

## 4. Rest without losing workout context

Observed: normal set logging replaces the workout view with a full-screen rest timer. The rest view receives the next exercise name even when more sets of the current exercise may remain.

Proposal: inline rest card with remaining time, adjustment, Skip, and optional expanded timer. Allow preparation of the next set, corrections, guides, and exercise navigation during rest. Next up must reflect the actual next action, including superset behavior. Preserve elapsed-time correctness across background/resume, sound/vibration preferences, alerts, and manual timing changes. Compact and expanded views must share one timer state.

## 5. Minimize, finish, and discard

Observed: header close opens a discard confirmation; back handling is separate; Home already offers Resume.

Proposal: explicit Minimize workout, Finish workout, and secondary confirmed Discard. Add a persistent resume bar across primary destinations. Preserve the existing protection against starting a conflicting session. Inspect current persistence before promising recovery after process death. Support jumping between exercises and substituting an exercise for this session separately from permanently changing a routine. Define what happens to already logged sets when substituting.

## 6. Navigation and planning

Observed: Home / Routines / History / Stats; Programs is reached from Routines; Coach is separate.

Proposal: Home / Train / History / Progress, with labels visible. Train offers Routines / Programs / Exercises. Explain routine as one reusable workout and program as a multi-week sequence. Keep Coach contextual initially; a fifth main destination requires evidence of usage. Preserve tab position, navigation state, and access to existing features.

Routine builder: compact exercise rows with set/rep/rest summaries, clear reorder affordances, bulk exercise selection, and explicit superset grouping. Do not show Group selected as superset without selection controls. Establish a real selection state before enabling the action; the mockup omits that interaction detail.

## 7. Contextual coaching

Observed: chat history, tool chips, run controls, and proposed-change approvals already exist.

Proposal: entry points such as Explain this workout, Why has this lift stalled?, Review this routine, and Review my week. Pass session/exercise/date context and show it above the composer. Lead responses with a finding and practical next step, with supporting data expandable. Translate internal tool names into useful status copy, leaving technical details expandable.

Keep meaningful approvals. Show before/after, reason, scope, and selected changes clearly. Preserve stop/resume behavior, durable checkpoints, tool execution guarantees, partial-failure handling, and protection against replaying writes. Do not introduce selective application unless backend semantics support dependencies and partial success safely. Use deterministic facts for comparisons and label AI interpretation as interpretation.

## 8. Honest health states

Observed in the supplied logs: permissions and enough baseline history existed, but today's measurements were missing. Permission is not freshness.

Proposal: distinguish disconnected, connected/waiting, building baseline, ready, and historical data. Show latest measurement date and individual available metrics even when no score exists. Label fallback data by date. Explain missing score in plain language. Let users hide recovery cards. Handle timezone boundaries and sync failures; never fabricate a readiness number or imply permission guarantees availability.

## 9. Visual hierarchy and accessibility

Retain brand color and dark surfaces. Reduce decorative whitespace on dense screens, reserve strong accents for primary actions, improve secondary-text contrast, and label important icons. Keep advanced controls discoverable without making everything visually primary. Validate touch targets, semantics, focus order, keyboard behavior, large text, small screens, system insets, reduced motion, and bright-gym readability. Prefer OS accessibility settings; app overrides should complement them and persist consistently.

## 10. First use, completion, history, and data confidence

Observed: onboarding requires a nonempty name. History already has a search affordance and date/exercise search. Backup/import and diagnostic logs already exist. Export diagnostics and large-conversation preservation were fixed in 2.2.1.

Proposal:

- Offer empty workout, starter routine, and restore at first use; make personalization skippable. Request health and AI setup when useful. Confirm how app initialization detects onboarding completion before allowing name omission.
- Finish with an unequivocal saved state, compact factual comparison, Done, contextual Coach, and Save as routine where applicable. Do not claim a workout is saved before persistence succeeds.
- Make history search readily visible, add meaningful filters, and simplify set corrections with save/cancel and undo where feasible. Define effects on derived records, analytics, and Health Connect sync; preserve original session metadata.
- Show backup handoff outcome with precise wording. A share handoff does not prove a recoverable file exists. Keep diagnostics in About.
- Preview restore contents and explain duplicate/conflict behavior before applying. Selective restore and Review matching items are proposed capabilities, not assumed existing features. Inspect import semantics, define stable identity/conflict policy, and guard against partial destructive restore before exposing controls.

## Flow goals to validate

| Task | Current evidence | Intended improvement |
| --- | --- | --- |
| Start usual workout from Home | Start opens selection | Direct start for a justified choice, chooser remains available |
| Repeat a varied set sequence | Last set initializes values | Match corresponding historical set where appropriate |
| Prepare during rest | Full-screen timer replaces inputs | Inputs remain accessible with inline timer |
| Leave session temporarily | Resume exists on Home | Explicit Minimize and persistent Resume |
| Ask about a workout | Coach is a separate chat | Context passed from session or summary |
| Understand missing readiness | Current measurements may be absent | Specific missing-data and freshness explanation |

These are intended interaction improvements, not measured tap-count or retention claims.

## Suggested implementation slices

1. Home action resolution, honest routine labels, weekly consistency, direct start, and persistent Resume.
2. Corresponding-set defaults, set correction/Undo, inline timer, and clear leave/finish/discard actions.
3. Exercise navigation/substitution and Train organization; retain advanced routine/program features.
4. Contextual Coach and clear approvals; truthful recovery/freshness states.
5. Onboarding, summary/history refinements, backup/restore preview, and accessibility/preferences polish.

Deliver complete, reviewable slices; do not combine data migrations and the whole UI revamp in one unvalidated rewrite. The first two slices have the highest expected everyday value, but effort and benefit have not been measured.

## Validation

Use realistic tasks: start usual routine; log three sets with varying weights; correct a mistake; prepare during rest; minimize/resume; substitute occupied equipment; finish/save; find/edit history; inspect missing health data; restore a backup. Track hesitation, accidental actions, taps, and elapsed task time through explicit usability sessions. Do not add telemetry by default.

Use meaningful tests for action resolution, set precedence, undo/correction, timer lifecycle, workout conflicts, substitutions, import conflicts, and AI approval semantics. Add focused widget/golden coverage where it helps verify layout and accessibility. Run repository-required checks; preserve release/version policy. Verify on device before claiming interaction or accessibility validation.

## Source map

Paths relative to repository root:

- `workout-logger/lib/screens/home_screen.dart`
- `workout-logger/lib/screens/routines_screen.dart`
- `workout-logger/lib/screens/workout_flow_screen.dart`
- `workout-logger/lib/screens/widgets/rest_timer_view.dart`
- `workout-logger/lib/screens/widgets/workout_header.dart`
- `workout-logger/lib/screens/widgets/routine_creator.dart`
- `workout-logger/lib/screens/onboarding_screen.dart`
- `workout-logger/lib/screens/history_screen.dart`
- `workout-logger/lib/screens/analytics_screen.dart`
- `workout-logger/lib/screens/workout_summary_screen.dart`
- `workout-logger/lib/screens/ai_coach_screen.dart`
- `workout-logger/lib/screens/widgets/agent_change_queue.dart`
- `workout-logger/lib/screens/widgets/readiness_card.dart`
- `workout-logger/lib/screens/widgets/profile_sections.dart`
- `workout-logger/lib/screens/profile_screen.dart`
- `workout-logger/lib/services/sqlite_storage_service.dart`
- `workout-logger/lib/services/ai/sql_query_service.dart`
- `workout-logger/lib/theme/app_theme.dart`
- `fastlane/metadata/android/en-US/images/phoneScreenshots/`

Reinspect current main before implementing; this audit reflects the 2.2.1-era code reviewed in this conversation.
