// Session Fatigue Accumulator (intra-session, cross-exercise awareness)
//
// The recommendation engine previously had zero awareness of what the user
// already did earlier in TODAY's session — deload/plateau detection only
// looks at day-to-day history of the SAME exercise.
//
// An earlier version of this accumulator attributed fatigue per muscle group
// using each exercise's hand-authored `Exercise.muscleActivations` table.
// That table proved untrustworthy: Seated Cable Row's own top-activation
// muscle is "back" while Lat Pulldown's and Pull-ups' is "lats" — separate
// ids in this app's taxonomy, not aliased — so a real user's actual
// back/bicep routine (rows, pulldowns, pull-ups back to back — genuinely the
// same movement pattern) could silently miss its own overlap depending on
// which exercise happened to be authored with which label as "primary".
//
// A backtest against 74 real logged sessions (see the recommendation-engine
// plan doc's Phase 6+ notes) then tested whether a same-session order effect
// is statistically detectable AT ALL, independent of the muscle-activation
// table — pooled regression of same-session exercise performance against
// prior same-session hard-set count, session-demeaned: r = 0.005, t = 0.09,
// n = 309. No effect survived a split-half check for any individual
// exercise either. With this user's routine order essentially fixed
// session-to-session (73 of 85 logged exercise pairs never appear in both
// possible orders), there isn't yet enough contrastive data for ANY model —
// simple or complex — to learn a reliable relationship.
//
// So this accumulator now tracks a single, exercise-agnostic scalar — total
// RPE-weighted hard-set-equivalents already logged elsewhere in today's
// session — with NO muscle attribution at all, and the cap that converts it
// to a dampening factor is calibrated to stay at 0.0 for every one of 254
// real historical set-recommendation contexts (max observed: 11.87; caps set
// well above that). This is an intentionally inert, honest placeholder: the
// mechanism is real and ready, but the current calibration should not change
// any recommendation until genuine order-variation data exists to fit it
// against (see the plan doc's suggested "occasionally swap exercise order"
// data-collection nudge).

import '../../models/models.dart';
import 'effort_estimator.dart';

class SessionFatigueAccumulator {
  const SessionFatigueAccumulator({
    EffortEstimator effortEstimator = const EffortEstimator(),
  }) : _effortEstimator = effortEstimator;

  final EffortEstimator _effortEstimator;

  // A set's contribution ramps from 0 at RPE 6 (light/warm-up) to 1.0 at
  // RPE 9+ (near failure) — not every logged set counts equally.
  static const double _rpeFloor = 6.0;
  static const double _rpeSpan = 3.0;

  // Calibrated (2026-08) against 254 real historical set-recommendation
  // contexts from a 74-session export: max observed total was 11.87. Both
  // caps sit comfortably above that, so this factor evaluates to 0.0 on
  // every real case seen so far — see the file-level comment for why.
  static const double _softCap = 16.0;
  static const double _hardCap = 24.0;

  /// A 0.0–1.0 same-session fatigue dampening factor from [exerciseLogs]
  /// (the in-progress session's logs so far, across all exercises),
  /// summing each set's estimated-RPE-derived hardness with no per-muscle
  /// weighting.
  ///
  /// [excludeExerciseId], when given, skips that exercise's own sets — the
  /// fatigue an exercise contributes to itself is already covered by the
  /// deload/decline rules; this accumulator is specifically for carryover
  /// from *other* exercises trained earlier today.
  double factorFor({
    required List<ExerciseLog> exerciseLogs,
    String? excludeExerciseId,
  }) {
    var total = 0.0;
    for (final log in exerciseLogs) {
      if (log.exerciseId == excludeExerciseId) continue;

      for (var i = 0; i < log.sets.length; i++) {
        final set = log.sets[i];
        final estimate = _effortEstimator.estimate(
          set: set,
          priorSetsThisExerciseToday: log.sets.sublist(0, i),
        );
        total += ((estimate.rpe - _rpeFloor) / _rpeSpan).clamp(0.0, 1.0);
      }
    }
    return ((total - _softCap) / (_hardCap - _softCap)).clamp(0.0, 1.0);
  }
}
