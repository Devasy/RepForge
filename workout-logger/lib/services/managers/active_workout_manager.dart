// Active Workout Manager (Single Responsibility Principle)
//
// This class is responsible ONLY for managing the state of the currently
// active workout session. It handles:
// - Starting/stopping workouts
// - Current exercise index navigation
// - Adding/removing sets to the current exercise
//
// It does NOT handle persistence (that's delegated to storage service)
// or history management (that's a separate concern).

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';

/// Manages the state of an active workout session.
///
/// Following Single Responsibility Principle: this class only handles
/// the live workout flow, not history, analytics, or persistence concerns.
class ActiveWorkoutManager extends ChangeNotifier {
  final IStorageService _storage;
  final Uuid _uuid = const Uuid();

  // Active workout state
  Routine? _activeRoutine;
  int _currentExerciseIndex = 0;
  List<ExerciseLog> _currentExerciseLogs = [];
  DateTime? _workoutStartTime;

  // Callback for when workout is saved (to notify other managers)
  final void Function(WorkoutSession)? onWorkoutSaved;

  ActiveWorkoutManager(this._storage, {this.onWorkoutSaved});

  // Getters
  bool get hasActiveWorkout => _workoutStartTime != null;
  Routine? get activeRoutine => _activeRoutine;
  int get currentExerciseIndex => _currentExerciseIndex;
  List<ExerciseLog> get currentExerciseLogs =>
      List.unmodifiable(_currentExerciseLogs);
  DateTime? get workoutStartTime => _workoutStartTime;
  int get totalExercises => _currentExerciseLogs.length;
  bool get isLastExercise =>
      _currentExerciseIndex >= _currentExerciseLogs.length - 1;
  bool get isFirstExercise => _currentExerciseIndex == 0;

  /// Get current exercise log
  ExerciseLog? get currentExerciseLog {
    if (_currentExerciseLogs.isEmpty ||
        _currentExerciseIndex >= _currentExerciseLogs.length) {
      return null;
    }
    return _currentExerciseLogs[_currentExerciseIndex];
  }

  /// Get current exercise ID
  String? get currentExerciseId => currentExerciseLog?.exerciseId;

  /// Start a new workout with a routine or list of exercises
  ///
  /// Throws [StateError] if a workout is already in progress or if no
  /// exercises are provided.
  void startWorkout({Routine? routine, List<String>? exerciseIds}) {
    if (hasActiveWorkout) {
      throw StateError(
        'A workout is already in progress. Cancel or finish it first.',
      );
    }

    // Resolve exercise IDs from routine or provided list
    final ids = routine?.exerciseIds ?? exerciseIds ?? [];

    // Validate that at least one exercise is provided
    if (ids.isEmpty) {
      throw StateError(
        'Cannot start a workout with zero exercises. '
        'Provide a routine with exercises or a non-empty exerciseIds list.',
      );
    }

    _workoutStartTime = DateTime.now();
    _activeRoutine = routine;
    _currentExerciseIndex = 0;
    _currentExerciseLogs = [];

    // Initialize exercise logs based on routine or provided exercise IDs
    for (var id in ids) {
      _currentExerciseLogs.add(ExerciseLog(exerciseId: id, sets: []));
    }

    notifyListeners();
  }

  /// Add a set to current exercise
  void addSet(WorkoutSet set) {
    if (!hasActiveWorkout) {
      throw StateError('No active workout. Start a workout first.');
    }

    if (_currentExerciseIndex < _currentExerciseLogs.length) {
      final currentLog = _currentExerciseLogs[_currentExerciseIndex];
      _currentExerciseLogs[_currentExerciseIndex] = ExerciseLog(
        exerciseId: currentLog.exerciseId,
        sets: [...currentLog.sets, set],
        notes: currentLog.notes,
      );
      notifyListeners();
    }
  }

  /// Remove last set from current exercise
  void removeLastSet() {
    if (!hasActiveWorkout) return;

    if (_currentExerciseIndex < _currentExerciseLogs.length) {
      final currentLog = _currentExerciseLogs[_currentExerciseIndex];
      if (currentLog.sets.isNotEmpty) {
        final newSets = List<WorkoutSet>.from(currentLog.sets)..removeLast();
        _currentExerciseLogs[_currentExerciseIndex] = ExerciseLog(
          exerciseId: currentLog.exerciseId,
          sets: newSets,
          notes: currentLog.notes,
        );
        notifyListeners();
      }
    }
  }

  /// Update notes for current exercise
  void updateCurrentExerciseNotes(String? notes) {
    if (!hasActiveWorkout) return;

    if (_currentExerciseIndex < _currentExerciseLogs.length) {
      final currentLog = _currentExerciseLogs[_currentExerciseIndex];
      _currentExerciseLogs[_currentExerciseIndex] = ExerciseLog(
        exerciseId: currentLog.exerciseId,
        sets: currentLog.sets,
        notes: notes,
      );
      notifyListeners();
    }
  }

  /// Move to next exercise
  /// Returns true if moved, false if already at last exercise
  bool nextExercise() {
    if (_currentExerciseIndex < _currentExerciseLogs.length - 1) {
      _currentExerciseIndex++;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Move to previous exercise
  /// Returns true if moved, false if already at first exercise
  bool previousExercise() {
    if (_currentExerciseIndex > 0) {
      _currentExerciseIndex--;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Jump to a specific exercise by index
  void goToExercise(int index) {
    if (index >= 0 && index < _currentExerciseLogs.length) {
      _currentExerciseIndex = index;
      notifyListeners();
    }
  }

  /// Finish workout and save
  ///
  /// Note: If saving fails, the active workout state remains intact and the
  /// exception is rethrown. Callers must handle errors appropriately.
  Future<WorkoutSession> finishWorkout({String? notes}) async {
    if (!hasActiveWorkout) {
      throw StateError('No active workout to finish.');
    }

    final duration = _workoutStartTime != null
        ? DateTime.now().difference(_workoutStartTime!).inMinutes
        : 0;

    // Filter out exercises with no sets
    final completedExercises = _currentExerciseLogs
        .where((log) => log.sets.isNotEmpty)
        .toList();

    final session = WorkoutSession(
      id: _uuid.v4(),
      date: _workoutStartTime ?? DateTime.now(),
      routineId: _activeRoutine?.id,
      exercises: completedExercises,
      duration: duration,
      notes: notes,
    );

    try {
      await _storage.saveWorkoutSession(session);
    } catch (e) {
      // Log the error and rethrow - active workout state remains intact
      debugPrint('Failed to save workout session: $e');
      rethrow;
    }

    // Notify callback and ensure cleanup happens even if callback throws
    try {
      onWorkoutSaved?.call(session);
    } finally {
      // Always clear active workout state
      _resetState();
      notifyListeners();
    }

    return session;
  }

  /// Cancel workout without saving
  void cancelWorkout() {
    _resetState();
    notifyListeners();
  }

  void _resetState() {
    _activeRoutine = null;
    _currentExerciseIndex = 0;
    _currentExerciseLogs = [];
    _workoutStartTime = null;
  }
}
