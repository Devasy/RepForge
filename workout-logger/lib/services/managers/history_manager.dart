// History Manager (Single Responsibility Principle)
//
// This class is responsible ONLY for managing workout history (past sessions).
// It handles:
// - Loading/saving workout sessions
// - Updating and deleting sessions
// - Querying session history
//
// It does NOT handle active workout state or analytics calculations.

import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';

/// Manages workout session history.
///
/// Following Single Responsibility Principle: this class only handles
/// historical session data, not active workouts or analytics.
class HistoryManager extends ChangeNotifier {
  final IStorageService _storage;

  List<WorkoutSession> _sessions = [];

  // Callback for when sessions change (to notify other managers like AnalyticsManager)
  final void Function(Set<String> affectedExerciseIds)? onSessionsChanged;

  HistoryManager(this._storage, {this.onSessionsChanged});

  // Getters
  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);
  int get totalSessions => _sessions.length;

  /// Load all sessions from storage
  Future<void> loadSessions() async {
    _sessions = await _storage.getAllWorkoutSessions();
    notifyListeners();
  }

  /// Add a new session to history
  void addSession(WorkoutSession session) {
    _sessions.insert(0, session);
    final exerciseIds = session.exercises.map((e) => e.exerciseId).toSet();
    onSessionsChanged?.call(exerciseIds);
    notifyListeners();
  }

  /// Get a session by ID
  WorkoutSession? getSession(String sessionId) {
    try {
      return _sessions.firstWhere((s) => s.id == sessionId);
    } catch (_) {
      return null;
    }
  }

  /// Get sessions for a specific exercise
  List<WorkoutSession> getSessionsForExercise(String exerciseId) {
    return _sessions
        .where(
          (session) => session.exercises.any((e) => e.exerciseId == exerciseId),
        )
        .toList();
  }

  /// Get sessions within a date range
  List<WorkoutSession> getSessionsInDateRange(DateTime start, DateTime end) {
    return _sessions
        .where(
          (session) =>
              session.date.isAfter(start) && session.date.isBefore(end),
        )
        .toList();
  }

  /// Get sessions from the last N days
  List<WorkoutSession> getRecentSessions(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _sessions.where((s) => s.date.isAfter(cutoff)).toList();
  }

  /// Delete a workout session
  Future<void> deleteSession(String sessionId) async {
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);

    if (sessionIndex == -1) {
      debugPrint('Session $sessionId not found, skipping deletion');
      return;
    }

    final session = _sessions[sessionIndex];
    final affectedExerciseIds = session.exercises
        .map((e) => e.exerciseId)
        .toSet();

    await _storage.deleteWorkoutSession(sessionId);
    _sessions = List.from(_sessions)..removeAt(sessionIndex);

    onSessionsChanged?.call(affectedExerciseIds);
    notifyListeners();
  }

  /// Update an existing workout session
  Future<void> updateSession(WorkoutSession updatedSession) async {
    final previousSession = _sessions.firstWhere(
      (s) => s.id == updatedSession.id,
      orElse: () => updatedSession,
    );

    // Gather affected exercise IDs from both old and new versions
    final previousExerciseIds = previousSession.exercises
        .map((e) => e.exerciseId)
        .toSet();
    final updatedExerciseIds = updatedSession.exercises
        .map((e) => e.exerciseId)
        .toSet();
    final allAffectedExerciseIds = previousExerciseIds.union(
      updatedExerciseIds,
    );

    await _storage.saveWorkoutSession(updatedSession);

    final index = _sessions.indexWhere((s) => s.id == updatedSession.id);
    if (index != -1) {
      _sessions = List.from(_sessions)..[index] = updatedSession;
    }

    // Keep sorted by date
    _sessions.sort((a, b) => b.date.compareTo(a.date));

    onSessionsChanged?.call(allAffectedExerciseIds);
    notifyListeners();
  }

  /// Get last session containing a specific exercise
  ExerciseLog? getLastSessionForExercise(String exerciseId) {
    for (var session in _sessions) {
      for (var log in session.exercises) {
        if (log.exerciseId == exerciseId) {
          return log;
        }
      }
    }
    return null;
  }
}
