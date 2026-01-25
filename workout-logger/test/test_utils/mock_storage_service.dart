// Shared Mock Storage Service for testing
import 'package:repforge/models/models.dart';
import 'package:repforge/services/storage_service.dart';

// Mock StorageService that works as a manual fake/stub
class MockStorageService implements StorageService {
  final List<Exercise> _customExercises = [];
  bool saveCustomExerciseCalled = false;
  Exercise? lastSavedExercise;

  // Public getter to access the hidden list in tests
  List<Exercise> get customExercises => _customExercises;

  void addMockCustomExercise(Exercise exercise) {
    _customExercises.add(exercise);
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<Exercise>> getAllExercises() async => _customExercises;

  @override
  Future<List<Exercise>> getCustomExercises() async => _customExercises;

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
  Future<List<WorkoutSession>> getAllWorkoutSessions() async => [];

  @override
  Future<List<Routine>> getAllRoutines() async => [];

  @override
  Future<List<MuscleGroup>> getAllMuscleGroups() async => [];

  @override
  Future<List<Target>> getAllTargets() async => [];

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {}
  @override
  Future<WorkoutSession?> getWorkoutSession(String id) async => null;
  @override
  Future<void> deleteWorkoutSession(String id) async {}
  @override
  Future<List<WorkoutSession>> getSessionsForExercise(
    String exerciseId,
  ) async => [];
  @override
  Future<List<WorkoutSession>> getSessionsInDateRange(
    DateTime start,
    DateTime end,
  ) async => [];
  @override
  Future<void> saveRoutine(Routine routine) async {}
  @override
  Future<Routine?> getRoutine(String id) async => null;
  @override
  Future<void> deleteRoutine(String id) async {}
  @override
  Future<void> saveTarget(Target target) async {}
  @override
  Future<Target?> getTarget(String id) async => null;
  @override
  Future<void> deleteTarget(String id) async {}
  @override
  Future<List<Target>> getTargetsForExercise(String exerciseId) async => [];
  @override
  Future<void> updateMuscleGroupGrowthRate(
    String muscleGroupId,
    double rate,
  ) async {}
  @override
  Future<MuscleGroup?> getMuscleGroup(String id) async => null;
  @override
  Future<Exercise?> getExercise(String id) async => null;
  @override
  Future<void> saveSetting(String key, String value) async {}
  @override
  Future<String?> getSetting(String key) async => null;
  @override
  Future<String> exportAllData() async => '{}';
  @override
  Future<void> importData(String jsonData) async {}
  @override
  Future<Map<String, dynamic>> getQuickStats() async => {};
}
