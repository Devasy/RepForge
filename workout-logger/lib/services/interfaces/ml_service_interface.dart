// Abstract ML Service Interface (Dependency Inversion Principle)
//
// This interface defines the contract for machine learning operations.
// By depending on this abstraction, we can:
// - Swap ML algorithms without modifying consumers
// - Easily mock the ML service in tests
// - Follow the Open/Closed principle for new ML strategies

import '../../models/models.dart';

/// Data point for ML training
class DataPoint {
  final double x; // Session number or time
  final double y; // Volume or performance metric

  DataPoint({required this.x, required this.y});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataPoint &&
        other.runtimeType == runtimeType &&
        other.x == x &&
        other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

/// Abstract interface for ML operations
///
/// Implements Dependency Inversion Principle by allowing high-level modules
/// to depend on this abstraction rather than concrete ML implementations.
abstract class IMLService {
  /// Train a growth model using data points
  GrowthModel trainGrowthModel(List<DataPoint> dataPoints);

  /// Extract data points from workout history for a specific exercise
  List<DataPoint> extractExerciseDataPoints(
    String exerciseId,
    List<WorkoutSession> sessions,
  );

  /// Get recommended sets based on last session and growth model
  List<SetRecommendation> recommendSets({
    required List<WorkoutSet> lastSession,
    GrowthModel? growthModel,
  });

  /// Get default recommendations when no history exists
  List<SetRecommendation> getDefaultRecommendations(int setCount);

  /// Predict when a target will be completed based on growth model
  DateTime? predictTargetCompletion({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
  });
}
