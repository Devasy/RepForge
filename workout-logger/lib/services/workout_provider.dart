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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../data/exercise_database.dart';
import 'interfaces/storage_service_interface.dart';
import 'interfaces/ml_service_interface.dart';
import 'interfaces/health_connect_service_interface.dart';
import 'ml_service.dart';
import 'strategies/target_calculator.dart';
import 'managers/program_manager.dart';
import 'utils/exercise_history.dart';

enum StartWorkoutConflictAction { resume, discardAndStart, cancel }

class WorkoutInProgressError extends StateError {
  WorkoutInProgressError() : super('A workout is already in progress.');
}

class WorkoutProvider extends ChangeNotifier {
  final IStorageService _storage;
  final IMLService _mlService;
  final IHealthConnectService? _healthConnect;
  final Uuid _uuid = const Uuid();

  // State
  List<WorkoutSession> _sessions = [];
  List<Routine> _routines = [];
  List<Target> _targets = [];
  List<MuscleGroup> _muscleGroups = [];
  List<Exercise> _allExercises = [];
  final Map<String, GrowthModel> _growthModels =
      {}; // exerciseId -> GrowthModel

  final ProgramManager programManager;

  // Active workout state
  WorkoutSession? _activeSession;
  Routine? _activeRoutine;
  ProgramDay? _activeProgramDay;
  ProgramWeek? _activeProgramWeek;
  int _currentExerciseIndex = 0;
  List<ExerciseLog> _currentExerciseLogs = [];
  DateTime? _workoutStartTime;
  static const String _draftKey = 'active_workout_draft';
  static const int _draftSchemaVersion = 1;
  bool _draftRestoreInProgress = false;
  Future<void> _draftWriteQueue = Future.value();

  // Getters
  List<WorkoutSession> get sessions => _sessions;
  List<Routine> get routines => _routines;
  List<Target> get targets => _targets;
  List<MuscleGroup> get muscleGroups => _muscleGroups;
  List<Exercise> get allExercises => _allExercises;

  bool get hasActiveWorkout =>
      _activeSession != null || _workoutStartTime != null;
  Routine? get activeRoutine => _activeRoutine;
  ProgramDay? get activeProgramDay => _activeProgramDay;
  ProgramWeek? get activeProgramWeek => _activeProgramWeek;
  int get currentExerciseIndex => _currentExerciseIndex;
  List<ExerciseLog> get currentExerciseLogs => _currentExerciseLogs;
  DateTime? get workoutStartTime => _workoutStartTime;

  /// Create WorkoutProvider with dependency injection.
  ///
  /// Following Dependency Inversion Principle: accepts abstractions
  /// rather than concrete implementations. [programManager] defaults to a
  /// new ProgramManager backed by the same storage if not provided.
  WorkoutProvider(
    this._storage, {
    IMLService? mlService,
    IHealthConnectService? healthConnectService,
    required this.programManager,
  })  : _mlService = mlService ?? MLService(),
        _healthConnect = healthConnectService;

  // ==================== INITIALIZATION ====================

  Future<void> init() async {
    await _storage.init();
    await loadAllData();
    await _trainAllGrowthModels();
    await _restoreDraftIfAny();
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

  Future<void> _persistDraft() async {
    if (_draftRestoreInProgress) {
      return;
    }

    if (!hasActiveWorkout || _workoutStartTime == null) {
      await _clearDraft();
      return;
    }

    final draft = jsonEncode({
      'schemaVersion': _draftSchemaVersion,
      'startTime': _workoutStartTime!.toIso8601String(),
      'routineId': _activeRoutine?.id,
      'programDay': _activeProgramDay?.toJson(),
      'programWeek': _activeProgramWeek?.toJson(),
      'currentExerciseIndex': _currentExerciseIndex,
      'currentExerciseLogs': _currentExerciseLogs
          .map((log) => log.toJson())
          .toList(),
    });

    await _enqueueDraftWrite(() async {
      try {
        await _storage.saveSetting(_draftKey, draft);
      } catch (e) {
        debugPrint('Failed to persist active workout draft: $e');
      }
    });
  }

  Future<void> _enqueueDraftWrite(Future<void> Function() writeOperation) {
    _draftWriteQueue = _draftWriteQueue
        .catchError((_) {})
        .then((_) => writeOperation());
    return _draftWriteQueue;
  }

  Future<void> _clearDraft() async {
    await _enqueueDraftWrite(() async {
      try {
        await _storage.saveSetting(_draftKey, '');
      } catch (e) {
        debugPrint('Failed to clear active workout draft: $e');
      }
    });
  }

  Future<void> _restoreDraftIfAny() async {
    String? rawDraft;
    try {
      rawDraft = await _storage.getSetting(_draftKey);
    } catch (e) {
      debugPrint('Failed to read active workout draft: $e');
      return;
    }

    if (rawDraft == null || rawDraft.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map) {
        throw const FormatException('Draft payload must be a JSON object.');
      }
      final draft = Map<String, dynamic>.from(decoded);

      final schemaVersion = draft['schemaVersion'];
      if (schemaVersion != _draftSchemaVersion) {
        debugPrint(
          'Unsupported active workout draft schema: $schemaVersion. Clearing draft.',
        );
        await _clearDraft();
        return;
      }

      final startTimeRaw = draft['startTime'] as String?;
      final logsRaw = draft['currentExerciseLogs'];
      if (startTimeRaw == null || logsRaw is! List) {
        throw const FormatException('Draft is missing required fields.');
      }

      final restoredLogs = logsRaw
          .map(
            (log) =>
                ExerciseLog.fromJson(Map<String, dynamic>.from(log as Map)),
          )
          .toList();

      final programDayRaw = draft['programDay'];
      ProgramDay? restoredProgramDay;
      if (programDayRaw is Map) {
        restoredProgramDay = ProgramDay.fromJson(
          Map<String, dynamic>.from(programDayRaw),
        );
      }

      final programWeekRaw = draft['programWeek'];
      ProgramWeek? restoredProgramWeek;
      if (programWeekRaw is Map) {
        restoredProgramWeek = ProgramWeek.fromJson(
          Map<String, dynamic>.from(programWeekRaw),
        );
      }

      final routineId = draft['routineId'] as String?;
      Routine? restoredRoutine;
      if (routineId != null) {
        try {
          restoredRoutine = _routines.firstWhere((r) => r.id == routineId);
        } catch (_) {
          restoredRoutine = null;
        }
      }

      final indexFromDraft =
          (draft['currentExerciseIndex'] as num?)?.toInt() ?? 0;
      final maxIndex = restoredLogs.isEmpty ? 0 : restoredLogs.length - 1;

      _draftRestoreInProgress = true;
      _activeSession = null;
      _workoutStartTime = DateTime.parse(startTimeRaw);
      _activeRoutine = restoredRoutine;
      _activeProgramDay = restoredProgramDay;
      _activeProgramWeek = restoredProgramWeek;
      _currentExerciseLogs = restoredLogs;
      _currentExerciseIndex = indexFromDraft.clamp(0, maxIndex).toInt();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to restore active workout draft: $e');
      await _clearDraft();
    } finally {
      _draftRestoreInProgress = false;
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

    // Build a set of referenced exercise IDs in a single pass over
    // sessions, routines, targets, and the active workout.
    final referencedIds = <String>{};
    final referenceReasons = <String, Set<String>>{};

    void addReference(String id, String reason) {
      referencedIds.add(id);
      referenceReasons.putIfAbsent(id, () => {}).add(reason);
    }

    for (final s in _sessions) {
      for (final e in s.exercises) {
        addReference(e.exerciseId, '_sessions');
      }
    }
    for (final r in _routines) {
      for (final id in r.exerciseIds) {
        addReference(id, '_routines');
      }
    }
    for (final t in _targets) {
      addReference(t.exerciseId, '_targets');
    }
    for (final l in _currentExerciseLogs) {
      addReference(l.exerciseId, '_currentExerciseLogs');
    }
    if (_activeRoutine != null) {
      for (final id in _activeRoutine!.exerciseIds) {
        addReference(id, '_activeRoutine');
      }
    }

    if (referencedIds.contains(exerciseId)) {
      final reasons = referenceReasons[exerciseId]?.join(', ') ?? 'unknown';
      debugPrint(
        'Cannot delete custom exercise $exerciseId: still referenced in $reasons',
      );
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
  void startWorkout({
    Routine? routine,
    List<String>? exerciseIds,
    ProgramDay? programDay,
    ProgramWeek? programWeek,
  }) {
    if (hasActiveWorkout) {
      throw WorkoutInProgressError();
    }

    _workoutStartTime = DateTime.now();
    _activeRoutine = routine;
    _activeProgramDay = programDay;
    _activeProgramWeek = programWeek;
    _currentExerciseIndex = 0;
    _currentExerciseLogs = [];

    // Initialize exercise logs based on routine or provided exercise IDs
    final ids = routine?.exerciseIds ?? exerciseIds ?? [];
    for (var id in ids) {
      _currentExerciseLogs.add(ExerciseLog(exerciseId: id, sets: []));
    }

    notifyListeners();
    unawaited(_persistDraft());
  }

  Future<bool> startWorkoutSafely({
    Routine? routine,
    List<String>? exerciseIds,
    ProgramDay? programDay,
    ProgramWeek? programWeek,
    required Future<StartWorkoutConflictAction> Function() onConflict,
  }) async {
    if (!hasActiveWorkout) {
      startWorkout(
        routine: routine,
        exerciseIds: exerciseIds,
        programDay: programDay,
        programWeek: programWeek,
      );
      return true;
    }

    final action = await onConflict();
    if (action == StartWorkoutConflictAction.discardAndStart) {
      await cancelWorkout();
      startWorkout(
        routine: routine,
        exerciseIds: exerciseIds,
        programDay: programDay,
        programWeek: programWeek,
      );
      return true;
    }

    return false;
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
      unawaited(_persistDraft());
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
        unawaited(_persistDraft());
      }
    }
  }

  /// Move to next exercise
  bool nextExercise() {
    if (_currentExerciseIndex < _currentExerciseLogs.length - 1) {
      _currentExerciseIndex++;
      notifyListeners();
      unawaited(_persistDraft());
      return true;
    }
    return false; // No more exercises
  }

  /// Move to previous exercise
  bool previousExercise() {
    if (_currentExerciseIndex > 0) {
      _currentExerciseIndex--;
      notifyListeners();
      unawaited(_persistDraft());
      return true;
    }
    return false;
  }

  /// Jump directly to an exercise by index
  void goToExercise(int index) {
    if (index >= 0 &&
        index < _currentExerciseLogs.length &&
        index != _currentExerciseIndex) {
      _currentExerciseIndex = index;
      notifyListeners();
      unawaited(_persistDraft());
    }
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
    await _clearDraft();
    _sessions.insert(0, session);

    // Fire-and-forget Health Connect sync if enabled
    final hcEnabled = await _storage.getSetting('healthConnectEnabled');
    if (hcEnabled == 'true' && _healthConnect != null) {
      _healthConnect.syncWorkoutSession(
        session,
        title: _activeRoutine?.name,
      ).catchError((e) {
        debugPrint('Health Connect sync error: $e');
        return false;
      });
    }

    // Update growth models for performed exercises
    for (var log in completedExercises) {
      await _updateGrowthModel(log.exerciseId);
    }

    // Update targets
    await _updateTargetsFromSession(session);

    // Clear active workout state
    _activeSession = null;
    _activeRoutine = null;
    _activeProgramDay = null;
    _activeProgramWeek = null;
    _currentExerciseIndex = 0;
    _currentExerciseLogs = [];
    _workoutStartTime = null;

    notifyListeners();
    return session;
  }

  /// Cancel workout without saving
  Future<void> cancelWorkout() async {
    _activeSession = null;
    _activeRoutine = null;
    _activeProgramDay = null;
    _activeProgramWeek = null;
    _currentExerciseIndex = 0;
    _currentExerciseLogs = [];
    _workoutStartTime = null;
    notifyListeners();
    await _clearDraft();
  }

  // ==================== RECOMMENDATIONS ====================

  /// Get set recommendations for an exercise.
  ///
  /// Uses the most-recently-dated session that contains this exercise as the
  /// basis for the recommendation. Order in `_sessions` is not assumed.
  List<SetRecommendation> getRecommendations(String exerciseId) {
    final lastLog = findMostRecentExerciseLog(exerciseId, _sessions);

    if (lastLog == null || lastLog.sets.isEmpty) {
      return _mlService.getDefaultRecommendations(3);
    }

    return _mlService.recommendSets(
      lastSession: lastLog.sets,
      growthModel: _growthModels[exerciseId],
    );
  }

  /// Get the most recent exercise log for [exerciseId], or null if never logged.
  ExerciseLog? getLastSessionForExercise(String exerciseId) {
    return findMostRecentExerciseLog(exerciseId, _sessions);
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

  /// Get weekly volume by muscle group.
  ///
  /// Sessions are traversed newest-first and the loop breaks once we reach
  /// a session older than 7 days, so only in-range sessions are visited.
  /// An exercise map is built once at the top for O(1) per-set lookup.
  Map<String, double> getWeeklyVolumeByMuscle() {
    final volumeByMuscle = <String, double>{};
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    // Pre-build exercise map for O(1) lookup
    final exerciseMap = <String, Exercise>{
      for (final e in _allExercises) e.id: e,
    };

    // Iterate directly since _sessions is maintained newest-first.
    // We use continue rather than break in case of external imports
    // that might temporarily violate the newest-first invariant.
    for (final session in _sessions) {
      if (session.date.isBefore(weekAgo)) continue;

      for (final log in session.exercises) {
        final exercise = exerciseMap[log.exerciseId];
        if (exercise == null) continue;

        for (final activation in exercise.muscleActivations) {
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

  /// Estimate 1RM using Epley formula: weight × (1 + reps / 30).
  static double estimateOneRM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  /// Get the best estimated 1RM across all logged sets for an exercise.
  /// Returns null if no sessions exist for the exercise.
  double? getBestOneRM(String exerciseId) {
    double? best;
    for (final session in _sessions) {
      for (final log in session.exercises) {
        if (log.exerciseId != exerciseId) continue;
        for (final set in log.sets) {
          final orm = estimateOneRM(set.weight, set.reps);
          if (best == null || orm > best) best = orm;
        }
      }
    }
    return best;
  }

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
