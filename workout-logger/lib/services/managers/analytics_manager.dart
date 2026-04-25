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

  // Debug-only reference to track the sessions list identity and detect stale usage
  List<WorkoutSession>? _lastIndexedSessions;

  // Pre-computed exerciseId → sorted-newest-first ExerciseLog and date index.
  // Rebuilt via [buildSessionIndex] whenever the session list changes.
  Map<String, List<({ExerciseLog log, DateTime date})>> _sessionIndex = {};

  // Callback to update targets with new growth models
  final void Function(String exerciseId, GrowthModel model)?
  onGrowthModelUpdated;

  AnalyticsManager(this._storage, this._mlService, {this.onGrowthModelUpdated});

  // Getters
  Map<String, GrowthModel> get growthModels => Map.unmodifiable(_growthModels);

  /// Build (or rebuild) the exerciseId → sorted log index from [sessions].
  ///
  /// Callers MUST call this after any session mutation (add, delete, update).
  /// The index maps each exercise id to a list of [ExerciseLog] instances
  /// ordered newest-first, which lets recommendation and progression APIs
  /// avoid repeated O(N log N) sorts and O(N²) scans on every render.
  void buildSessionIndex(List<WorkoutSession> sessions) {
    assert(() {
      _lastIndexedSessions = sessions;
      return true;
    }());

    final index = <String, List<({ExerciseLog log, DateTime date})>>{};

    // Sort sessions newest-first once and iterate
    final sorted = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => b.date.compareTo(a.date));

    for (final session in sorted) {
      for (final log in session.exercises) {
        if (log.sets.isNotEmpty) {
          index.putIfAbsent(log.exerciseId, () => []).add((log: log, date: session.date));
        }
      }
    }

    _sessionIndex = index;
  }

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
  /// Uses the most-recently-dated session containing this exercise as the
  /// basis for the recommendation. Reads from the pre-built session index
  /// so no sort is required at call time — O(1).
  List<SetRecommendation> getRecommendations(
    String exerciseId,
    List<WorkoutSession> sessions,
  ) {
    // Fast path: use pre-built index if available.
    final logs = _sessionIndex[exerciseId];
    final lastLog = (logs != null && logs.isNotEmpty)
        ? logs.first.log // already sorted newest-first
        : findMostRecentExerciseLog(exerciseId, sessions); // fallback

    if (lastLog == null || lastLog.sets.isEmpty) {
      return _mlService.getDefaultRecommendations(3);
    }

    return _mlService.recommendSets(
      lastSession: lastLog.sets,
      growthModel: _growthModels[exerciseId],
    );
  }

  /// Get volume progression for an exercise.
  ///
  /// Reads from the pre-built session index (sorted oldest-first by
  /// reversing the newest-first index list), so no allocation or sort is
  /// required at call time — O(K) where K is the number of logs for this
  /// exercise.
  List<({DateTime date, double volume})> getVolumeProgression(
    String exerciseId,
    List<WorkoutSession> sessions,
  ) {
    // Fast path: use pre-built index
    final logs = _sessionIndex[exerciseId];
    if (logs != null) {
      // Index is newest-first; progression needs oldest-first.
      return [
        for (final entry in logs.reversed)
          (date: entry.date, volume: entry.log.totalVolume),
      ];
    }

    // Fallback (index not built yet) — same as before, sort + scan.
    final data = <({DateTime date, double volume})>[];
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



  /// Get weekly volume by muscle group.
  ///
  /// [exerciseMap] is a pre-built id → Exercise map for O(1) lookups,
  /// eliminating the inner O(N) scan from the original [_findExercise].
  /// [now] parameter allows test injection of a fixed timestamp.
  Map<String, double> getWeeklyVolumeByMuscle(
    List<WorkoutSession> sessions,
    List<Exercise> exercises, {
    DateTime? now,
    Map<String, Exercise>? exerciseMap,
  }) {
    final volumeByMuscle = <String, double>{};
    final currentTime = now ?? DateTime.now();
    final weekAgo = currentTime.subtract(const Duration(days: 7));
    final Map<String, Exercise> lookup =
        exerciseMap ?? {for (final e in exercises) e.id: e};

    for (var session in sessions) {
      if (session.date.isBefore(weekAgo)) continue;

      for (var log in session.exercises) {
        final exercise = lookup[log.exerciseId];
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



  /// Get quick stats for dashboard
  Future<Map<String, dynamic>> getQuickStats() async {
    return await _storage.getQuickStats();
  }
}
