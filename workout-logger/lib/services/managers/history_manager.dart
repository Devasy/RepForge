// History Manager (Single Responsibility Principle)
//
// This class is responsible ONLY for managing workout history (past sessions).
// It handles:
// - Loading/saving workout sessions
// - Updating and deleting sessions
// - Querying session history
// - Triggering Health Connect sync after a new session is persisted
//   (via the optional IHealthSyncManager dependency).
//
// It does NOT handle active workout state or analytics calculations.

import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';
import '../interfaces/health_sync_manager_interface.dart';

/// Manages workout session history.
///
/// Following Single Responsibility Principle: this class only handles
/// historical session data, not active workouts or analytics.
class HistoryManager extends ChangeNotifier {
  final IStorageService _storage;
  final IHealthSyncManager? _healthSync;

  List<WorkoutSession> _sessions = [];

  // Callback for when sessions change (to notify other managers like AnalyticsManager)
  final void Function(Set<String> affectedExerciseIds)? onSessionsChanged;

  HistoryManager(
    this._storage, {
    IHealthSyncManager? healthSyncManager,
    this.onSessionsChanged,
  }) : _healthSync = healthSyncManager;

  // Getters
  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);
  int get totalSessions => _sessions.length;

  /// Load all sessions from storage
  Future<void> loadSessions() async {
    _sessions = await _storage.getAllWorkoutSessions();
    // Sort newest-first to ensure consistent ordering for queries
    _sessions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  /// Add a new session to history.
  ///
  /// Persists the session, updates in-memory state, then triggers a
  /// best-effort Health Connect sync if [healthSyncManager] is provided.
  /// [routineName] is forwarded as the HC exercise session title.
  Future<void> addSession(
    WorkoutSession session, {
    String? routineName,
  }) async {
    _sessions.insert(0, session);
    await _storage.saveWorkoutSession(session);

    final exerciseIds = session.exercises.map((e) => e.exerciseId).toSet();
    onSessionsChanged?.call(exerciseIds);
    notifyListeners();

    // Fire-and-forget HC sync — runs after UI is already updated.
    _healthSync?.syncSession(
      session,
      routineName: routineName,
      onSynced: _onHcSynced,
    );
  }

  /// Manually trigger a Health Connect sync for an existing session.
  ///
  /// Called from the ⋮ menu in the history UI when a session is unsynced.
  /// No-op when [healthSyncManager] was not provided.
  void syncSession(WorkoutSession session, {String? routineName}) {
    _healthSync?.syncSession(
      session,
      routineName: routineName,
      onSynced: _onHcSynced,
    );
  }

  /// Trigger a Health Connect sync for every session that has not yet been synced.
  ///
  /// Fires all syncs concurrently (fire-and-forget). Each successful sync
  /// stamps hcSyncedAt and persists via the normal _onHcSynced path.
  /// No-op when [healthSyncManager] was not provided.
  void syncAllUnsynced() {
    if (_healthSync == null) return;
    for (final session in _sessions) {
      if (session.hcSyncedAt == null) {
        _healthSync.syncSession(session, onSynced: _onHcSynced);
      }
    }
  }

  // Called by HealthSyncManager on successful sync.
  // Merges only hcSyncedAt into the current in-memory session so that any
  // edits made between sync being triggered and this callback firing are not
  // overwritten, then re-persists.
  void _onHcSynced(WorkoutSession updated) {
    final index = _sessions.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;
    final merged = _sessions[index].copyWith(hcSyncedAt: updated.hcSyncedAt);
    _sessions[index] = merged;
    _storage.saveWorkoutSession(merged).catchError((Object e) {
      debugPrint('HistoryManager: failed to persist hcSyncedAt: $e');
    });
    notifyListeners();
  }

  /// Get a session by ID
  WorkoutSession? getSession(String sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    return index != -1 ? _sessions[index] : null;
  }

  /// Get sessions for a specific exercise
  List<WorkoutSession> getSessionsForExercise(String exerciseId) {
    return _sessions
        .where(
          (session) => session.exercises.any((e) => e.exerciseId == exerciseId),
        )
        .toList();
  }

  /// Get sessions within a date range (inclusive of start and end).
  ///
  /// Tolerates inverted ranges (mirrors [StorageService.getSessionsInDateRange])
  /// so callers don't silently get an empty list when start/end are passed in
  /// the wrong order.
  List<WorkoutSession> getSessionsInDateRange(DateTime start, DateTime end) {
    final lo = start.isAfter(end) ? end : start;
    final hi = start.isAfter(end) ? start : end;
    return _sessions
        .where(
          (session) =>
              !session.date.isBefore(lo) && !session.date.isAfter(hi),
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
  ///
  /// Throws [StateError] if session is not found.
  Future<void> updateSession(WorkoutSession updatedSession) async {
    final index = _sessions.indexWhere((s) => s.id == updatedSession.id);
    if (index == -1) {
      throw StateError('Session ${updatedSession.id} not found');
    }

    final previousSession = _sessions[index];

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

    _sessions = List.from(_sessions)..[index] = updatedSession;

    // Keep sorted by date
    _sessions.sort((a, b) => b.date.compareTo(a.date));

    onSessionsChanged?.call(allAffectedExerciseIds);
    notifyListeners();
  }

  // ── Cache-only mutations (no storage I/O) ─────────────────────────────────
  // Called by WorkoutProvider after it has already handled storage, so that
  // HistoryManager's in-memory list stays in sync without a double-write.

  /// Remove a session from the in-memory list without touching storage.
  void evictSession(String sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;
    _sessions = List.from(_sessions)..removeAt(index);
    notifyListeners();
  }

  /// Replace a session in the in-memory list without touching storage.
  void patchSession(WorkoutSession updated) {
    final index = _sessions.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;
    _sessions = List.from(_sessions)..[index] = updated;
    _sessions.sort((a, b) => b.date.compareTo(a.date));
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
