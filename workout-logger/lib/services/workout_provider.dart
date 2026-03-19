// Workout Provider - State Management for the App
//
// NOTE: This class is maintained for backward compatibility.
// For new code, consider using the individual managers:
// - ActiveWorkoutManager: Current workout state
// - HistoryManager: Past sessions
// - RoutineManager: Workout routines
// - ExerciseManager: Exercise library
// - TargetManager: Goals and targets
// - AnalyticsManager: Statistics and recommendations
// - ProgramManager: Training programs (multi-week plans)
//
// Following Dependency Inversion Principle: this class now depends on
// abstractions (IStorageService, IMLService) rather than concrete implementations.

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../data/exercise_database.dart';
import 'interfaces/storage_service_interface.dart';
import 'interfaces/ml_service_interface.dart';
import 'ml_service.dart';
import 'strategies/target_calculator.dart';
import 'managers/program_manager.dart';

class WorkoutProvider extends ChangeNotifier {
  final IStorageService _storage;
  final IMLService _mlService;
  final Uuid _uuid = const Uuid();

  // State
  List<WorkoutSession> _sessions = [];
  List<Routine> _routines = [];
  List<Target> _targets = [];
  List<MuscleGroup> _muscleGroups = [];
  List<Exercise> _allExercises = [];
  final Map<String, GrowthModel> _growthModels =
      {}; // exerciseId -> GrowthModel

  late final ProgramManager programManager;

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

  bool get hasActiveWorkout =>
      _activeSession != null || _workoutStartTime != null;
  Routine? get activeRoutine => _activeRoutine;
  int get currentExerciseIndex => _currentExerciseIndex;
  List<ExerciseLog> get currentExerciseLogs => _currentExerciseLogs;
  DateTime? get workoutStartTime => _workoutStartTime;

  /// Create WorkoutProvider with dependency injection.
  ///
  /// Following Dependency Inversion Principle: accepts abstractions
  /// rather than concrete implementations.
  WorkoutProvider(this._storage, {IMLService? mlService})
    : _mlService = mlService ?? MLService() {
    programManager = ProgramManager(_storage);
  }

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
    await programManager.loadPrograms();
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
    final dataPoints = _mlService.extractExerciseDataPoints(
      exerciseId,
      _sessions,
    );
    if (dataPoints.length >= 2) {
      _growthModels[exerciseId] = _mlService.trainGrowthModel(dataPoints);
    } else {
      // Remove stale model if not enough data to train (e.g. after deletion)
      _growthModels.remove(exerciseId);
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

  // ==================== CUSTOM EXERCISES ====================

  /// Allowed category values for exercises
  static const Set<String> _allowedCategories = {'compound', 'isolation'};

  /// Add a custom exercise created by the user
  ///
  /// Throws [ArgumentError] if inputs are invalid.
  Future<void> addCustomExercise({
    required String name,
    required String category,
    required String primaryMuscleGroupId,
  }) async {
    // Validate and normalize name (trim and collapse whitespace)
    final normalizedName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedName.isEmpty) {
      throw ArgumentError('Exercise name cannot be empty');
    }

    // Validate primaryMuscleGroupId
    if (primaryMuscleGroupId.isEmpty) {
      throw ArgumentError('Primary muscle group is required');
    }

    // Normalize and validate category
    final normalizedCategory = category.toLowerCase().trim();
    if (!_allowedCategories.contains(normalizedCategory)) {
      throw ArgumentError(
        'Invalid category "$category". Must be one of: ${_allowedCategories.join(", ")}',
      );
    }

    // Generate unique ID
    final id = 'custom_${_uuid.v4()}';

    // Create muscle activation (100% for primary muscle in v1)
    final muscleActivations = [
      MuscleActivation(
        muscleGroupId: primaryMuscleGroupId,
        activationPercentage: 100,
      ),
    ];

    // Create exercise with isCustom flag using normalized values
    final exercise = Exercise(
      id: id,
      name: normalizedName,
      muscleActivations: muscleActivations,
      category: normalizedCategory,
      isCustom: true,
    );

    // Persist to storage
    await _storage.saveCustomExercise(exercise);

    // Add to local list (use List.from for immutability)
    _allExercises = List.from(_allExercises)..add(exercise);

    notifyListeners();
  }

  /// Delete a custom exercise
  ///
  /// Returns false if exercise not found, not custom, or IN USE by sessions/routines/targets
  Future<bool> deleteCustomExercise(String exerciseId) async {
    // Only allow deleting custom exercises
    final exercise = getExercise(exerciseId);
    if (exercise == null || !exercise.isCustom) {
      return false;
    }

    // Check for references in Sessions
    for (var session in _sessions) {
      if (session.exercises.any((e) => e.exerciseId == exerciseId)) {
        debugPrint(
          'Cannot delete custom exercise: Used in session ${session.id}',
        );
        return false;
      }
    }

    // Check for references in Routines
    for (var routine in _routines) {
      if (routine.exerciseIds.contains(exerciseId)) {
        debugPrint(
          'Cannot delete custom exercise: Used in routine ${routine.name}',
        );
        return false;
      }
    }

    // Check for references in Targets
    for (var target in _targets) {
      if (target.exerciseId == exerciseId) {
        debugPrint(
          'Cannot delete custom exercise: Used in target ${target.id}',
        );
        return false;
      }
    }

    // Check for references in active workout
    if (_currentExerciseLogs.any((l) => l.exerciseId == exerciseId)) {
      debugPrint('Cannot delete custom exercise: Used in active workout');
      return false;
    }
    if (_activeRoutine?.exerciseIds.contains(exerciseId) ?? false) {
      debugPrint('Cannot delete custom exercise: Used in active routine');
      return false;
    }

    // Remove from storage
    await _storage.deleteCustomExercise(exerciseId);

    // Remove from local list
    _allExercises = List.from(_allExercises)
      ..removeWhere((e) => e.id == exerciseId);

    // Also remove any growth model
    _growthModels.remove(exerciseId);

    notifyListeners();
    return true;
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
      return _mlService.getDefaultRecommendations(3);
    }

    return _mlService.recommendSets(
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

  // ==================== SESSION MANAGEMENT ====================

  /// Delete a workout session
  Future<void> deleteWorkoutSession(String sessionId) async {
    // Find the session to get exercise IDs for model retraining
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);

    // Return early if session not found (e.g., stale sessionId)
    if (sessionIndex == -1) {
      debugPrint('Session $sessionId not found, skipping deletion');
      return;
    }

    final session = _sessions[sessionIndex];
    // All exercises in the deleted session need their growth models retrained
    final affectedExerciseIds = session.exercises
        .map((e) => e.exerciseId)
        .toSet();

    // Remove from storage first
    await _storage.deleteWorkoutSession(sessionId);

    // Remove from local list
    _sessions = List.from(_sessions)..removeWhere((s) => s.id == sessionId);

    // Retrain growth models for all affected exercises
    // (their data has changed because a session was removed)
    for (var exerciseId in affectedExerciseIds) {
      await _updateGrowthModel(exerciseId);
    }

    // Recalculate targets for affected exercises
    await _recalculateTargets(affectedExerciseIds);

    notifyListeners();
  }

  /// Update an existing workout session
  Future<void> updateWorkoutSession(WorkoutSession updatedSession) async {
    // Find the previous version of the session to compare exercises
    final previousSession = _sessions.firstWhere(
      (s) => s.id == updatedSession.id,
      orElse: () => updatedSession, // Fallback if not found (shouldn't happen)
    );

    // Gather exercise IDs from BOTH previous and updated sessions
    // so we retrain models for exercises that were added OR removed
    final previousExerciseIds = previousSession.exercises
        .map((e) => e.exerciseId)
        .toSet();
    final updatedExerciseIds = updatedSession.exercises
        .map((e) => e.exerciseId)
        .toSet();
    final allAffectedExerciseIds = previousExerciseIds.union(
      updatedExerciseIds,
    );

    // Save to storage (overwrites by ID)
    await _storage.saveWorkoutSession(updatedSession);

    // Update local list
    final index = _sessions.indexWhere((s) => s.id == updatedSession.id);
    if (index != -1) {
      _sessions = List.from(_sessions)..[index] = updatedSession;
    }

    // Sort sessions by date (most recent first)
    _sessions.sort((a, b) => b.date.compareTo(a.date));

    // Retrain growth models for ALL affected exercises
    // (both exercises that were in the old session and exercises in the new session)
    for (var exerciseId in allAffectedExerciseIds) {
      await _updateGrowthModel(exerciseId);
    }

    // Recalculate targets for affected exercises
    await _recalculateTargets(allAffectedExerciseIds);

    notifyListeners();
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
    // Get current value from history using Strategy Pattern (Open/Closed Principle)
    double currentValue = _calculateCurrentTargetValue(exerciseId, type);

    // Predict completion date using injected ML service
    DateTime? estimatedDate;
    final growthModel = _growthModels[exerciseId];
    if (growthModel != null) {
      estimatedDate = _mlService.predictTargetCompletion(
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
      isCompleted: currentValue >= targetValue,
    );

    await _storage.saveTarget(target);
    _targets.add(target);
    notifyListeners();
  }

  /// Recalculate targets for a set of exercises based on full history
  Future<void> _recalculateTargets(Set<String> exerciseIds) async {
    for (var exerciseId in exerciseIds) {
      final relevantTargets = _targets
          .where((t) => t.exerciseId == exerciseId)
          .toList();

      for (var target in relevantTargets) {
        // Recalculate current value from all sessions
        final newValue = _calculateCurrentTargetValue(
          exerciseId,
          target.targetType,
        );

        target.currentValue = newValue;

        // If it was completed but now isn't (e.g. deleted PR session), uncomplete it
        // If it wasn't completed but now is (unlikely on delete, but possible on edit), complete it
        target.isCompleted = newValue >= target.targetValue;

        // Update prediction if not completed using injected ML service
        if (!target.isCompleted) {
          final growthModel = _growthModels[exerciseId];
          if (growthModel != null) {
            target.estimatedCompletionDate = _mlService.predictTargetCompletion(
              currentValue: newValue,
              targetValue: target.targetValue,
              growthModel: growthModel,
            );
          } else {
            target.estimatedCompletionDate = null;
          }
        } else {
          target.estimatedCompletionDate = null;
        }

        await _storage.saveTarget(target);
      }
    }
  }

  /// Calculate the current best value for a target type from all history
  /// Uses Strategy Pattern (Open/Closed Principle) via TargetCalculatorFactory
  double _calculateCurrentTargetValue(String exerciseId, String targetType) {
    // Try to use the strategy pattern first
    final calculator = TargetCalculatorFactory.getCalculator(targetType);
    if (calculator != null) {
      return calculator.calculate(exerciseId, _sessions);
    }

    // Fallback for backward compatibility with unknown types
    double bestValue = 0;

    for (var session in _sessions) {
      for (var log in session.exercises) {
        if (log.exerciseId == exerciseId && log.sets.isNotEmpty) {
          double sessionValue = 0;
          switch (targetType) {
            case 'reps':
              sessionValue = log.sets
                  .map((s) => s.reps)
                  .reduce((a, b) => a > b ? a : b)
                  .toDouble();
              break;
            case 'weight':
              sessionValue = log.sets
                  .map((s) => s.weight)
                  .reduce((a, b) => a > b ? a : b);
              break;
            case 'volume':
              sessionValue = log.totalVolume;
              break;
          }
          if (sessionValue > bestValue) {
            bestValue = sessionValue;
          }
        }
      }
    }
    return bestValue;
  }

  Future<void> _updateTargetsFromSession(WorkoutSession session) async {
    // This is optimzed for adding new sessions, but we can just use the generic recalculate
    // to be safe and consistent, although it's slightly more expensive.
    // Given the scale of mobile data, scanning history is acceptable.
    final exerciseIds = session.exercises.map((e) => e.exerciseId).toSet();
    await _recalculateTargets(exerciseIds);
  }

  Future<void> deleteTarget(String id) async {
    await _storage.deleteTarget(id);
    _targets.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ==================== ANALYTICS ====================

  /// Get volume progression for an exercise
  List<({DateTime date, double volume})> getVolumeProgression(
    String exerciseId,
  ) {
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
          final muscleVolume =
              log.totalVolume * (activation.activationPercentage / 100);
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

  // ==================== BACKUP ====================

  Future<String> exportAllData() async {
    return await _storage.exportAllData();
  }

  Future<void> importData(String jsonData) async {
    await _storage.importData(jsonData);
    await loadAllData();
    await _trainAllGrowthModels();
  }
}
