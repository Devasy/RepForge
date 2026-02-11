// Storage Service - Hive-based local persistence
//
// This is a concrete implementation of IStorageService using Hive.
// Following Dependency Inversion Principle: high-level modules depend on
// the IStorageService abstraction, not this concrete class.

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import '../data/exercise_database.dart';
import 'interfaces/storage_service_interface.dart';

/// Hive-based implementation of the storage service.
///
/// This class implements IStorageService, allowing it to be swapped
/// for other storage backends (SQL, Firebase, etc.) without modifying
/// the consuming code.
class StorageService implements IStorageService {
  static const String _workoutSessionsBox = 'workout_sessions';
  static const String _routinesBox = 'routines';
  static const String _targetsBox = 'targets';
  static const String _muscleGroupsBox = 'muscle_groups';
  static const String _customExercisesBox = 'custom_exercises';
  static const String _settingsBox = 'settings';

  late Box<String> _sessionsBox;
  late Box<String> _routinesBoxInstance;
  late Box<String> _targetsBoxInstance;
  late Box<String> _muscleGroupsBoxInstance;
  late Box<String> _customExercisesBoxInstance;
  late Box<String> _settingsBoxInstance;

  bool _initialized = false;

  /// Initialize Hive and open boxes
  @override
  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    _sessionsBox = await Hive.openBox<String>(_workoutSessionsBox);
    _routinesBoxInstance = await Hive.openBox<String>(_routinesBox);
    _targetsBoxInstance = await Hive.openBox<String>(_targetsBox);
    _muscleGroupsBoxInstance = await Hive.openBox<String>(_muscleGroupsBox);
    _customExercisesBoxInstance = await Hive.openBox<String>(
      _customExercisesBox,
    );
    _settingsBoxInstance = await Hive.openBox<String>(_settingsBox);

    // Initialize default muscle groups if empty
    if (_muscleGroupsBoxInstance.isEmpty) {
      await _initializeDefaultMuscleGroups();
    }

    _initialized = true;
  }

  Future<void> _initializeDefaultMuscleGroups() async {
    final muscleGroups = MuscleGroups.getAll();
    for (var mg in muscleGroups) {
      await _muscleGroupsBoxInstance.put(mg.id, jsonEncode(mg.toJson()));
    }
  }

  // ==================== WORKOUT SESSIONS ====================

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {
    await _sessionsBox.put(session.id, jsonEncode(session.toJson()));
  }

  @override
  Future<List<WorkoutSession>> getAllWorkoutSessions() async {
    final sessions = <WorkoutSession>[];
    for (var json in _sessionsBox.values) {
      sessions.add(WorkoutSession.fromJson(jsonDecode(json)));
    }
    sessions.sort((a, b) => b.date.compareTo(a.date)); // Most recent first
    return sessions;
  }

  @override
  Future<WorkoutSession?> getWorkoutSession(String id) async {
    final json = _sessionsBox.get(id);
    if (json == null) return null;
    return WorkoutSession.fromJson(jsonDecode(json));
  }

  @override
  Future<void> deleteWorkoutSession(String id) async {
    await _sessionsBox.delete(id);
  }

  @override
  Future<List<WorkoutSession>> getSessionsForExercise(String exerciseId) async {
    final allSessions = await getAllWorkoutSessions();
    return allSessions
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
    final allSessions = await getAllWorkoutSessions();
    return allSessions
        .where(
          (session) =>
              !session.date.isBefore(start) && !session.date.isAfter(end),
        )
        .toList();
  }

  // ==================== ROUTINES ====================

  @override
  Future<void> saveRoutine(Routine routine) async {
    await _routinesBoxInstance.put(routine.id, jsonEncode(routine.toJson()));
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    final routines = <Routine>[];
    for (var json in _routinesBoxInstance.values) {
      routines.add(Routine.fromJson(jsonDecode(json)));
    }
    return routines;
  }

  @override
  Future<Routine?> getRoutine(String id) async {
    final json = _routinesBoxInstance.get(id);
    if (json == null) return null;
    return Routine.fromJson(jsonDecode(json));
  }

  @override
  Future<void> deleteRoutine(String id) async {
    await _routinesBoxInstance.delete(id);
  }

  // ==================== TARGETS ====================

  @override
  Future<void> saveTarget(Target target) async {
    await _targetsBoxInstance.put(target.id, jsonEncode(target.toJson()));
  }

  @override
  Future<List<Target>> getAllTargets() async {
    final targets = <Target>[];
    for (var json in _targetsBoxInstance.values) {
      targets.add(Target.fromJson(jsonDecode(json)));
    }
    return targets;
  }

  @override
  Future<Target?> getTarget(String id) async {
    final json = _targetsBoxInstance.get(id);
    if (json == null) return null;
    return Target.fromJson(jsonDecode(json));
  }

  @override
  Future<void> deleteTarget(String id) async {
    await _targetsBoxInstance.delete(id);
  }

  @override
  Future<List<Target>> getTargetsForExercise(String exerciseId) async {
    final allTargets = await getAllTargets();
    return allTargets.where((t) => t.exerciseId == exerciseId).toList();
  }

  // ==================== MUSCLE GROUPS ====================

  @override
  Future<void> updateMuscleGroupGrowthRate(
    String muscleGroupId,
    double rate,
  ) async {
    final json = _muscleGroupsBoxInstance.get(muscleGroupId);
    if (json != null) {
      final mg = MuscleGroup.fromJson(jsonDecode(json));
      mg.growthRate = rate;
      mg.lastUpdated = DateTime.now();
      await _muscleGroupsBoxInstance.put(
        muscleGroupId,
        jsonEncode(mg.toJson()),
      );
    }
  }

  @override
  Future<List<MuscleGroup>> getAllMuscleGroups() async {
    final groups = <MuscleGroup>[];
    for (var json in _muscleGroupsBoxInstance.values) {
      groups.add(MuscleGroup.fromJson(jsonDecode(json)));
    }
    return groups;
  }

  @override
  Future<MuscleGroup?> getMuscleGroup(String id) async {
    final json = _muscleGroupsBoxInstance.get(id);
    if (json == null) return null;
    return MuscleGroup.fromJson(jsonDecode(json));
  }

  // ==================== CUSTOM EXERCISES ====================

  @override
  Future<void> saveCustomExercise(Exercise exercise) async {
    await _customExercisesBoxInstance.put(
      exercise.id,
      jsonEncode(exercise.toJson()),
    );
  }

  @override
  Future<List<Exercise>> getCustomExercises() async {
    final exercises = <Exercise>[];
    for (var json in _customExercisesBoxInstance.values) {
      exercises.add(Exercise.fromJson(jsonDecode(json)));
    }
    return exercises;
  }

  @override
  Future<void> deleteCustomExercise(String id) async {
    await _customExercisesBoxInstance.delete(id);
  }

  /// Get all exercises (built-in + custom)
  @override
  Future<List<Exercise>> getAllExercises() async {
    final builtIn = ExerciseDatabase.getAll();
    final custom = await getCustomExercises();
    return [...builtIn, ...custom];
  }

  /// Get exercise by ID (built-in or custom)
  @override
  Future<Exercise?> getExercise(String id) async {
    // Check built-in first
    final builtIn = ExerciseDatabase.getById(id);
    if (builtIn != null) return builtIn;

    // Check custom
    final json = _customExercisesBoxInstance.get(id);
    if (json != null) {
      return Exercise.fromJson(jsonDecode(json));
    }

    return null;
  }

  // ==================== SETTINGS ====================

  @override
  Future<void> saveSetting(String key, String value) async {
    await _settingsBoxInstance.put(key, value);
  }

  @override
  Future<String?> getSetting(String key) async {
    return _settingsBoxInstance.get(key);
  }

  // ==================== EXPORT / IMPORT ====================

  @override
  Future<String> exportAllData() async {
    final data = {
      'sessions': _sessionsBox.values.toList(),
      'routines': _routinesBoxInstance.values.toList(),
      'targets': _targetsBoxInstance.values.toList(),
      'muscleGroups': _muscleGroupsBoxInstance.values.toList(),
      'customExercises': _customExercisesBoxInstance.values.toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  @override
  Future<void> importData(String jsonData) async {
    final data = jsonDecode(jsonData) as Map<String, dynamic>;

    // Import sessions
    if (data['sessions'] != null) {
      for (var json in data['sessions']) {
        final session = WorkoutSession.fromJson(jsonDecode(json));
        await saveWorkoutSession(session);
      }
    }

    // Import routines
    if (data['routines'] != null) {
      for (var json in data['routines']) {
        final routine = Routine.fromJson(jsonDecode(json));
        await saveRoutine(routine);
      }
    }

    // Import targets
    if (data['targets'] != null) {
      for (var json in data['targets']) {
        final target = Target.fromJson(jsonDecode(json));
        await saveTarget(target);
      }
    }
  }

  // ==================== STATS ====================

  @override
  Future<Map<String, dynamic>> getQuickStats() async {
    final sessions = await getAllWorkoutSessions();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final weekSessions = sessions
        .where((s) => s.date.isAfter(weekAgo))
        .toList();

    double weeklyVolume = 0;
    int exercisesCompleted = 0;

    for (var session in weekSessions) {
      weeklyVolume += session.totalVolume;
      exercisesCompleted += session.exercises.length;
    }

    return {
      'totalWorkouts': sessions.length,
      'weeklyWorkouts': weekSessions.length,
      'weeklyVolume': weeklyVolume,
      'exercisesThisWeek': exercisesCompleted,
    };
  }
}
