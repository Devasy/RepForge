// Shared Mock Storage Service for testing
//
// This mock implements the IStorageService interface for testing.
// Following Dependency Inversion Principle: tests can inject this mock
// instead of the real StorageService.

import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/interfaces/storage_service_interface.dart';

/// Mock implementation of IStorageService for testing.
///
/// Following Liskov Substitution Principle: this mock can be used
/// wherever IStorageService is expected without breaking the tests.
class MockStorageService implements IStorageService {
  final List<Exercise> _customExercises = [];
  final List<WorkoutSession> _sessions = [];
  final List<Routine> _routines = [];
  final List<Target> _targets = [];
  final List<MuscleGroup> _muscleGroups = [];
  final Map<String, String> _settings = {};
  final List<TrainingProgram> _trainingPrograms = [];

  bool saveCustomExerciseCalled = false;
  Exercise? lastSavedExercise;
  int saveSettingCallCount = 0;
  Duration saveSettingDelay = Duration.zero;
  Duration Function(String key, String value)? saveSettingDelayResolver;

  // Public getters for test assertions
  List<Exercise> get customExercises => _customExercises;
  List<WorkoutSession> get sessions => _sessions;
  List<Routine> get routines => _routines;
  List<Target> get targets => _targets;
  Map<String, String> get settings => _settings;

  // Test helpers
  void addMockCustomExercise(Exercise exercise) {
    _customExercises.add(exercise);
  }

  void addMockSession(WorkoutSession session) {
    _sessions.add(session);
  }

  void addMockRoutine(Routine routine) {
    _routines.add(routine);
  }

  void addMockTarget(Target target) {
    _targets.add(target);
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<Exercise>> getAllExercises() async {
    // Merge built-in exercises with custom exercises to mirror production behavior
    final builtInExercises = ExerciseDatabase.getAll();
    return [...builtInExercises, ..._customExercises];
  }

  @override
  Future<List<Exercise>> getCustomExercises() async =>
      List.from(_customExercises);

  @override
  Future<void> saveCustomExercise(Exercise exercise) async {
    saveCustomExerciseCalled = true;
    lastSavedExercise = exercise;
    _customExercises.add(exercise);
  }

  @override
  Future<void> deleteCustomExercise(String id) async {
    _customExercises.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<WorkoutSession>> getAllWorkoutSessions() async =>
      List.from(_sessions);

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.add(session);
    }
  }

  @override
  Future<WorkoutSession?> getWorkoutSession(String id) async {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteWorkoutSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<WorkoutSession>> getSessionsForExercise(String exerciseId) async {
    return _sessions
        .where(
          (session) => session.exercises.any((e) => e.exerciseId == exerciseId),
        )
        .toList();
  }

  @override
  Future<List<WorkoutSession>> getSessionsInDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final lo = start.isAfter(end) ? end : start;
    final hi = start.isAfter(end) ? start : end;
    return _sessions
        .where(
          (session) => !session.date.isBefore(lo) && !session.date.isAfter(hi),
        )
        .toList();
  }

  @override
  Future<List<Routine>> getAllRoutines() async => List.from(_routines);

  @override
  Future<void> saveRoutine(Routine routine) async {
    final index = _routines.indexWhere((r) => r.id == routine.id);
    if (index >= 0) {
      _routines[index] = routine;
    } else {
      _routines.add(routine);
    }
  }

  @override
  Future<Routine?> getRoutine(String id) async {
    try {
      return _routines.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteRoutine(String id) async {
    _routines.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<Target>> getAllTargets() async => List.from(_targets);

  @override
  Future<void> saveTarget(Target target) async {
    final index = _targets.indexWhere((t) => t.id == target.id);
    if (index >= 0) {
      _targets[index] = target;
    } else {
      _targets.add(target);
    }
  }

  @override
  Future<Target?> getTarget(String id) async {
    try {
      return _targets.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteTarget(String id) async {
    _targets.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<Target>> getTargetsForExercise(String exerciseId) async {
    return _targets.where((t) => t.exerciseId == exerciseId).toList();
  }

  @override
  Future<List<MuscleGroup>> getAllMuscleGroups() async =>
      List.from(_muscleGroups);

  @override
  Future<void> updateMuscleGroupGrowthRate(
    String muscleGroupId,
    double rate,
  ) async {
    final index = _muscleGroups.indexWhere((m) => m.id == muscleGroupId);
    if (index >= 0) {
      _muscleGroups[index].growthRate = rate;
    }
  }

  @override
  Future<MuscleGroup?> getMuscleGroup(String id) async {
    try {
      return _muscleGroups.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Exercise?> getExercise(String id) async {
    // Check built-in exercises first, matching production behavior
    final builtIn = ExerciseDatabase.getById(id);
    if (builtIn != null) {
      return builtIn;
    }
    // Fall back to custom exercises
    final index = _customExercises.indexWhere((e) => e.id == id);
    return index != -1 ? _customExercises[index] : null;
  }

  @override
  Future<void> saveSetting(String key, String value) async {
    final delay =
        saveSettingDelayResolver?.call(key, value) ?? saveSettingDelay;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    saveSettingCallCount++;
    _settings[key] = value;
  }

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> saveTrainingProgram(TrainingProgram program) async {
    final index = _trainingPrograms.indexWhere((p) => p.id == program.id);
    if (index >= 0) {
      _trainingPrograms[index] = program;
    } else {
      _trainingPrograms.add(program);
    }
  }

  @override
  Future<List<TrainingProgram>> getAllTrainingPrograms() async =>
      List.from(_trainingPrograms);

  @override
  Future<TrainingProgram?> getTrainingProgram(String id) async {
    try {
      return _trainingPrograms.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteTrainingProgram(String id) async {
    _trainingPrograms.removeWhere((p) => p.id == id);
  }

  @override
  Future<String> exportAllData() async => '{}';

  @override
  Future<void> importData(String jsonData) async {}

  @override
  Future<Map<String, dynamic>> getQuickStats() async => {
    'totalWorkouts': _sessions.length,
    'weeklyWorkouts': 0,
    'weeklyVolume': 0.0,
    'exercisesThisWeek': 0,
  };
}
