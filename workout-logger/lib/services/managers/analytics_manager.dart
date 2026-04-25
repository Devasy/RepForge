// Analytics Manager (Single Responsibility Principle)
//
// This class is responsible ONLY for analytics and statistics.
// It handles:
// - Volume progression calculations
// - Weekly stats by muscle group
// - Growth model training
// - Set recommendations
//
// It does NOT handle data persistence or workout execution.

import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';
import '../interfaces/ml_service_interface.dart';
import '../utils/exercise_history.dart';

/// Manages analytics and statistics for workouts.
///
/// Following Single Responsibility Principle: this class only handles
/// analytics calculations, not data persistence or workout execution.
class AnalyticsManager extends ChangeNotifier {
  final IStorageService _storage;
  final IMLService _mlService;

  // Growth models for each exercise
  final Map<String, GrowthModel> _growthModels = {};

  // Callback to update targets with new growth models
  final void Function(String exerciseId, GrowthModel model)?
  onGrowthModelUpdated;

  AnalyticsManager(this._storage, this._mlService, {this.onGrowthModelUpdated});

  // Getters
  Map<String, GrowthModel> get growthModels => Map.unmodifiable(_growthModels);

  /// Get growth model for a specific exercise
  GrowthModel? getGrowthModel(String exerciseId) => _growthModels[exerciseId];

  /// Train all growth models from session history
  ///
  /// Runs all model updates concurrently for better performance.
  Future<void> trainAllGrowthModels(List<WorkoutSession> sessions) async {
    final exerciseIds = <String>{};

    // Get all unique exercise IDs from sessions
    for (var session in sessions) {
      for (var log in session.exercises) {
        exerciseIds.add(log.exerciseId);
      }
    }

    // Train models concurrently for better performance
    await Future.wait(
      exerciseIds.map((exerciseId) => updateGrowthModel(exerciseId, sessions)),
    );

    // Notify listeners after bulk update completes
    notifyListeners();
  }

  /// Update growth model for a specific exercise
  Future<void> updateGrowthModel(
    String exerciseId,
    List<WorkoutSession> sessions,
  ) async {
    final dataPoints = _mlService.extractExerciseDataPoints(
      exerciseId,
      sessions,
    );

    if (dataPoints.length >= 2) {
      final model = _mlService.trainGrowthModel(dataPoints);
      _growthModels[exerciseId] = model;
      onGrowthModelUpdated?.call(exerciseId, model);
    } else {
      // Remove stale model if not enough data
      _growthModels.remove(exerciseId);
    }
  }

  /// Update growth models for multiple exercises
  ///
  /// Runs all model updates concurrently for better performance.
  Future<void> updateGrowthModelsForExercises(
    Set<String> exerciseIds,
    List<WorkoutSession> sessions,
  ) async {
    // Run updates in parallel like trainAllGrowthModels
    await Future.wait(
      exerciseIds.map((exerciseId) => updateGrowthModel(exerciseId, sessions)),
    );
    notifyListeners();
  }

  /// Get set recommendations for an exercise.
  ///
  /// Uses the most-recently-dated session containing this exercise.
  List<SetRecommendation> getRecommendations(
    String exerciseId,
    List<WorkoutSession> sessions,
  ) {
    final lastLog = findMostRecentExerciseLog(exerciseId, sessions);

    if (lastLog == null || lastLog.sets.isEmpty) {
      return _mlService.getDefaultRecommendations(3);
    }

    return _mlService.recommendSets(
      lastSession: lastLog.sets,
      growthModel: _growthModels[exerciseId],
    );
  }

  /// Get volume progression for an exercise
  List<({DateTime date, double volume})> getVolumeProgression(
    String exerciseId,
    List<WorkoutSession> sessions,
  ) {
    final data = <({DateTime date, double volume})>[];

    // Process sessions in chronological order (oldest first)
    final sortedSessions = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (var session in sortedSessions) {
      for (var log in session.exercises) {
        if (log.exerciseId == exerciseId) {
          data.add((date: session.date, volume: log.totalVolume));
          break;
        }
      }
    }

    return data;
  }

  /// Get weekly volume by muscle group
  ///
  /// [now] parameter allows test injection of a fixed timestamp for deterministic testing.
  Map<String, double> getWeeklyVolumeByMuscle(
    List<WorkoutSession> sessions,
    List<Exercise> exercises, {
    DateTime? now,
  }) {
    final volumeByMuscle = <String, double>{};
    final currentTime = now ?? DateTime.now();
    final weekAgo = currentTime.subtract(const Duration(days: 7));

    for (var session in sessions) {
      if (session.date.isBefore(weekAgo)) continue;

      for (var log in session.exercises) {
        final exercise = _findExercise(log.exerciseId, exercises);
        if (exercise == null) continue;

        for (var activation in exercise.muscleActivations) {
          final muscleVolume =
              log.totalVolume * (activation.activationPercentage / 100);
          volumeByMuscle[activation.muscleGroupId] =
              (volumeByMuscle[activation.muscleGroupId] ?? 0) + muscleVolume;
        }
      }
    }

    return volumeByMuscle;
  }

  Exercise? _findExercise(String id, List<Exercise> exercises) {
    final index = exercises.indexWhere((e) => e.id == id);
    return index != -1 ? exercises[index] : null;
  }

  /// Get quick stats for dashboard
  Future<Map<String, dynamic>> getQuickStats() async {
    return await _storage.getQuickStats();
  }
}
