# Recommendation Engine Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the gap between what `MLService` can already compute and what actually reaches the user during a workout, then extend the model with the inputs it's currently blind to (readiness, effort, intra-session fatigue) — all estimated from data already collected, with **zero additional per-set user input** — without breaking the offline, zero-latency requirement of the in-workout recommendation card. Along the way, split `MLService`'s accumulated responsibilities to match this codebase's existing SOLID conventions (`managers/`, `strategies/`, `interfaces/`).

**Non-goal:** Replacing the classical model with a cloud LLM call on the hot path. The recommendation must render synchronously while the user is mid-set with no network. An LLM-backed layer is scoped as an optional *secondary* explanation feature (Phase 6), not a replacement for the deterministic engine.

**Product decisions locked in for this plan:**
- No manual per-set RPE picker — the user logs weight/reps only, same as today. Effort is *estimated*, never asked, per set.
- One optional once-per-workout question ("How did that session feel?" — 3 chips) is acceptable since it's asked once, not per set, and it's the only real calibration anchor the estimator has.
- Heart-rate data is optional and frequently absent (sync gaps) — every HR-dependent signal must degrade to a fully HR-less computation with no behavior change when HR is missing, never block or error.
- Flutter SDK is `3.44.8` (`workout-logger/pubspec.yaml:23`) — `CLAUDE.md`'s "3.41.5" is stale; no action needed here, just don't trust that doc for the SDK version.

---

## Audit findings (why each task exists)

Confirmed by reading `lib/services/ml_service.dart`, `lib/services/workout_provider.dart`, `lib/services/managers/analytics_manager.dart`, `lib/services/managers/readiness_manager.dart`, `lib/services/utils/readiness_calculator.dart`, `lib/services/ai/coach_tool_service.dart`, and `lib/models/models.dart`:

1. **Recovery-aware branch is dead code in production.** `MLService.recommendSets()` has a fully-implemented "under-recovered primary muscle → hold, don't progress" path (`ml_service.dart:433-476`), gated on `recoveryScores` + `primaryMuscleIds` params. **Neither live caller passes them** — not `WorkoutProvider.getRecommendations` (`workout_provider.dart:666`, the one the workout screen actually uses) nor `AnalyticsManager.getRecommendations` (`analytics_manager.dart:135`).
2. **No intra-session fatigue.** Zero awareness of what the user already did *earlier in today's session*. Deload/plateau detection only looks at day-to-day history of the *same* exercise.
3. **Readiness (sleep/RHR/HRV) is display-only.** `ReadinessManager`/`ReadinessCalculator` compute a real 0–100 score, cached and shown on `readiness_card.dart`, never read by `MLService`.
4. **No effort signal at all**, estimated or otherwise. `WorkoutSet` has no RPE-like field; the model can't tell an easy top set from a grinder.
5. **Per-exercise, not program-aware.** Each exercise's recommendation is computed in isolation.
6. **Two call sites, diverging behavior.** `WorkoutProvider.getRecommendations` passes `pastSessions` (deload detection works there) but not recovery data. `AnalyticsManager.getRecommendations` passes neither (deload detection dead there too). Every future param has to be added in both places or they drift further.
7. **`MLService` violates SRP.** One 640-line class does curve-fitting math, recovery scoring, recommendation heuristics, and target-date prediction — unlike the rest of the codebase's `managers/`/`strategies/`/`interfaces/` split.
8. **A second "brain" already exists and is underused.** The Gemini-backed AI Coach (`coach_tool_service.dart`) already has tool-calling access to muscle recovery, targets, and history, but it's a separate on-demand chat feature, not wired into the automatic per-set card.

---

## Global Constraints

- Flutter SDK `3.44.8`. All commands run from `workout-logger/`.
- `flutter analyze` reports 0 issues at the end of every task.
- The in-workout recommendation call (`WorkoutProvider.getRecommendations`) stays **synchronous and offline** — no `await`, no network, no fresh Health Connect reads. Anything needing I/O (readiness, HR) must already be cached in memory before the card renders, exactly as `ReadinessManager` caches its snapshot today.
- Preserve `IMLService`'s role as the stable facade every call site depends on — see Phase 2's "keep the facade" decision. `MockMLService` (`test/test_utils/mock_ml_service.dart`) and Mockito-generated mocks must be updated in lockstep with any interface signature change (`dart run build_runner build --delete-conflicting-outputs`).
- No behavior change ships without a test in `test/ml_service_test.dart` (or a new file) demonstrating the new branch fires and every existing branch's output is byte-identical to before.
- New tunable constants (thresholds, caps) go in as named `static const` near the existing ones (e.g. `_plateauWeeklyPct` in `ml_service.dart:341`), never as magic numbers inline.
- Commit after every task. Conventional commit prefixes (`feat:`, `fix:`, `test:`, `refactor:`).

---

## Phase 1 — Wire up what already exists (ship first, independent of everything else)

Pure bug fix: connect signals that are already computed but discarded. No new logic.

- [x] **1.1** Add `recoveryScores` + `primaryMuscleIds` to the call in `WorkoutProvider.getRecommendations` (`workout_provider.dart:666`). Source: `computeMuscleRecoveryScores(_sessions, exerciseMap)` (already used at `workout_provider.dart:1053`) + `Exercise.primaryMuscle` (the existing single-highest-activation getter, reused as-is rather than inventing a new "≥50%" threshold not used elsewhere in the codebase).
- [x] **1.2** Did the same for `AnalyticsManager.getRecommendations` (`analytics_manager.dart:135`), plus `pastSessions` (was missing — its deload detection was dead too). Note: `AnalyticsManager` currently has **zero live callers** anywhere in the app (verified — not wired into `main.dart` or any screen); this fix is precautionary/for whenever it's wired up, not a live-bug fix like 1.1. Signature follows the existing `exercises`/`exerciseMap` optional-param convention already used by `getWeeklyVolumeByMuscle` in the same file, so old 2-arg call sites stay valid.
- [x] **1.3** Tests added: `workout_provider_test.dart` ("holds load when the primary muscle is still under-recovered...", exercised through `WorkoutProvider`, not `MLService` directly — the test that would've caught the original gap) and two in `analytics_manager_test.dart` (params reach the mock when exercise data is supplied; omitted when it isn't, for backward compatibility). `MockMLService` extended with `lastPastSessions`/`lastRecoveryScores`/`lastPrimaryMuscleIds` tracking fields.
- [x] **1.4** `flutter analyze` clean (5 files), `flutter test` green (103/103, including the 3 new tests). Not committed — awaiting the user's go-ahead per this repo's "only commit when explicitly asked" policy.

## Phase 2 — MLService refactor into SOLID collaborators

**Decision:** keep `IMLService` as a stable facade; split the *implementation* into four collaborators, so DI wiring (`main.dart`) and every call site are untouched while the internals become testable independently. Land this **before** Phases 3–5 so the new signals arrive as additive rules, not more edits to a 70-line if/else.

| New file | Owns | Moved from |
|---|---|---|
| `lib/services/strategies/growth_curve_fitter.dart` (`IGrowthCurveFitter`) | WLS fit, Tukey re-weighting, linear/log selection, `predictTargetCompletion`/`predictTargetWithConfidence` (prediction is the curve's inverse — belongs with the fit) | `ml_service.dart:17-216, 545-621` |
| `lib/services/utils/recovery_calculator.dart` (`const RecoveryCalculator()`) | `_tauHours`, `computeMuscleRecoveryScores`, shared `muscleVolumes` helper | `ml_service.dart:34-53, 269-334` |
| `lib/services/utils/effort_estimator.dart` | Estimated-RPE logic — see Phase 3 | new |
| `lib/services/strategies/progression_rules.dart` | `ProgressionRule.apply(ProgressionContext) → SetRecommendation?` (null = "not mine, try next") + an ordered `ProgressionRuleChain`, registry shaped like `TargetCalculatorFactory` (`target_calculator.dart:88-125`) with a `reset()` for test isolation | `ml_service.dart:459-529` |

Recovery goes in `utils/`, not `managers/` — managers in this repo are `ChangeNotifier` state owners (`managers.dart`); recovery scoring is stateless and pure, same shape as `ReadinessCalculator`.

`MLService` shrinks to ~120 lines of delegation, collaborators injected as optional constructor params defaulting to concretes (the same idiom `WorkoutProvider(..., IMLService? mlService)` already uses at `workout_provider.dart:91-94`). `extractExerciseDataPoints`/`extractMuscleDataPoints` stay put (thin model→`DataPoint` adapters). `trainGrowthModelStatic` (`ml_service.dart:65`) has no external callers — delete it, don't migrate it.

Call-site convergence for the Phase 1 fix and future params: one shared parameter-assembly function in `lib/services/utils/exercise_history.dart` (already imported by `AnalyticsManager`), so `WorkoutProvider.getRecommendations` and `AnalyticsManager.getRecommendations` can no longer drift apart (audit item 6).

- [x] **2.1** Extracted `GrowthCurveFitter` + `IGrowthCurveFitter` into `lib/services/strategies/growth_curve_fitter.dart`; `MLService` delegates via an injected `_curveFitter`. Deleted `trainGrowthModelStatic`. `predictTargetWithConfidence` moved to `GrowthCurveFitter.predictTargetWithConfidence` (static) — the one test call site (`ml_service_test.dart`) updated to match. `MLService`/`IGrowthCurveFitter`/`GrowthCurveFitter` re-exported from `ml_service.dart` so existing `import 'ml_service.dart'` call sites needed no changes.
- [x] **2.2** Extracted `RecoveryCalculator` (incl. public `muscleVolumes`, reusable by Phase 5's fatigue accumulator) into `lib/services/utils/recovery_calculator.dart`; `MLService` delegates via an injected `_recoveryCalculator`.
- [x] **2.3** Introduced `ProgressionContext` + `ProgressionRule` + `ProgressionRuleFactory` in `lib/services/strategies/progression_rules.dart`; ported all five branches (under-recovered, post-deload, decline, plateau, double-progression) verbatim as `UnderRecoveredRule`/`PostDeloadRecoveryRule`/`DeclineDeloadRule`/`PlateauRule`/`DoubleProgressionRule`. `MLService.recommendSets` now builds a `ProgressionContext` and calls `ProgressionRuleFactory.apply`.
- [x] **2.4** Added `ProgressionRuleFactory.reset()` + `registerRuleAtHead()`; new `test/progression_rules_test.dart` (15 tests) covers every rule in isolation plus chain ordering, override, and reset — mirroring `target_calculator_test.dart`'s pattern.
- [x] **2.5** Added `recoveryRecommendationInputs()` to `lib/services/utils/exercise_history.dart`; both `WorkoutProvider.getRecommendations` and `AnalyticsManager.getRecommendations` now call it instead of duplicating the recovery-score/primary-muscle assembly, so they can't drift apart again.

**Verification:** whole-project `flutter analyze` clean; full `flutter test` run is 963/964 green — the 1 failure (`readiness_manager_test.dart`, an HR-fallback test) reproduces only in the full-suite run and passes standalone, and touches no file this refactor changed (confirmed unrelated pre-existing flakiness, not investigated further as out of scope). All pre-existing `ml_service_test.dart`/`workout_provider_test.dart`/`analytics_manager_test.dart`/`target_calculator_test.dart` assertions pass unmodified except the one `predictTargetWithConfidence` call-site rename noted in 2.1 — confirming the refactor is behavior-preserving. Not committed (repo policy: commit only on explicit request).

## Phase 3 — Estimated effort (RPE), no per-set input

**Decision:** a pure `EffortEstimator` (`lib/services/utils/effort_estimator.dart`, `const`-constructible, injected like `ReadinessCalculator` into `ReadinessManager`) producing a continuous **0–10 estimated RPE plus an explicit source + confidence** — never a bare number, so a future real RPE picker is a drop-in `EffortSource.userReported, confidence: 1.0` with zero call-site churn.

New model in `lib/models/models.dart` near `SetRecommendation` (`models.dart:469`): `EffortEstimate { double rpe; EffortSource source; double confidence; }`, `enum EffortSource { userReported, estimatedWithHr, estimatedHrless }`.

Anchor at RPE 8 (double progression already assumes near-failure working sets), four additive terms, all using data already logged today:

1. **Trend deviation** — `z = (actualVolume − growthModel.predict(x)) / max(stdError, 0.05·predict(x))`, gated on `r2 > 0.2` (reuses `_minR2ForTrendSignal`, `ml_service.dart:343`). Term `−0.8·clamp(z, −2, 2)`.
2. **Intra-session decline** — volume ratio of last set vs. first set of the same exercise this session (via `WorkoutSet.volume`, not rep count, so it absorbs dropsets/assisted-weight sets correctly). Deadband ≤5%. Term `+3.0·clamp(declineFrac − 0.05, 0, 0.5)`.
3. **Rest/tempo (free, already logged, currently unused)** — `WorkoutSet.timestamp` (`models.dart:134`) gives inter-set gaps, `timeTaken` (`models.dart:133`) gives per-set duration. Longer-than-usual gaps or slower-than-usual reps vs. this exercise's own history both push RPE up.
4. **HR — optional, additive only.** Only used if Health Connect returns ≥3 samples inside the set window; normalized *within the session* (`hrFrac = (setPeak − sessionFloor)/(sessionPeak − sessionFloor)`). Absent → term 0, confidence unaffected downward, never blocks the estimate.

`rpe = clamp(8.0 + calibrationOffset + Σterms, 5.0, 10.0)`.

**Confidence:** base 0.35, +0.20 trend gate passed, +0.20 if ≥3 sets logged, +0.15 if HR term fired, +0.10 if ≥6 sessions history — **capped at 0.85** (real user-reported RPE, if ever added, is the only thing that reaches 1.0). Consumers may only let effort change a *branch* at `confidence ≥ 0.6`; below that it only enriches `SetRecommendation.reasoning` text.

**Once-per-workout chip (Easy / Solid / Brutal) — include it.** It's the only real calibration signal available: rolling `calibrationOffset = mean(chipValue − estimatedSessionMeanRpe)` over the last 10 answered sessions (Easy→6.5, Solid→8, Brutal→9.5), clamped ±1.0. Store as nullable `WorkoutSession.sessionEffort` (int 1–3) — nullable means no Hive migration, and skipping it is a first-class path with `calibrationOffset = 0`.

- [x] **3.1** Added `EffortEstimate`/`EffortSource` to `models.dart` (next to `SetRecommendation`); added nullable `WorkoutSession.sessionEffort` with `toJson`/`fromJson`/`copyWith` round-trip.
- [x] **3.2** Created `lib/services/utils/effort_estimator.dart` with terms 1–3 (trend deviation, intra-session decline, rest/tempo drift — all HR-less, pure, synchronous). 19 unit tests in `test/effort_estimator_test.dart` covering every term in isolation, the confidence ladder, and RPE clamping.
- [x] **3.3 (revised design):** Rather than accepting `IHealthConnectService?` and fetching samples itself, `EffortEstimator.estimate()` takes an optional **pre-resolved** `HrEffortSignal?` (peak bpm in the set's window + session floor/ceiling). Reason: the in-workout recommendation path must stay synchronous/offline (a hard constraint from this plan's Global Constraints), so `EffortEstimator` cannot do Health Connect I/O itself. It's a pure function ready to receive HR data whenever an upstream caller resolves it — tested directly with synthetic `HrEffortSignal` values (4 tests: null, too-few-samples, near-ceiling, well-below-ceiling). **Not done in this pass:** actually wiring a live Health Connect read into the hot path — that needs a caching layer analogous to `ReadinessManager`'s snapshot, which doesn't exist yet for per-set HR. Flagged as a natural follow-up, not built speculatively (no consumer ready to use it yet).
- [x] **3.4** Added the post-workout chip row (`_EffortChipRow` in `workout_summary_screen.dart`, Easy/Solid/Brutal) + `EffortCalibration` (`lib/services/utils/effort_calibration.dart`) implementing the rolling offset as an exponential moving average (α≈0.1, approximates a ~10-session rolling mean without persisting per-session history) rather than storing raw history. `WorkoutProvider.recordSessionEffort()` persists both the session's `sessionEffort` and the offset via `IStorageService.saveSetting`. Tests: `test/effort_calibration_test.dart` (7, incl. convergence/clamping) + 4 in `workout_provider_test.dart` (default 0.0, records + updates offset, persists across reload, no-op for unknown session).

## Phase 4 — Readiness-aware modulation

- [x] **4.1** `WorkoutProvider.getRecommendations` now takes an optional `ReadinessBand? readinessBand` (not the full snapshot — the rule chain only ever needed the band). Wired from `WorkoutFlowScreen` via `context.watch<ReadinessManager?>()?.snapshot?.band` — the **nullable-typed** lookup was required: an earlier attempt with `context.watch<ReadinessManager>()` (non-nullable) threw `ProviderNotFoundException` in `userflow_workout_logging_test.dart`, which mounts `WorkoutFlowScreen` without the full `main.dart` provider tree. Nullable lookup resolves to `null` gracefully instead, preserving the screen's existing testability.
- [x] **4.2** Added `ReadinessRule` to `progression_rules.dart` at priority 3 (after under-recovered/post-deload, before the new `SessionFatigueRule` and decline/plateau) — reasoning: readiness is a whole-day physiological signal like under-recovery, so it outranks same-session-local fatigue and multi-session trend holds. `ProgressionContext` gained `bool isLowReadiness = false` (defaulted, so the one existing `ml_service.dart` call site needed no changes for this field alone).
- [x] **4.3** No explicit check needed in `MLService`/`WorkoutProvider` — `ReadinessManager.refresh()` already gates on `_settings.readinessEnabled` internally (`readiness_manager.dart:66`) and leaves `snapshot` `null` when disabled/no Health Connect permission, so a disabled/unavailable readiness feature naturally degrades to `readinessBand: null` → `isLowReadiness: false` with zero behavior change.
- [x] **4.4** Tests in `workout_provider_test.dart`: low band holds load even when reps are at the ceiling (verified against a same-setup baseline that *does* progress, to prove the suppression is real); moderate band is a no-op.

## Phase 5 — Intra-session fatigue model

**Decision: per-muscle *hard-set-equivalent* accumulation with a continuous dampening factor**, using the Phase 3 effort estimate — not raw tonnage (a leg-press set and a lateral-raise set aren't comparable in kg), not relative-to-typical-volume (would need a history query on the synchronous hot path).

```
hardSets[muscleId] = Σ over sets already logged today, excluding the current exercise
      (activation% / 100) × clamp((estimatedRpe − 6) / 3, 0, 1)
```
Activation weighting reuses the Phase 2 `RecoveryCalculator.muscleVolumes` helper rather than a second copy of that loop.

```
f = clamp((hardSets − softCap) / (hardCap − softCap), 0, 1)   // softCap = 6, hardCap = 12
```
- `f = 0` → untouched.
- `0 < f < 1` → **scales, doesn't block**: weight-progression increment × `(1 − f)`, snapped to the nearest 2.5 kg plate (so `f > 0.5` naturally becomes "hold weight, reset reps"), confidence drops `high → medium`.
- `f ≥ 1` → early exit, same output shape as the under-recovered rule, distinct reasoning ("≈N hard sets for chest already this session — hold and finish strong").

**Priority in the Phase 2 rule chain:** the `f ≥ 1` exit sits *after* under-recovered and post-deload (those are multi-day physiological/protocol states and dominate), but *before* decline/plateau — deloading 10% while also mid-session-fatigued double-penalizes, and "rebuild next session" isn't the right advice for a fatigue state that resolves by tomorrow. `0 < f < 1` doesn't short-circuit; it flows through as a multiplier on whatever the later rules decide.

Data source: `WorkoutProvider`'s in-progress session state, already in memory — zero I/O, preserves the offline constraint.

- [x] **5.1** Added `SessionFatigueAccumulator` (`lib/services/utils/session_fatigue.dart`): `hardSetEquivalents({exerciseLogs, exerciseMap, excludeExerciseId})`, using `EffortEstimator` (HR-less, no growth model — just the decline/tempo terms plus the RPE-8 base anchor) per set, `clamp((rpe-6)/3, 0, 1)` for hardness, weighted by each exercise's muscle-activation percentages. 7 tests in `test/session_fatigue_test.dart`.
- [x] **5.2** Added `readinessBand`/`sessionHardSets` params to `recommendSets` on both `IMLService` and `MLService` (no separate `primaryMuscleIds` needed — it already existed and is reused for the fatigue lookup too, same as recovery). Updated `MockMLService` with `lastReadinessBand`/`lastSessionHardSets` tracking. No Mockito-generated mock exists for `IMLService` (verified via search) — only the hand-written `MockMLService` needed updating.
- [x] **5.3** Added `SessionFatigueRule` (hard-hold at `f ≥ 1.0`) to the chain, plus modified `DoubleProgressionRule` itself to scale its weight-progression increment by `(1 − f)` for `0 < f < 1`, snapped to the nearest 2.5kg plate — this couldn't be a separate rule since partial dampening isn't a "hold, stop the chain" decision, it has to modify what the terminal rule would otherwise do. Verified byte-identical output at `f = 0` (the default) with a dedicated test. `_fatigueSoftCap`/`_fatigueHardCap` (6.0/12.0) added as named constants in `ml_service.dart` beside `_plateauWeeklyPct`; the `recommendSets` priority-order doc comment updated to the full 8-tier list.
- [x] **5.4** Wired from `WorkoutProvider.getRecommendations` via a `SessionFatigueAccumulator` field, computed from `_currentExerciseLogs` (already in memory — zero I/O) excluding the exercise being recommended. 4 integration tests in `workout_provider_test.dart` using real `startWorkout`/`addSet`/`nextExercise` flows: same-primary-muscle exercise dampened after heavy prior sets (compared against a fresh provider with no in-progress session, to isolate the effect); a different, unrelated muscle group is unaffected.

## Phase 6 — "Bigger model" evaluation (spike, completed 2026-08-18)

Executed as a code-grounded architecture review (Opus subagent) plus an actual backtest of the shipped engine against a real 74-session export (`repforge_backup_2026-08-02_221350.json`, 832 simulated set-recommendations). No code changed in this phase — findings only.

### Q1: Keep the ordered rule chain, or convert to a scored/weighted composite?

**Decision: keep the chain.** Four of the seven rules (`UnderRecoveredRule`, `ReadinessRule`, `SessionFatigueRule`, `PlateauRule`) return numerically identical output (`weight: c.set.weight, reps: c.set.reps`) — they differ only in which *reasoning string* wins, i.e. the chain isn't blending four numbers, it's selecting an explanation for one shared "hold" outcome. A scored composite would have to sum contributors into a pressure number and then separately argmax them back apart to pick a sentence — that's the chain, reimplemented with extra state. Worse, `isUnderRecovered`'s veto (it must win outright regardless of how good the trend looks) isn't expressible as a smooth weight without a sentinel/infinite term, i.e. a hard gate wearing a score's clothing. Where the code genuinely needed continuity (partial same-session fatigue), it already lives *inside* the chain as a multiplier on the one rule that computes a delta (`DoubleProgressionRule`), not as a competing score. That's the correct shape: hard gates for veto states, one continuous modulator on the terminal rule.

### Q2: Give the Gemini AI Coach a `_setRecommendation`/`_explainRecommendation` tool?

**Decision: no — and the actual blocker is upstream of the LLM question.** `SetRecommendation.reasoning` — the carefully-worded string every rule produces — has exactly one reference in all of `lib/`: its own declaration. `_RecommendationCard` (`exercise_input_section.dart`) renders only the weight/reps and an unlabelled confidence dot; the reasoning text is asserted in tests but never shown to a user. Building a Coach tool to *explain* a decision nobody has been shown a single word about is solving the wrong layer. Do the free fix first: render `rec.reasoning` in the card (and label the confidence dot). Revisit the Coach tool only if, after reasoning is visible, chat transcripts or a "why?" tap-through show real demand for something richer than what's already computed and sitting unused.

### Real-data backtest — the second most useful finding of this phase

Backtested the exact shipped `MLService`/`ProgressionRuleFactory` against 74 real sessions (832 simulated recommendations, mirroring `WorkoutProvider.getRecommendations`'s exact inputs at each historical point in time — no data leakage from future sessions):

| Rule | Fired |
|---|---|
| `DoubleProgressionRule` (add rep) | 420 (50.5%) |
| `DoubleProgressionRule` (weight bump) | 137 (16.5%) |
| `UnderRecoveredRule` | 119 (14.3%) |
| `PostDeloadRecoveryRule` | 77 (9.3%) |
| `DeclineDeloadRule` | 50 (6.0%) |
| `PlateauRule` | 29 (3.5%) |
| `SessionFatigueRule` / fatigue-scaled progression | **0 (0.0%)** |

The Phase 1 recovery-gate fix (`UnderRecoveredRule` + `PostDeloadRecoveryRule`) is doing real, substantial work for this user — nearly a quarter of all recommendations. **Phase 5's same-session fatigue signal never fired once.** 159 of 832 sets had *some* non-zero same-session hard-set accumulation for their primary muscle, but the highest value ever reached across all 74 sessions was **5.13** — under the `_fatigueSoftCap = 6.0` threshold every time. This user's actual training pattern (rotating through many distinct exercises per session rather than stacking several heavy sets on overlapping muscles back-to-back) never generates enough same-session overlap to cross into the dampening zone as calibrated.

This doesn't mean Phase 5 is wrong — it means `_fatigueSoftCap`/`_fatigueHardCap` (6.0/12.0, always flagged as unvalidated guesses) are calibrated for a different training style than this real user's. **Action for whenever this gets tuned:** lower `_fatigueSoftCap` toward ~4–5 and re-backtest, or gather a session with genuinely stacked same-muscle work (e.g. a push-day superset) to find a real threshold instead of guessing again. Also confirmed separately: `readiness.snapshot` in this export was cached once at `band: moderate` — never `low` — so `ReadinessRule` had no opportunity to fire in this dataset either; no conclusion possible from this backup about its calibration.

**Also surfaced, unrelated to the two questions but found while reading the export:** the backup's `settings` block contains a plaintext `geminiApiKey`. Flagged to the user directly — recommend rotating that key and confirming this export file isn't synced/committed anywhere.

---

## Phase 7 — Remove `muscleActivations` from the fatigue path (completed 2026-08-19)

The user pointed out a concrete real case the Phase 6 backtest's calibration missed: their back/bicep routine trains Lat Pulldown, Seated Cable Row, and Pull-ups back to back, and order visibly affects performance — but investigating found `seated_cable_row`'s highest-activation muscle is `'back'` (70%) while `lat_pulldown`/`pull_ups`' is `'lats'` (75–80%) — **separate, non-aliased ids** in this app's hand-authored taxonomy (`exercise_database.dart:9-16`). Since Phase 5's fatigue gate only checked `[exercise.primaryMuscle]` (a single label) against the accumulated map, cross-talk between these three near-identical pulling movements depended on accidents of which label the exercise database's author happened to pick as "primary" for each. The user's explicit instruction: *"Don't rely much on this muscle activation data (as it's hardcoded, and I don't think any medical reference backs this), just make relationships based on the data."*

Rather than patch the taxonomy (e.g. broadening to "all significantly-activated muscles"), a deeper spike (Opus subagent, grounded in the real 74-session export) tested whether a same-session order effect is statistically detectable **at all**, independent of muscle labels:

- **Pooled effect across all exercises: r = 0.005, t = 0.09, n = 309** (session-demeaned regression of trend-residual performance against prior in-session hard-set count). Effectively zero.
- **Per-exercise coefficients that looked real didn't replicate** on a split-half check (e.g. `hammer_curl`: −0.52 in the first half of history, +0.11 in the second).
- **Order barely varies in this user's real routine** — 73 of 85 logged exercise pairs have *zero* counterfactual observations (always trained in the same relative order), and a plausible 3–5% order effect is smaller than the 2.6–13.8% session-to-session noise on most exercises' top-set performance. No model — linear, GRU, or transformer — can be fit reliably against noise this size with this little contrastive data; a user-proposed LSTM/attention approach was evaluated and rejected on the same grounds (far more parameters than the 1-parameter linear model that already failed to generalize, against the same starved, noisy dataset).
- **The only identifiable unit was a single exercise-agnostic scalar** — total prior same-session hard-set-equivalents, not attributed to any muscle or specific prior exercise.

**Implemented:** `SessionFatigueAccumulator.factorFor()` (`lib/services/utils/session_fatigue.dart`) now sums RPE-weighted hardness across all of today's earlier sets with **no `Exercise.muscleActivations` dependency at all** — it no longer even takes an `exerciseMap` parameter. `IMLService.recommendSets`/`MLService.recommendSets` replaced `Map<String, double>? sessionHardSets` with a single `double sessionFatigueFactor = 0.0`, computed upstream by `WorkoutProvider` and passed straight through — `ml_service.dart` no longer does any per-muscle lookup or cap math itself (`primaryMuscleIds` now serves the recovery gate only). `ProgressionContext`, `SessionFatigueRule`, and `DoubleProgressionRule` needed **zero changes** — they already consumed a plain `double`.

**Calibration, not a guess:** re-ran a backtest of the new formula against the same 74-session export (254 real same-session contexts) and found real-set totals up to **11.87**, median 4.56. The new `_softCap`/`_hardCap` (16.0/24.0) sit comfortably above the observed max, so the factor evaluates to exactly `0.0` on every real historical case — an explicit, verified "must not ship as a behavior change" guarantee rather than an assumption. This is an intentionally inert placeholder, documented as such in the accumulator's file header, ready to be recalibrated downward once genuine order-variation data exists (the deferred "occasionally suggest swapping exercise order" data-collection nudge from the Phase 6 spike is what would generate that data).

Tests: `test/session_fatigue_test.dart` fully rewritten for the new scalar API (no `Exercise` fixtures needed at all now); two `workout_provider_test.dart` integration tests updated — one confirms realistic session sizes produce zero behavior change (verified against a fresh-provider baseline), one confirms an extreme, unrealistic session (40 sets) still dampens, proving the mechanism is wired end-to-end even though real sessions never reach it. Full suite verified green.

---

## Suggested sequencing

**1 → 2 → 3 → (4 and 5 in either order, 5 depends on 3) → 6.** Phase 1 is a same-day bug fix. Phase 2 is a pure refactor with no behavior change — verify with byte-identical-output tests before adding anything new on top of it. Phases 3–5 are each independently shippable; 5 needs 3's effort estimate as an input, so it can't land first. Ship and observe after each phase rather than batching — the thresholds introduced in Phases 3 and 5 in particular (the 8.0 RPE anchor, `softCap`/`hardCap`) are unvalidated constants that will need tuning against real user feedback, and that's much easier to isolate one phase at a time.

---

## Status: Phases 1–5 implemented (2026-08-18)

All tasks above are done. Final verification: whole-project `flutter analyze` — 0 issues. Full `flutter test` — **1014/1014 passing** (the 1 pre-existing flaky failure noted after Phase 2 did not reproduce in the final full run, consistent with it being unrelated ordering/timing flakiness in `readiness_manager_test.dart`, not a regression from this work).

**New files:** `strategies/growth_curve_fitter.dart`, `strategies/progression_rules.dart`, `utils/recovery_calculator.dart`, `utils/effort_estimator.dart`, `utils/effort_calibration.dart`, `utils/session_fatigue.dart`, plus 6 new test files (`progression_rules_test.dart`, `effort_estimator_test.dart`, `effort_calibration_test.dart`, `session_fatigue_test.dart`, and additions to `model_serialization_test.dart`/`workout_provider_test.dart`/`analytics_manager_test.dart`).

**Known gaps, called out honestly rather than papered over:**
- The HR term in `EffortEstimator` is fully implemented and tested but not wired to a live Health Connect read anywhere — it needs a caching layer that doesn't exist yet (see Phase 3.3's note). Every constant fed to it in production today is `null`, so it never fires outside of tests.
- All the new thresholds (RPE-8 anchor, `_fatigueSoftCap`/`_fatigueHardCap`, `EffortCalibration`'s α=0.1) are engineering estimates, not tuned against real user data. Expect to revisit them after Phase 6's usage-data checkpoint.
- `AnalyticsManager.getRecommendations` received the Phase 1 recovery-data fix for consistency but was **not** extended with `readinessBand`/`sessionHardSets` — it still has zero live callers in the app, so this was judged out of scope rather than speculative work.

**Not committed.** Every phase's changes are sitting in the working tree, verified but uncommitted, per this repo's "only commit when explicitly asked" policy.
