// Progression Rule Chain (Open/Closed Principle)
//
// Each tier of MLService's double-progression heuristic (recovery gate,
// deload protocol, decline/plateau detection, weight/rep progression) is its
// own [ProgressionRule]. Rules are tried in order; the first to return a
// non-null [SetRecommendation] wins. New signals (readiness, same-session
// fatigue — see the recommendation-engine-upgrade plan) become new rules
// inserted at the appropriate point in the chain instead of edits to a
// growing if/else. Mirrors the registry shape of
// `strategies/target_calculator.dart`'s TargetCalculatorFactory, adapted
// from a type→strategy map to an ordered chain.

import 'dart:math';

import '../../models/models.dart';

/// Everything a [ProgressionRule] needs to decide (or defer) a
/// recommendation for one set.
class ProgressionContext {
  final WorkoutSet set;
  final int minReps;
  final int maxReps;
  final bool isPlateau;
  final bool isDeclining;
  final bool isUnderRecovered;
  final int? recoveryPercent;
  final bool isPostDeloadRecovery;

  /// True when today's readiness (sleep/RHR/HRV) is in the low band.
  /// Defaulted so existing call sites that don't pass it are unaffected.
  final bool isLowReadiness;

  /// 0.0 (untouched) to 1.0+ (fully fatigued) — how much of today's
  /// earlier training already loaded this set's primary muscle. 0.0 is the
  /// default so existing call sites are unaffected. [SessionFatigueRule]
  /// hard-holds at ≥1.0; values in between scale [DoubleProgressionRule]'s
  /// weight increment instead of blocking it outright.
  final double sessionFatigueFactor;

  const ProgressionContext({
    required this.set,
    required this.minReps,
    required this.maxReps,
    required this.isPlateau,
    required this.isDeclining,
    required this.isUnderRecovered,
    this.recoveryPercent,
    required this.isPostDeloadRecovery,
    this.isLowReadiness = false,
    this.sessionFatigueFactor = 0.0,
  });
}

/// One tier in the progression priority chain.
///
/// Return `null` to defer to the next rule ("this signal doesn't apply —
/// try the next one"); return a [SetRecommendation] to win and stop the
/// chain.
abstract class ProgressionRule {
  SetRecommendation? apply(ProgressionContext context);
}

/// Priority 1: a still-fatigued primary muscle holds instead of progressing.
class UnderRecoveredRule implements ProgressionRule {
  const UnderRecoveredRule();

  @override
  SetRecommendation? apply(ProgressionContext c) {
    if (!c.isUnderRecovered) return null;
    return SetRecommendation(
      weight: c.set.weight,
      reps: c.set.reps,
      confidence: 'low',
      reasoning: 'Muscle only ${c.recoveryPercent}% recovered — maintain '
          'load, skip progression',
    );
  }
}

/// Priority 2: the session right after a detected deload re-anchors on the
/// pre-deload baseline rather than progressing off the deload itself.
class PostDeloadRecoveryRule implements ProgressionRule {
  const PostDeloadRecoveryRule();

  @override
  SetRecommendation? apply(ProgressionContext c) {
    if (!c.isPostDeloadRecovery) return null;
    return SetRecommendation(
      weight: c.set.weight,
      reps: c.set.reps,
      confidence: 'high',
      // No raw weight value embedded here — the recommended weight/unit
      // is already surfaced via SetRecommendation.weight and formatted by
      // the presentation layer according to the user's unit preference.
      reasoning: 'Resuming training after deload — anchored on pre-deload '
          'baseline (${c.set.reps} reps)',
    );
  }
}

/// Priority 3: low whole-day readiness (sleep/RHR/HRV) holds instead of
/// progressing — a day-level physiological signal, so it outranks the
/// session-local fatigue check below.
class ReadinessRule implements ProgressionRule {
  const ReadinessRule();

  @override
  SetRecommendation? apply(ProgressionContext c) {
    if (!c.isLowReadiness) return null;
    return SetRecommendation(
      weight: c.set.weight,
      reps: c.set.reps,
      confidence: 'low',
      reasoning: 'Low readiness today (sleep/recovery signals) — hold load '
          'and reassess next session',
    );
  }
}

/// Priority 4: heavy same-session fatigue for this muscle hard-holds once
/// [ProgressionContext.sessionFatigueFactor] reaches 1.0. Values between 0
/// and 1 don't stop here — they defer to [DoubleProgressionRule], which
/// scales its weight increment down instead of blocking it outright.
class SessionFatigueRule implements ProgressionRule {
  const SessionFatigueRule();

  @override
  SetRecommendation? apply(ProgressionContext c) {
    if (c.sessionFatigueFactor < 1.0) return null;
    return SetRecommendation(
      weight: c.set.weight,
      reps: c.set.reps,
      confidence: 'medium',
      reasoning: "Already trained hard for this muscle earlier in today's "
          'session — hold and finish strong',
    );
  }
}

/// Priority 5: a trustworthy declining trend triggers a ~10% deload.
class DeclineDeloadRule implements ProgressionRule {
  const DeclineDeloadRule();

  @override
  SetRecommendation? apply(ProgressionContext c) {
    if (!c.isDeclining) return null;
    // Round the deload to the plate increment users can actually load.
    final deloaded = max(0.0, ((c.set.weight * 0.9) / 2.5).round() * 2.5);
    return SetRecommendation(
      weight: deloaded,
      reps: c.set.reps,
      confidence: 'medium',
      reasoning: 'Volume trending down — deload ~10% for a session or two, '
          'then rebuild',
    );
  }
}

/// Priority 6: a trustworthy flat trend holds load and reps.
class PlateauRule implements ProgressionRule {
  const PlateauRule();

  @override
  SetRecommendation? apply(ProgressionContext c) {
    if (!c.isPlateau) return null;
    return SetRecommendation(
      weight: c.set.weight,
      reps: c.set.reps,
      confidence: 'medium',
      reasoning: 'Plateau detected — maintain load and focus on form quality',
    );
  }
}

/// Priority 7 (terminal): plain double progression — add a rep, or bump
/// weight and reset reps once the rep ceiling is hit. Always produces a
/// recommendation, so this must stay last in the chain.
///
/// When [ProgressionContext.sessionFatigueFactor] is partial (0 < f < 1,
/// not enough to trigger [SessionFatigueRule]'s hard hold), the weight
/// increment scales down by (1 − f) instead of blocking progression
/// outright, snapped to the nearest 2.5kg plate. At f = 0 (the default) this
/// reduces to exactly the original unscaled behavior.
class DoubleProgressionRule implements ProgressionRule {
  const DoubleProgressionRule();

  @override
  SetRecommendation apply(ProgressionContext c) {
    if (c.set.reps >= c.maxReps) {
      final baseIncrement = c.set.weight < 40 ? 2.5 : 5.0;
      final increment = c.sessionFatigueFactor > 0
          ? max(
              0.0,
              ((baseIncrement * (1 - c.sessionFatigueFactor)) / 2.5).round() *
                  2.5,
            )
          : baseIncrement;

      if (increment <= 0) {
        return SetRecommendation(
          weight: c.set.weight,
          reps: c.set.reps,
          confidence: 'medium',
          reasoning: 'Rep target hit, but earlier sets today already '
              'fatigued this muscle — hold weight for now',
        );
      }

      return SetRecommendation(
        weight: c.set.weight + increment,
        reps: c.minReps,
        confidence: increment < baseIncrement ? 'medium' : 'high',
        // No raw weight or unit embedded, for the same reason as
        // PostDeloadRecoveryRule above: the recommended load rides on
        // SetRecommendation.weight and the presentation layer formats it in
        // the user's chosen unit. Hardcoding "kg" here read as "add 5.0kg"
        // to someone with pounds selected.
        reasoning: increment < baseIncrement
            ? 'Rep target hit — step the weight up a little (reduced — '
                'already fatigued this muscle today) and reset to '
                '${c.minReps} reps'
            : 'Rep target hit — step the weight up and reset to '
                '${c.minReps} reps',
      );
    }

    return SetRecommendation(
      weight: c.set.weight,
      reps: c.set.reps + 1,
      confidence: 'high',
      reasoning: 'Add 1 rep (${c.set.reps + 1}/${c.maxReps}) — progressive overload',
    );
  }
}

/// Ordered registry of [ProgressionRule]s, mirroring
/// [TargetCalculatorFactory]'s registration/reset pattern.
class ProgressionRuleFactory {
  static List<ProgressionRule> _rules = _defaults();

  static List<ProgressionRule> _defaults() => const [
        UnderRecoveredRule(),
        PostDeloadRecoveryRule(),
        ReadinessRule(),
        SessionFatigueRule(),
        DeclineDeloadRule(),
        PlateauRule(),
        DoubleProgressionRule(),
      ];

  /// Reset the chain to defaults.
  ///
  /// This is primarily used in tests to restore isolation after
  /// registering a custom rule.
  static void reset() {
    _rules = _defaults();
  }

  /// The current chain, in priority order (highest priority first).
  static List<ProgressionRule> get rules => List.unmodifiable(_rules);

  /// Registers [rule] at the head of the chain, so it is tried before every
  /// existing rule (highest priority).
  static void registerRuleAtHead(ProgressionRule rule) {
    _rules = [rule, ..._rules];
  }

  /// Runs [context] through the chain and returns the first rule's
  /// non-null result. [DoubleProgressionRule] is the terminal rule and
  /// always matches, so a well-formed chain never falls through.
  static SetRecommendation apply(ProgressionContext context) {
    for (final rule in _rules) {
      final result = rule.apply(context);
      if (result != null) return result;
    }
    throw StateError(
      'No progression rule produced a recommendation — the chain is '
      'missing a terminal rule.',
    );
  }
}
