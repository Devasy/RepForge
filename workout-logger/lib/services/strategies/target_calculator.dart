// Target Calculator Strategy Pattern (Open/Closed Principle)
//
// This module implements the Strategy Pattern for calculating target values.
// Following Open/Closed Principle: new target types can be added by creating
// new strategy implementations without modifying existing code.
// Following Single Responsibility Principle: each strategy handles one type of calculation.

import '../../models/models.dart';

/// Abstract strategy for calculating target values from workout history.
///
/// New target types (reps, weight, volume, duration, etc.) can be added
/// by implementing this interface without modifying existing calculators.
abstract class TargetCalculatorStrategy {
  /// Calculate the current best/max value for this target type
  double calculate(String exerciseId, List<WorkoutSession> sessions);
}

/// Helper function to get all exercise logs for a specific exercise across sessions.
///
/// Returns an iterable of ExerciseLog entries that have non-empty sets.
Iterable<ExerciseLog> _getExerciseLogsForExercise(
  String exerciseId,
  List<WorkoutSession> sessions,
) sync* {
  for (var session in sessions) {
    for (var log in session.exercises) {
      if (log.exerciseId == exerciseId && log.sets.isNotEmpty) {
        yield log;
      }
    }
  }
}

/// Calculator for maximum reps achieved
class RepsTargetCalculator implements TargetCalculatorStrategy {
  @override
  double calculate(String exerciseId, List<WorkoutSession> sessions) {
    double bestValue = 0;

    for (final log in _getExerciseLogsForExercise(exerciseId, sessions)) {
      // In-place max scan: no intermediate list allocation, no .toDouble() needed.
      for (final set in log.sets) {
        if (set.reps > bestValue) bestValue = set.reps.toDouble();
      }
    }

    return bestValue;
  }
}

/// Calculator for maximum weight lifted
class WeightTargetCalculator implements TargetCalculatorStrategy {
  @override
  double calculate(String exerciseId, List<WorkoutSession> sessions) {
    double bestValue = 0;

    for (var log in _getExerciseLogsForExercise(exerciseId, sessions)) {
      final maxWeight = log.sets
          .map((s) => s.weight)
          .reduce((a, b) => a > b ? a : b);
      if (maxWeight > bestValue) {
        bestValue = maxWeight;
      }
    }

    return bestValue;
  }
}

/// Calculator for total volume (weight × reps)
class VolumeTargetCalculator implements TargetCalculatorStrategy {
  @override
  double calculate(String exerciseId, List<WorkoutSession> sessions) {
    double bestValue = 0;

    for (var log in _getExerciseLogsForExercise(exerciseId, sessions)) {
      if (log.totalVolume > bestValue) {
        bestValue = log.totalVolume;
      }
    }

    return bestValue;
  }
}

/// Factory for creating target calculators based on target type.
///
/// This factory centralizes the creation logic and makes it easy to
/// add new target types without modifying the main business logic.
class TargetCalculatorFactory {
  static final Map<String, TargetCalculatorStrategy> _strategies = {
    'reps': RepsTargetCalculator(),
    'weight': WeightTargetCalculator(),
    'volume': VolumeTargetCalculator(),
  };

  /// Reset the strategies registry to defaults.
  ///
  /// This is primarily used in tests to restore isolation after
  /// registering custom calculators.
  static void reset() {
    _strategies.clear();
    _strategies['reps'] = RepsTargetCalculator();
    _strategies['weight'] = WeightTargetCalculator();
    _strategies['volume'] = VolumeTargetCalculator();
  }

  /// Get a calculator for the specified target type
  ///
  /// Returns null if the target type is not supported.
  static TargetCalculatorStrategy? getCalculator(String targetType) {
    return _strategies[targetType.toLowerCase()];
  }

  /// Register a new target calculator strategy
  ///
  /// This allows extending the system with new target types
  /// without modifying existing code (Open/Closed Principle).
  static void registerCalculator(
    String targetType,
    TargetCalculatorStrategy strategy,
  ) {
    _strategies[targetType.toLowerCase()] = strategy;
  }

  /// Get all supported target types
  static List<String> get supportedTypes => _strategies.keys.toList();

  /// Calculate current value for a target using the appropriate strategy
  static double calculateCurrentValue(
    String exerciseId,
    String targetType,
    List<WorkoutSession> sessions,
  ) {
    final calculator = getCalculator(targetType);
    if (calculator == null) {
      throw ArgumentError('Unsupported target type: $targetType');
    }
    return calculator.calculate(exerciseId, sessions);
  }
}
