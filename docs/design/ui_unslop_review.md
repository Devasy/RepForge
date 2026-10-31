# RepForge UI refinement review

Refined using [Unslop by Damir Sokolovsky (@heydamir)](https://github.com/heydamir/unslop/blob/main/skills/unslop/SKILL.md), CC BY 4.0. The user’s deliberate visual choices take precedence over generic cleanup rules.

## Current direction: preserve the glass, refine the hierarchy

The background lighting and graded glass material were deliberately designed by the user. They are part of RepForge’s identity and must be preserved. The initial neutral treatment removed too much character; later refinements retain violet actions, the original glass treatment and useful feedback while improving legibility and layout.

- **Product:** A training log for lifters recording sets and reviewing their progress.
- **Character:** Focused, tactile, luminous.
- **World:** The existing dark glass interface with its authored violet lighting.
- **Moments:** Glass surfaces reveal the background light; completed activity forms a green calendar; the active set and Log set action lead the logging screen.
- **Signature:** RepForge’s violet actions, graded glass edges and consistent weight × reps notation.

## Why the retained effects belong

Unslop asks whether color, material and motion serve the product. Here the background provides the light that makes the translucent glass readable. Removing it changes the intended material rather than merely reducing visual clutter. This is a polish pass around that material, not a replacement aesthetic.

Green is appropriate for the activity calendar: it represents completed training and has a familiar habit-calendar association. Use one green hue with increasing intensity, retain a neutral empty cell, and keep violet for interactive selection and primary actions. A brighter cell means a higher activity bin, not greater recovery or readiness. Muscle and recovery colors keep their existing meanings.

## Current implementation

- Restored the original dark surface tokens, ambient floor, radial light pools, motion/reduced-motion behavior, glass fill and graded edge painter from the existing repository.
- Retained transparent Material and InkWell layers so card interactions, keyboard access and ListTile ink remain visible on the glass.
- Changed the activity calendar to green `#4CC38A`; the cells and Less/More legend now share one intensity scale. The underlying training data is unchanged.
- Kept violet primary actions and selected Home navigation, haptic feedback, readable text roles and native pressed/focus states.
- Kept weight and reps paired where readable, with 48px stepper targets beneath the values. Large-text layouts still stack without clipping.
- Kept session history close to set entry and Log set anchored at the bottom.

## Previews and validation

Latest Flutter captures with sample data: [Home](previews/refined_home.png) and [green activity calendar](previews/refined_activity.png). These show the preserved glass material and lighting at 390 × 900 logical pixels, with the animation paused for a stable capture. Earlier [workout](previews/refined_workout.png) and [Analytics](previews/refined_analytics.png) captures document the preceding layout pass and predate the restored glass material.

- 35 affected widget/screen regressions pass, covering shared cards, health widgets, Home, narrow and large-text layouts, and screen navigation.
- The Home/activity capture check passes; changed-file Flutter analysis reports no issues.
- The prior character/layout pass passed 82 regression tests, including real-font paired-input and nearby-history checks.
- Device rendering, platform accessibility services and the live background animation still merit an Android review; widget captures do not establish device behavior.
- Graphify is unavailable in this environment, so its requested graph refresh cannot run.

## Historical audit and proposal

The audit below records the starting findings. Its proposed removals of the deliberate background/glass treatment and its neutral primary-action palette are superseded by the current direction above.

## Original evidence and recommendation

Reviewed the checked-in Home, active workout and Analytics screenshots in `fastlane/metadata/android/en-US/images/phoneScreenshots/`, and the current Flutter theme, Home, Analytics, exercise input and shared components. The screenshots are reference captures, not fresh renders of this checkout; findings about current behavior below come from source inspection. Motion was inspected in code, not observed on a device.

The visual treatment warrants the full Unslop process: repeated signs occur across surfaces, color, typography, icons, hierarchy and motion. The app already has a spacing system, bundled Geist/Geist Mono, useful charts and a recognizable workout notation. Build around those assets.

Recommendation: make RepForge feel like a dependable training instrument. Quiet the surrounding controls so workout actions, weight/reps and training data lead. Start with shared components and Home, then apply the approved treatment to workout logging and Analytics. Keep the existing feature set and section order.

## Direction for review

- **Product:** RepForge helps lifters record sets, follow routines and understand their training progress.
- **Character:** Sturdy, exact, focused.
- **World:** A training log beside steel plates; near-neutral graphite surfaces, readable figures and restrained flat violet drawn from the existing identity.
- **Moments:** The weekly activity pattern on Home and the volume trend on Analytics carry the visual richness; the active workout gives its weight/reps inputs the strongest hierarchy.
- **Signature:** Consistent set notation, `60 kg × 11 reps`, with tabular figures and quieter units wherever the app already shows a set.

## Audit

| Sign found | Location | Proposed correction |
| --- | --- | --- |
| Violet background wash and radial pools | `app_theme.dart` wash tokens; `rf_widgets.dart` → `AmbientGlow` | Opaque graphite surfaces; remove decorative background pools |
| Continuous drift and scroll parallax unrelated to workout state | `rf_widgets.dart` → `_AmbientGlowState` | Static background; retain feedback for actual state changes |
| Glowing primary controls compete with data | `home_screen.dart` → `_buildHeader`, `_buildStreakHero`; `rf_widgets.dart` → `GlowButton` | Violet primary action with clear pressed, focused and disabled states |
| Violet-to-cyan recommendation surface | `exercise_input_section.dart` → recommendation container | Subdued violet panel; keep recommendation, confidence and Apply action |
| AI sparkle tile gets disproportionate emphasis | Home header and exercise recommendation | Quiet Material outline icon with accessible name; keep coach access |
| Highlighted glass edges and optional colored card shadows | `rf_widgets.dart` → `GlassCard` | Solid fill and 1px neutral hairline |
| Navigation glow, colored selected border and spring expansion | `home_screen.dart` navigation theme; `floating_nav_bar.dart` | Violet-tinted selected surface; restrained transition without overshoot |
| Greeting occupies the page headline | `home_screen.dart` → `_buildHeader` | `Training` headline with date beneath; keep personalization in Profile |
| Uppercase tracked labels | Home date and `STREAK`; Analytics `INSIGHTS`; timer label in `rf_widgets.dart` | Sentence case, normal tracking |
| Tiny supporting text and four text opacity tiers | `app_theme.dart` → 9–11px labels and text tokens; Home weekday labels | Three text roles; 12px readable supporting text, 14px body |
| Excessively heavy figures in shared stats | `rf_widgets.dart` → `RFStatBox` uses weight 800 | Weight 500 figures; reserve 600 for limited emphasis |
| One-off spacing breaks the existing scale | Home: 14px top inset, 18px hero gap, 10px grid gaps | 16px top inset, 20px hero gap, 12px grid gaps |
| Four equally sized stat cards and four competing chart colors | `home_screen.dart` → `_buildStatsGrid`, `_StatCard` | Compact label/value/unit hierarchy; neutral supporting trend strokes, accent only on the leading series |
| Stat trends lack visible period labels | Home calculates seven weekly points but captions do not state that range | Label retained sparklines `Last 7 weeks`; retain the underlying historical information |
| A fixed five-workout goal is presented as personal | `home_screen.dart` → `_buildStatsGrid`, literal `/ 5 goal` | Display the real saved goal if one exists; otherwise label the figure `Workouts this week` without an implied target |
| Average-time period is ambiguous | Home calculates average duration from up to seven sessions | Caption `Last 7 workouts`, or the actual smaller count when fewer exist |
| Accent text has insufficient contrast at small sizes | Current violet `#7C3AED` against proposed card `#19191B` measures 3.08:1 | Use neutral text; reserve deep violet for fills and chart marks, with white labels on filled controls |

The existing sparklines are calculated from history, not fabricated filler. Preserve their information while reducing their visual priority. Muscle colors identify categories and recovery colors communicate state; preserve those meanings and pair them with labels. No invented activity, comparisons or claims are needed.

## Original proposal values (superseded where noted above)

| Token | Value |
| --- | --- |
| Canvas / card / raised surface | `#141415` / `#19191B` / `#232325` |
| Primary / secondary / muted text | `#EDEDED` / `#A1A1A6` / `#909096` |
| Accent | Existing flat violet `#7C3AED`; no colored glow |
| Border | Primary text at 8%, 1 logical pixel |
| Primary action | `#EDEDED` fill, `#141415` text; semantic accent retained for relevant states |
| Typography | Existing Geist and Geist Mono; 12 / 14 / 16 / 20 / 28 / 32px, with 48px for the active weight/reps values |
| Weights | 400 body, 500 labels and figures, 600 occasional emphasis |
| Spacing | 20px mobile page inset, 20px card padding, 12px related gaps, 24px section gaps |
| Radius | 8px controls, 16px cards; inner radius derived from actual padding, minimum 4px |
| Touch targets | At least 48 × 48 logical pixels; icons remain visually smaller |
| Motion | 150ms feedback, 200ms selection, 300ms sheet entrance; one ease-out curve, reduced-motion support |

Calculated contrast: the proposed off-white primary action is 15.73:1; secondary text on card is 6.82:1; white on the existing solid violet is 5.70:1. The Unslop reference muted color `#85858B` only reaches 4.28:1 on the raised surface, so use the lighter proposed muted token and verify all actual composited states during implementation.

## Approved implementation passes

1. **Spacing:** Normalize shared padding, Home grid gaps and control alignment; retain responsive layouts and allow text to grow.
2. **Color:** Establish graphite tokens, remove background washes and colored shadows, flatten primary and selected states.
3. **Icons:** Keep the existing Material family; standardize utility icons to 20px and navigation icons to 24px, using outlined variants where available. Preserve 48px touch targets and tooltips/semantics.
4. **Copy:** Use `Training`, `Streak`, `Suggested set`, `Log set` and `Last session`. Name actual measurement periods and remove the unsupported fixed goal claim.
5. **Type:** Retain the bundled fonts, apply three text roles, tabular figures and consistent value/unit formatting. Keep values editable and respect the selected kg/lb unit.
6. **Layout:** Keep Home's current order: header, streak/start, readiness, sleep, heart rate, stats, activity, muscle volume, insights, recent workouts. Tighten stats and make Start/Resume clearly actionable. Preserve conditional sections.
7. **Details:** Flatten card edges and nav selection; add visible focus and pressed states. On active logging, prioritize Log set while preserving access to Next exercise, dropsets, recommendations and history.
8. **Visuals:** Let real activity, muscle data and volume charts carry color. Keep secondary charts quiet. No generated illustrations are needed for these app screens.
9. **Motion:** Remove the ambient drift/parallax and bouncy navigation selection. Keep meaningful rest countdown, loading feedback, haptics and progress changes.

## Validation when implemented

- Capture Home, active workout and Analytics from current Flutter code, including empty and populated states.
- Check 320px, 360px and typical phone widths plus large text; prevent fixed aspect ratios from clipping expanded labels.
- Verify screen-reader labels, keyboard focus, contrast, reduced motion, navigation clearance and safe areas.
- Run the existing shared-widget, Home, workout-flow and Analytics tests, then Flutter analysis for changed code. Add tests only where a behavior change needs coverage.
- Compare resulting screens against each audit row. Retain real chart data, health states, selected units and workout-resume behavior.

## Approval and attribution

The user approved the initial direction before application code was edited and then refined it to preserve the brand’s character, as required by Unslop step 4. This review and its workflow adapt [Unslop by Damir Sokolovsky (@heydamir)](https://github.com/heydamir/unslop/blob/main/skills/unslop/SKILL.md), licensed CC BY 4.0. Implementation remains in the existing Flutter stack.
