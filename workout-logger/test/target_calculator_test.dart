import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/strategies/target_calculator.dart';

WorkoutSession _session(
  String id,
  String exerciseId, {
  required List<WorkoutSet> sets,
  DateTime? date,
}) {
  return WorkoutSession(
    id: id,
    date: date ?? DateTime(2024, 1, 1),
    duration: 30,
    exercises: [ExerciseLog(exerciseId: exerciseId, sets: sets)],
  );
}

void main() {
  tearDown(() => TargetCalculatorFactory.reset());

  group('RepsTargetCalculator', () {
    final calculator = RepsTargetCalculator();

    test('returns 0 when no sessions', () {
      expect(calculator.calculate('ex1', []), 0);
    });

    test('returns maximum reps across all sets and sessions', () {
      final sessions = [
        _session('s1', 'ex1', sets: [
          WorkoutSet(weight: 80, reps: 8),
          WorkoutSet(weight: 80, reps: 10),
        ]),
        _session('s2', 'ex1', sets: [
          WorkoutSet(weight: 80, reps: 12),
          WorkoutSet(weight: 80, reps: 6),
        ]),
      ];

      expect(calculator.calculate('ex1', sessions), 12);
    });

    test('ignores sessions for other exercises', () {
      final sessions = [
        _session('s1', 'ex1', sets: [WorkoutSet(weight: 80, reps: 10)]),
        _session('s2', 'ex2', sets: [WorkoutSet(weight: 80, reps: 20)]),
      ];

      expect(calculator.calculate('ex1', sessions), 10);
    });
  });

  group('WeightTargetCalculator', () {
    final calculator = WeightTargetCalculator();

    test('returns 0 when no sessions', () {
      expect(calculator.calculate('ex1', []), 0);
    });

    test('returns maximum weight across all sets and sessions', () {
      final sessions = [
        _session('s1', 'ex1', sets: [
          WorkoutSet(weight: 80, reps: 5),
          WorkoutSet(weight: 90, reps: 3),
        ]),
        _session('s2', 'ex1', sets: [
          WorkoutSet(weight: 100, reps: 1),
        ]),
      ];

      expect(calculator.calculate('ex1', sessions), 100);
    });

    test('ignores sessions for other exercises', () {
      final sessions = [
        _session('s1', 'ex1', sets: [WorkoutSet(weight: 80, reps: 5)]),
        _session('s2', 'ex2', sets: [WorkoutSet(weight: 200, reps: 1)]),
      ];

      expect(calculator.calculate('ex1', sessions), 80);
    });
  });

  group('VolumeTargetCalculator', () {
    final calculator = VolumeTargetCalculator();

    test('returns 0 when no sessions', () {
      expect(calculator.calculate('ex1', []), 0);
    });

    test('returns maximum session volume across sessions', () {
      final sessions = [
        _session('s1', 'ex1', sets: [
          WorkoutSet(weight: 100, reps: 10), // 1000
          WorkoutSet(weight: 100, reps: 10), // 1000 → total 2000
        ]),
        _session('s2', 'ex1', sets: [
          WorkoutSet(weight: 80, reps: 12), // 960
          WorkoutSet(weight: 80, reps: 12), // 960
          WorkoutSet(weight: 80, reps: 12), // 960 → total 2880
        ]),
      ];

      expect(calculator.calculate('ex1', sessions), 2880);
    });
  });

  group('TargetCalculatorFactory', () {
    test('supportedTypes includes reps, weight, volume', () {
      expect(
        TargetCalculatorFactory.supportedTypes,
        containsAll(['reps', 'weight', 'volume']),
      );
    });

    test('getCalculator returns correct strategy for each type', () {
      expect(TargetCalculatorFactory.getCalculator('reps'),
          isA<RepsTargetCalculator>());
      expect(TargetCalculatorFactory.getCalculator('weight'),
          isA<WeightTargetCalculator>());
      expect(TargetCalculatorFactory.getCalculator('volume'),
          isA<VolumeTargetCalculator>());
    });

    test('getCalculator is case-insensitive', () {
      expect(TargetCalculatorFactory.getCalculator('REPS'), isNotNull);
      expect(TargetCalculatorFactory.getCalculator('Weight'), isNotNull);
    });

    test('getCalculator returns null for unknown type', () {
      expect(TargetCalculatorFactory.getCalculator('duration'), isNull);
    });

    test('calculateCurrentValue delegates to the right calculator', () {
      final sessions = [
        _session('s1', 'ex1', sets: [WorkoutSet(weight: 100, reps: 8)]),
      ];

      expect(
        TargetCalculatorFactory.calculateCurrentValue('ex1', 'weight', sessions),
        100,
      );
      expect(
        TargetCalculatorFactory.calculateCurrentValue('ex1', 'reps', sessions),
        8,
      );
      expect(
        TargetCalculatorFactory.calculateCurrentValue('ex1', 'volume', sessions),
        800, // 100 * 8
      );
    });

    test('calculateCurrentValue throws ArgumentError for unsupported type', () {
      expect(
        () => TargetCalculatorFactory.calculateCurrentValue('ex1', 'speed', []),
        throwsArgumentError,
      );
    });

    test('registerCalculator adds a new strategy', () {
      final custom = _AlwaysReturns42();
      TargetCalculatorFactory.registerCalculator('custom', custom);

      final result = TargetCalculatorFactory.calculateCurrentValue(
        'ex1',
        'custom',
        [],
      );

      expect(result, 42);
      expect(TargetCalculatorFactory.supportedTypes, contains('custom'));
    });

    test('reset restores default strategies only', () {
      TargetCalculatorFactory.registerCalculator('extra', _AlwaysReturns42());
      TargetCalculatorFactory.reset();

      expect(TargetCalculatorFactory.getCalculator('extra'), isNull);
      expect(TargetCalculatorFactory.supportedTypes.length, 3);
    });
  });
}

class _AlwaysReturns42 implements TargetCalculatorStrategy {
  @override
  double calculate(String exerciseId, List<WorkoutSession> sessions) => 42;
}
