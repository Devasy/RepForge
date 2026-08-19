import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/strategies/progression_rules.dart';

WorkoutSet _set({double weight = 60.0, int reps = 10}) =>
    WorkoutSet(weight: weight, reps: reps);

ProgressionContext _context({
  WorkoutSet? set,
  int minReps = 6,
  int maxReps = 12,
  bool isPlateau = false,
  bool isDeclining = false,
  bool isUnderRecovered = false,
  int? recoveryPercent,
  bool isPostDeloadRecovery = false,
  bool isLowReadiness = false,
  double sessionFatigueFactor = 0.0,
}) {
  return ProgressionContext(
    set: set ?? _set(),
    minReps: minReps,
    maxReps: maxReps,
    isPlateau: isPlateau,
    isDeclining: isDeclining,
    isUnderRecovered: isUnderRecovered,
    recoveryPercent: recoveryPercent,
    isPostDeloadRecovery: isPostDeloadRecovery,
    isLowReadiness: isLowReadiness,
    sessionFatigueFactor: sessionFatigueFactor,
  );
}

void main() {
  tearDown(() => ProgressionRuleFactory.reset());

  group('UnderRecoveredRule', () {
    final rule = UnderRecoveredRule();

    test('defers when not under-recovered', () {
      expect(rule.apply(_context(isUnderRecovered: false)), isNull);
    });

    test('holds weight/reps with low confidence when under-recovered', () {
      final result = rule.apply(_context(
        set: _set(weight: 80, reps: 8),
        isUnderRecovered: true,
        recoveryPercent: 40,
      ));
      expect(result, isNotNull);
      expect(result!.weight, 80);
      expect(result.reps, 8);
      expect(result.confidence, 'low');
      expect(result.reasoning, contains('40%'));
    });
  });

  group('PostDeloadRecoveryRule', () {
    final rule = PostDeloadRecoveryRule();

    test('defers when not post-deload', () {
      expect(rule.apply(_context()), isNull);
    });

    test('holds weight/reps with high confidence when post-deload', () {
      final result = rule.apply(_context(
        set: _set(weight: 100, reps: 6),
        isPostDeloadRecovery: true,
      ));
      expect(result, isNotNull);
      expect(result!.weight, 100);
      expect(result.reps, 6);
      expect(result.confidence, 'high');
      expect(result.reasoning, contains('deload'));
    });
  });

  group('ReadinessRule', () {
    final rule = ReadinessRule();

    test('defers when readiness is not low', () {
      expect(rule.apply(_context(isLowReadiness: false)), isNull);
    });

    test('holds weight/reps with low confidence when readiness is low', () {
      final result = rule.apply(_context(
        set: _set(weight: 70, reps: 9),
        isLowReadiness: true,
      ));
      expect(result, isNotNull);
      expect(result!.weight, 70);
      expect(result.reps, 9);
      expect(result.confidence, 'low');
      expect(result.reasoning, contains('readiness'));
    });
  });

  group('SessionFatigueRule', () {
    final rule = SessionFatigueRule();

    test('defers when fatigue factor is below 1.0', () {
      expect(rule.apply(_context(sessionFatigueFactor: 0.6)), isNull);
    });

    test('hard-holds once fatigue factor reaches 1.0', () {
      final result = rule.apply(_context(
        set: _set(weight: 60, reps: 10),
        sessionFatigueFactor: 1.0,
      ));
      expect(result, isNotNull);
      expect(result!.weight, 60);
      expect(result.reps, 10);
      expect(result.confidence, 'medium');
    });
  });

  group('DeclineDeloadRule', () {
    final rule = DeclineDeloadRule();

    test('defers when not declining', () {
      expect(rule.apply(_context()), isNull);
    });

    test('deloads ~10% rounded to the nearest 2.5kg plate', () {
      final result = rule.apply(_context(
        set: _set(weight: 100, reps: 8),
        isDeclining: true,
      ));
      expect(result, isNotNull);
      expect(result!.weight, closeTo(90.0, 0.001));
      expect(result.reps, 8);
      expect(result.confidence, 'medium');
    });
  });

  group('PlateauRule', () {
    final rule = PlateauRule();

    test('defers when not plateaued', () {
      expect(rule.apply(_context()), isNull);
    });

    test('holds weight/reps with medium confidence on plateau', () {
      final result = rule.apply(_context(
        set: _set(weight: 60, reps: 10),
        isPlateau: true,
      ));
      expect(result, isNotNull);
      expect(result!.weight, 60);
      expect(result.reps, 10);
      expect(result.confidence, 'medium');
    });
  });

  group('DoubleProgressionRule', () {
    final rule = DoubleProgressionRule();

    test('never defers (terminal rule)', () {
      expect(rule.apply(_context()), isNotNull);
    });

    test('adds one rep below the rep ceiling', () {
      final result = rule.apply(_context(set: _set(weight: 60, reps: 10), maxReps: 12));
      expect(result.weight, closeTo(60.0, 0.001));
      expect(result.reps, 11);
      expect(result.confidence, 'high');
    });

    test('bumps weight and resets reps at the rep ceiling', () {
      final result = rule.apply(
        _context(set: _set(weight: 80, reps: 12), minReps: 6, maxReps: 12),
      );
      expect(result.weight, closeTo(85.0, 0.001));
      expect(result.reps, 6);
    });

    test('partial session fatigue scales down the weight increment', () {
      // weight >= 40 → base increment 5.0; factor 0.5 → scaled to 2.5.
      final result = rule.apply(_context(
        set: _set(weight: 80, reps: 12),
        minReps: 6,
        maxReps: 12,
        sessionFatigueFactor: 0.5,
      ));
      expect(result.weight, closeTo(82.5, 0.001));
      expect(result.reps, 6);
      expect(result.confidence, 'medium');
      expect(result.reasoning, contains('reduced'));
    });

    test('heavy partial fatigue that rounds the increment to zero holds weight',
        () {
      // scaled = 5.0*(1-0.9) = 0.5 → rounds to 0 at the 2.5kg plate.
      final result = rule.apply(_context(
        set: _set(weight: 80, reps: 12),
        minReps: 6,
        maxReps: 12,
        sessionFatigueFactor: 0.9,
      ));
      expect(result.weight, closeTo(80.0, 0.001));
      expect(result.reps, 12); // not reset — no progression happened
      expect(result.confidence, 'medium');
    });

    test('zero fatigue factor (the default) is byte-identical to unscaled behavior',
        () {
      final unscaled = rule.apply(
        _context(set: _set(weight: 80, reps: 12), minReps: 6, maxReps: 12),
      );
      final explicitZero = rule.apply(_context(
        set: _set(weight: 80, reps: 12),
        minReps: 6,
        maxReps: 12,
        sessionFatigueFactor: 0.0,
      ));
      expect(explicitZero.weight, unscaled.weight);
      expect(explicitZero.reps, unscaled.reps);
      expect(explicitZero.confidence, unscaled.confidence);
      expect(explicitZero.reasoning, unscaled.reasoning);
    });
  });

  group('ProgressionRuleFactory', () {
    test('default chain order matches the documented priority', () {
      final rules = ProgressionRuleFactory.rules;
      expect(rules[0], isA<UnderRecoveredRule>());
      expect(rules[1], isA<PostDeloadRecoveryRule>());
      expect(rules[2], isA<ReadinessRule>());
      expect(rules[3], isA<SessionFatigueRule>());
      expect(rules[4], isA<DeclineDeloadRule>());
      expect(rules[5], isA<PlateauRule>());
      expect(rules[6], isA<DoubleProgressionRule>());
      expect(rules.length, 7);
    });

    test('apply falls through to the first matching rule', () {
      final result = ProgressionRuleFactory.apply(_context(
        set: _set(weight: 80, reps: 8),
        isUnderRecovered: true,
        recoveryPercent: 50,
        // Even though decline is also true, under-recovered has priority.
        isDeclining: true,
      ));
      expect(result.reasoning, contains('recovered'));
    });

    test('registerRuleAtHead overrides the entire chain', () {
      ProgressionRuleFactory.registerRuleAtHead(_AlwaysHolds());

      final result = ProgressionRuleFactory.apply(_context(set: _set(weight: 60, reps: 10)));

      expect(result.reasoning, 'always holds');
      expect(result.weight, 60);
      expect(result.reps, 10);
    });

    test('reset restores the default chain', () {
      ProgressionRuleFactory.registerRuleAtHead(_AlwaysHolds());
      ProgressionRuleFactory.reset();

      expect(ProgressionRuleFactory.rules.length, 7);
      expect(ProgressionRuleFactory.rules.first, isA<UnderRecoveredRule>());
    });
  });
}

class _AlwaysHolds implements ProgressionRule {
  @override
  SetRecommendation apply(ProgressionContext c) => SetRecommendation(
        weight: c.set.weight,
        reps: c.set.reps,
        confidence: 'low',
        reasoning: 'always holds',
      );
}
