// ML Service - Linear Regression for Growth Rate Prediction
// and Progressive Overload Recommendations
//
// This is a concrete implementation of IMLService.
// Following Dependency Inversion Principle: high-level modules depend on
// the IMLService abstraction, not this concrete class.
// Following Open/Closed Principle: new ML algorithms can be added by
// creating new implementations of IMLService.

import 'dart:math';
import '../models/models.dart';
import 'interfaces/ml_service_interface.dart';

// Re-export DataPoint from interface for backward compatibility
export 'interfaces/ml_service_interface.dart' show DataPoint;

/// Linear regression based implementation of the ML service.
///
/// This class implements IMLService, allowing it to be swapped
/// for other ML algorithms without modifying the consuming code.
class MLService implements IMLService {
  // ==================== LINEAR REGRESSION ====================

  /// Train a growth model using simple linear regression
  /// x = session number (0, 1, 2, ...)
  /// y = volume or performance metric
  @override
  GrowthModel trainGrowthModel(List<DataPoint> dataPoints) {
    return MLService.trainGrowthModelStatic(dataPoints);
  }

  /// Static version for backward compatibility
  static GrowthModel trainGrowthModelStatic(List<DataPoint> dataPoints) {
    if (dataPoints.isEmpty) {
      return GrowthModel(
        slope: 0,
        intercept: 0,
        r2: 0,
        lastTrained: DateTime.now(),
      );
    }

    if (dataPoints.length == 1) {
      return GrowthModel(
        slope: 0,
        intercept: dataPoints.first.y,
        r2: 1,
        lastTrained: DateTime.now(),
      );
    }

    final n = dataPoints.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (var point in dataPoints) {
      sumX += point.x;
      sumY += point.y;
      sumXY += point.x * point.y;
      sumX2 += point.x * point.x;
    }

    // Calculate slope and intercept using least squares
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) {
      return GrowthModel(
        slope: 0,
        intercept: sumY / n,
        r2: 0,
        lastTrained: DateTime.now(),
      );
    }

    final slope = (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;

    // Calculate R² (coefficient of determination)
    final yMean = sumY / n;
    double ssTotal = 0, ssResidual = 0;

    for (var point in dataPoints) {
      final predicted = slope * point.x + intercept;
      ssTotal += pow(point.y - yMean, 2);
      ssResidual += pow(point.y - predicted, 2);
    }

    final double r2Value = ssTotal > 0
        ? (1 - (ssResidual / ssTotal)).toDouble()
        : 0.0;

    return GrowthModel(
      slope: slope,
      intercept: intercept,
      r2: r2Value.clamp(0.0, 1.0),
      lastTrained: DateTime.now(),
    );
  }

  /// Extract data points from workout history for a specific exercise
  @override
  List<DataPoint> extractExerciseDataPoints(
    String exerciseId,
    List<WorkoutSession> sessions,
  ) {
    final dataPoints = <DataPoint>[];
    int sessionIndex = 0;

    // Sort sessions by date
    final sorted = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (var session in sorted) {
      for (var exerciseLog in session.exercises) {
        if (exerciseLog.exerciseId == exerciseId) {
          dataPoints.add(
            DataPoint(x: sessionIndex.toDouble(), y: exerciseLog.totalVolume),
          );
          sessionIndex++;
          break;
        }
      }
    }

    return dataPoints;
  }

  // ==================== RECOMMENDATIONS ====================

  /// Generate set recommendations based on previous performance
  @override
  List<SetRecommendation> recommendSets({
    required List<WorkoutSet> lastSession,
    GrowthModel? growthModel,
    double targetProgressPercent = 5.0, // Default 5% increase
  }) {
    if (lastSession.isEmpty) {
      return [];
    }

    // Calculate target volume increase
    final lastVolume = lastSession.fold<double>(
      0,
      (sum, set) => sum + set.volume,
    );

    // Use growth model slope if available, otherwise use default percentage
    double targetVolumeIncrease;
    if (growthModel != null && growthModel.r2 > 0.3) {
      // Use learned growth rate
      targetVolumeIncrease = growthModel.slope;
    } else {
      // Default: aim for 5% increase
      targetVolumeIncrease = lastVolume * (targetProgressPercent / 100);
    }

    final recommendations = <SetRecommendation>[];
    final volumeIncreasePerSet = targetVolumeIncrease / lastSession.length;

    for (var set in lastSession) {
      final targetVolume = set.volume + volumeIncreasePerSet;
      final recommendation = _calculateOptimalSet(
        currentWeight: set.weight,
        currentReps: set.reps,
        targetVolume: targetVolume,
      );
      recommendations.add(recommendation);
    }

    return recommendations;
  }

  /// Calculate optimal weight/reps to achieve target volume
  static SetRecommendation _calculateOptimalSet({
    required double currentWeight,
    required int currentReps,
    required double targetVolume,
  }) {
    // Strategy 1: Try adding reps first (safer progression)
    if (currentReps < 12) {
      final newReps = currentReps + 1;
      final newVolume = currentWeight * newReps;

      if (newVolume >= targetVolume * 0.95) {
        return SetRecommendation(
          weight: currentWeight,
          reps: newReps,
          confidence: 'high',
          reasoning: 'Add 1 rep for progressive overload',
        );
      }

      // Try adding 2 reps
      if (currentReps < 11) {
        final twoMoreReps = currentReps + 2;
        final volumeWith2Reps = currentWeight * twoMoreReps;

        if (volumeWith2Reps >= targetVolume * 0.95) {
          return SetRecommendation(
            weight: currentWeight,
            reps: twoMoreReps,
            confidence: 'high',
            reasoning: 'Add 2 reps to match target volume',
          );
        }
      }
    }

    // Strategy 2: Increase weight
    final weightIncrement = currentWeight < 40 ? 2.5 : 5.0;
    final newWeight = currentWeight + weightIncrement;

    // When increasing weight, maintain or slightly reduce reps
    int newReps = currentReps;
    if (currentReps >= 10) {
      newReps = currentReps - 2; // Reset rep range when weight goes up
    }
    newReps = newReps.clamp(6, 15);

    final newVolume = newWeight * newReps;

    String confidence;
    if (newVolume >= targetVolume * 0.9 && newVolume <= targetVolume * 1.1) {
      confidence = 'high';
    } else if (newVolume >= targetVolume * 0.8) {
      confidence = 'medium';
    } else {
      confidence = 'low';
    }

    return SetRecommendation(
      weight: newWeight,
      reps: newReps,
      confidence: confidence,
      reasoning: 'Increase weight by ${weightIncrement}kg, adjust reps',
    );
  }

  /// Fill in default recommendations for a new exercise
  @override
  List<SetRecommendation> getDefaultRecommendations(int setCount) {
    return List.generate(
      setCount,
      (index) => SetRecommendation(
        weight: 0,
        reps: 10,
        confidence: 'low',
        reasoning: 'No previous data - adjust based on feel',
      ),
    );
  }

  // ==================== TARGET PREDICTIONS ====================

  /// Predict when a target will be achieved
  @override
  DateTime? predictTargetCompletion({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
    double sessionsPerWeek = 3.0,
  }) {
    if (currentValue >= targetValue) {
      return DateTime.now(); // Already achieved
    }

    if (growthModel.slope <= 0) {
      return null; // No growth or declining - can't predict
    }

    final gapToTarget = targetValue - currentValue;
    final sessionsNeeded = gapToTarget / growthModel.slope;
    final weeksNeeded = sessionsNeeded / sessionsPerWeek;
    final daysNeeded = (weeksNeeded * 7).ceil();

    return DateTime.now().add(Duration(days: daysNeeded));
  }

  /// Calculate confidence interval for prediction
  static ({DateTime optimistic, DateTime expected, DateTime pessimistic})?
  predictTargetWithConfidence({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
    double sessionsPerWeek = 3.0,
  }) {
    // Create instance to call the non-static method
    final mlService = MLService();
    final expected = mlService.predictTargetCompletion(
      currentValue: currentValue,
      targetValue: targetValue,
      growthModel: growthModel,
      sessionsPerWeek: sessionsPerWeek,
    );

    if (expected == null) return null;

    // Adjust based on model quality (R²)
    final daysToTarget = expected.difference(DateTime.now()).inDays;
    final uncertainty = ((1 - growthModel.r2) * daysToTarget * 0.5).ceil();

    return (
      optimistic: expected.subtract(Duration(days: uncertainty)),
      expected: expected,
      pessimistic: expected.add(Duration(days: uncertainty)),
    );
  }
}
