// Mock ML Service for testing
//
// This mock implements the IMLService interface for testing.
// Following Dependency Inversion Principle: tests can inject this mock
// instead of the real MLService.

import 'package:repforge/models/models.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';

/// Mock implementation of IMLService for testing.
///
/// Following Liskov Substitution Principle: this mock can be used
/// wherever IMLService is expected without breaking the tests.
class MockMLService implements IMLService {
  // Configurable return values for testing
  GrowthModel? mockGrowthModel;
  List<SetRecommendation>? mockRecommendations;
  DateTime? mockPrediction;

  // Track method calls for verification
  int trainGrowthModelCallCount = 0;
  int extractDataPointsCallCount = 0;
  int recommendSetsCallCount = 0;
  int predictTargetCompletionCallCount = 0;

  // Last parameters received
  String? lastExtractedExerciseId;
  List<WorkoutSet>? lastRecommendedLastSession;
  List<List<WorkoutSet>>? lastPastSessions;
  Map<String, MuscleRecoveryStatus>? lastRecoveryScores;
  List<String>? lastPrimaryMuscleIds;
  ReadinessBand? lastReadinessBand;
  double? lastSessionFatigueFactor;

  @override
  GrowthModel trainGrowthModel(List<DataPoint> dataPoints) {
    trainGrowthModelCallCount++;
    return mockGrowthModel ??
        GrowthModel(
          slope: 0.1,
          intercept: 100,
          r2: 0.8,
          lastTrained: DateTime.now(),
        );
  }

  @override
  List<DataPoint> extractExerciseDataPoints(
    String exerciseId,
    List<WorkoutSession> sessions,
  ) {
    extractDataPointsCallCount++;
    lastExtractedExerciseId = exerciseId;

    // Return realistic data points based on sessions
    final dataPoints = <DataPoint>[];
    int sessionIndex = 0;

    for (var session in sessions) {
      for (var log in session.exercises) {
        if (log.exerciseId == exerciseId) {
          dataPoints.add(
            DataPoint(x: sessionIndex.toDouble(), y: log.totalVolume),
          );
          sessionIndex++;
          break;
        }
      }
    }

    return dataPoints;
  }

  @override
  List<DataPoint> extractMuscleDataPoints(
    String muscleGroupId,
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap,
  ) {
    return [];
  }

  @override
  Map<String, MuscleRecoveryStatus> computeMuscleRecoveryScores(
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap, {
    DateTime? asOf,
  }) {
    return {};
  }

  @override
  Map<String, DateTime> lastTrainedPerMuscle(
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap,
  ) {
    return {};
  }

  @override
  Map<String, MuscleRecoveryStatus> recoveryScoresFrom(
    Map<String, DateTime> lastTrained, {
    DateTime? asOf,
  }) {
    return {};
  }

  @override
  List<SetRecommendation> recommendSets({
    required List<WorkoutSet> lastSession,
    List<List<WorkoutSet>>? pastSessions,
    GrowthModel? growthModel,
    int minReps = 6,
    int maxReps = 12,
    Map<String, MuscleRecoveryStatus>? recoveryScores,
    List<String>? primaryMuscleIds,
    ReadinessBand? readinessBand,
    double sessionFatigueFactor = 0.0,
    DateTime? asOf,
  }) {
    recommendSetsCallCount++;
    lastRecommendedLastSession = lastSession;
    lastPastSessions = pastSessions;
    lastRecoveryScores = recoveryScores;
    lastPrimaryMuscleIds = primaryMuscleIds;
    lastReadinessBand = readinessBand;
    lastSessionFatigueFactor = sessionFatigueFactor;

    return mockRecommendations ??
        [
          SetRecommendation(
            weight: 50,
            reps: 10,
            confidence: 'high',
            reasoning: 'Mock recommendation',
          ),
        ];
  }

  @override
  List<SetRecommendation> getDefaultRecommendations(int setCount) {
    return mockRecommendations ??
        List.generate(
          setCount,
          (index) => SetRecommendation(
            weight: 0,
            reps: 10,
            confidence: 'low',
            reasoning: 'Default mock recommendation',
          ),
        );
  }

  @override
  DateTime? predictTargetCompletion({
    required double currentValue,
    required double targetValue,
    required GrowthModel growthModel,
  }) {
    predictTargetCompletionCallCount++;

    if (mockPrediction != null) {
      return mockPrediction;
    }

    // Default: predict 30 days from now if not completed
    if (currentValue >= targetValue) {
      return DateTime.now();
    }
    return DateTime.now().add(const Duration(days: 30));
  }

  /// Reset all tracking state for fresh test runs
  void reset() {
    trainGrowthModelCallCount = 0;
    extractDataPointsCallCount = 0;
    recommendSetsCallCount = 0;
    predictTargetCompletionCallCount = 0;
    lastExtractedExerciseId = null;
    lastRecommendedLastSession = null;
    lastPastSessions = null;
    lastRecoveryScores = null;
    lastPrimaryMuscleIds = null;
    lastReadinessBand = null;
    lastSessionFatigueFactor = null;
    mockGrowthModel = null;
    mockRecommendations = null;
    mockPrediction = null;
  }
}
