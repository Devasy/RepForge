// Workout Provider - State Management for the App

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../data/exercise_database.dart';
import 'storage_service.dart';
import 'ml_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  // State
  List<WorkoutSession> _sessions = [];
  List<Routine> _routines = [];
  List<Target> _targets = [];
  List<MuscleGroup> _muscleGroups = [];
  List<Exercise> _allExercises = [];
  Map<String, GrowthModel> _growthModels = {}; // exerciseId -> GrowthModel

  // Active workout state
  WorkoutSession? _activeSession;
  Routine? _activeRoutine;
  int _currentExerciseIndex = 0;
  List<ExerciseLog> _currentExerciseLogs = [];
  DateTime? _workoutStartTime;

  // Getters
  List<WorkoutSession> get sessions => _sessions;
  List<Routine> get routines => _routines;
  List<Target> get targets => _targets;
  List<MuscleGroup> get muscleGroups => _muscleGroups;
  List<Exercise> get allExercises => _allExercises;
  
  bool get hasActiveWorkout => _activeSession != null || _workoutStartTime != null;
  Routine? get activeRoutine => _activeRoutine;
  int get currentExerciseIndex => _currentExerciseIndex;
  List<ExerciseLog> get currentExerciseLogs => _currentExerciseLogs;
  DateTime? get workoutStartTime => _workoutStartTime;

  WorkoutProvider(this._storage);

  // ==================== INITIALIZATION ====================

  Future<void> init() async {
    await _storage.init();
    await loadAllData();
    await _trainAllGrowthModels();
  }

  Future<void> loadAllData() async {
    _sessions = await _storage.getAllWorkoutSessions();
    _routines = await _storage.getAllRoutines();
    _targets = await _storage.getAllTargets();
    _muscleGroups = await _storage.getAllMuscleGroups();
    _allExercises = await _storage.getAllExercises();
    notifyListeners();
  }

  Future<void> _trainAllGrowthModels() async {
    final exerciseIds = <String>{};
    
    // Get all unique exercise IDs from sessions
    for (var session in _sessions) {
      for (var log in session.exercises) {
        exerciseIds.add(log.exerciseId);
      }
    }

    // Train model for each exercise
    for (var exerciseId in exerciseIds) {
      await _updateGrowthModel(exerciseId);
    }
  }

  Future<void> _updateGrowthModel(String exerciseId) async {
    final dataPoints = MLService.extractExerciseDataPoints(exerciseId, _sessions);
    if (dataPoints.length >= 2) {
      _growthModels[exerciseId] = MLService.trainGrowthModel(dataPoints);
    }
  }

  // ==================== EXERCISE HELPERS ====================

  Exercise? getExercise(String id) {
    try {
      return _allExercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return ExerciseDatabase.getById(id);
    }
  }

  String getExerciseName(String id) {
    return getExercise(id)?.name ?? 'Unknown Exercise';
  }

  String getMuscleGroupName(String id) {
    return MuscleGroups.names[id] ?? 'Unknown';
  }

  // ==================== WORKOUT FLOW ====================

  /// Start a new workout with a routine
  void startWorkout({Routine? routine, List<String>? exerciseIds}) {
    _workoutStartTime = DateTime.now();
    _activeRoutine = routine;
    _currentExerciseIndex = 0;
    _currentExerciseLogs = [];

    // Initialize exercise logs based on routine or provided exercise IDs
    final ids = routine?.exerciseIds ?? exerciseIds ?? [];
    for (var id in ids) {
      _currentExerciseLogs.add(ExerciseLog(exerciseId: id, sets: []));
    }

    notifyListeners();
  }

  /// Get current exercise being performed
  Exercise? get currentExercise {
    if (_currentExerciseLogs.isEmpty || 
        _currentExerciseIndex >= _currentExerciseLogs.length) {
      return null;
    }
    final exerciseId = _currentExerciseLogs[_currentExerciseIndex].exerciseId;
    return getExercise(exerciseId);
  }

  /// Get current exercise log
  ExerciseLog? get currentExerciseLog {
    if (_currentExerciseLogs.isEmpty || 
        _currentExerciseIndex >= _currentExerciseLogs.length) {
      return null;
    }
    return _currentExerciseLogs[_currentExerciseIndex];
  }

  /// Add a set to current exercise
  void addSet(WorkoutSet set) {
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

  /// Move to next exercise
  bool nextExercise() {
    if (_currentExerciseIndex < _currentExerciseLogs.length - 1) {
      _currentExerciseIndex++;
      notifyListeners();
      return true;
    }
    return false; // No more exercises
  }

  /// Move to previous exercise
  bool previousExercise() {
    if (_currentExerciseIndex > 0) {
      _currentExerciseIndex--;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Finish workout and save
  Future<WorkoutSession> finishWorkout({String? notes}) async {
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

    await _storage.saveWorkoutSession(session);
    _sessions.insert(0, session);

    // Update growth models for performed exercises
    for (var log in completedExercises) {
      await _updateGrowthModel(log.exerciseId);
    }

    // Update targets
    await _updateTargetsFromSession(session);

    // Clear active workout state
    _activeSession = null;
    _activeRoutine = null;
    _currentExerciseIndex = 0;
    _currentExerciseLogs = [];
    _workoutStartTime = null;

    notifyListeners();
    return session;
  }

  /// Cancel workout without saving
  void cancelWorkout() {
    _activeSession = null;
    _activeRoutine = null;
    _currentExerciseIndex = 0;
    _currentExerciseLogs = [];
    _workoutStartTime = null;
    notifyListeners();
  }

  // ==================== RECOMMENDATIONS ====================

  /// Get set recommendations for an exercise
  List<SetRecommendation> getRecommendations(String exerciseId) {
    // Find last session with this exercise
    ExerciseLog? lastLog;
    for (var session in _sessions) {
      for (var log in session.exercises) {
        if (log.exerciseId == exerciseId) {
          lastLog = log;
          break;
        }
      }
      if (lastLog != null) break;
    }

    if (lastLog == null || lastLog.sets.isEmpty) {
      return MLService.getDefaultRecommendations(3);
    }

    return MLService.recommendSets(
      lastSession: lastLog.sets,
      growthModel: _growthModels[exerciseId],
    );
  }

  /// Get last session data for an exercise
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

  // ==================== ROUTINES ====================

  Future<void> createRoutine(String name, List<String> exerciseIds) async {
    final routine = Routine(
      id: _uuid.v4(),
      name: name,
      exerciseIds: exerciseIds,
    );
    await _storage.saveRoutine(routine);
    _routines.add(routine);
    notifyListeners();
  }

  Future<void> updateRoutine(Routine routine) async {
    await _storage.saveRoutine(routine);
    final index = _routines.indexWhere((r) => r.id == routine.id);
    if (index != -1) {
      _routines[index] = routine;
    }
    notifyListeners();
  }

  Future<void> deleteRoutine(String id) async {
    await _storage.deleteRoutine(id);
    _routines.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  // ==================== TARGETS ====================

  Future<void> createTarget({
    required String exerciseId,
    required String type,
    required double targetValue,
  }) async {
    // Get current value from last session
    double currentValue = 0;
    final lastLog = getLastSessionForExercise(exerciseId);
    if (lastLog != null && lastLog.sets.isNotEmpty) {
      switch (type) {
        case 'reps':
          currentValue = lastLog.sets.map((s) => s.reps).reduce((a, b) => a > b ? a : b).toDouble();
          break;
        case 'weight':
          currentValue = lastLog.sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
          break;
        case 'volume':
          currentValue = lastLog.totalVolume;
          break;
      }
    }

    // Predict completion date
    DateTime? estimatedDate;
    final growthModel = _growthModels[exerciseId];
    if (growthModel != null) {
      estimatedDate = MLService.predictTargetCompletion(
        currentValue: currentValue,
        targetValue: targetValue,
        growthModel: growthModel,
      );
    }

    final target = Target(
      id: _uuid.v4(),
      exerciseId: exerciseId,
      targetType: type,
      targetValue: targetValue,
      currentValue: currentValue,
      estimatedCompletionDate: estimatedDate,
    );

    await _storage.saveTarget(target);
    _targets.add(target);
    notifyListeners();
  }

  Future<void> _updateTargetsFromSession(WorkoutSession session) async {
    for (var log in session.exercises) {
      final exerciseTargets = _targets.where((t) => 
        t.exerciseId == log.exerciseId && !t.isCompleted
      ).toList();

      for (var target in exerciseTargets) {
        double newValue = 0;
        switch (target.targetType) {
          case 'reps':
            newValue = log.sets.map((s) => s.reps).reduce((a, b) => a > b ? a : b).toDouble();
            break;
          case 'weight':
            newValue = log.sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
            break;
          case 'volume':
            newValue = log.totalVolume;
            break;
        }

        target.currentValue = newValue;
        target.isCompleted = newValue >= target.targetValue;

        // Update prediction
        final growthModel = _growthModels[log.exerciseId];
        if (growthModel != null && !target.isCompleted) {
          target.estimatedCompletionDate = MLService.predictTargetCompletion(
            currentValue: newValue,
            targetValue: target.targetValue,
            growthModel: growthModel,
          );
        }

        await _storage.saveTarget(target);
      }
    }
    notifyListeners();
  }

  Future<void> deleteTarget(String id) async {
    await _storage.deleteTarget(id);
    _targets.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ==================== ANALYTICS ====================

  /// Get volume progression for an exercise
  List<({DateTime date, double volume})> getVolumeProgression(String exerciseId) {
    final data = <({DateTime date, double volume})>[];
    
    for (var session in _sessions.reversed) {
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
  Map<String, double> getWeeklyVolumeByMuscle() {
    final volumeByMuscle = <String, double>{};
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    for (var session in _sessions) {
      if (session.date.isBefore(weekAgo)) continue;

      for (var log in session.exercises) {
        final exercise = getExercise(log.exerciseId);
        if (exercise == null) continue;

        for (var activation in exercise.muscleActivations) {
          final muscleVolume = log.totalVolume * (activation.activationPercentage / 100);
          volumeByMuscle[activation.muscleGroupId] = 
            (volumeByMuscle[activation.muscleGroupId] ?? 0) + muscleVolume;
        }
      }
    }

    return volumeByMuscle;
  }

  /// Get growth model for an exercise
  GrowthModel? getGrowthModel(String exerciseId) => _growthModels[exerciseId];

  // ==================== QUICK STATS ====================

  Future<Map<String, dynamic>> getQuickStats() async {
    return await _storage.getQuickStats();
  }
}
