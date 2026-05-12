// Abstract Storage Service Interface (Dependency Inversion Principle)
//
// This interface defines the contract for storage operations.
// High-level modules should depend on this abstraction, not concrete implementations.
// This allows swapping storage backends (Hive, SQL, Firebase, etc.) without modifying consumers.

import '../../models/models.dart';

/// Abstract interface for storage operations
///
/// Implements Interface Segregation Principle by being focused on storage concerns only.
/// Clients depend on this abstraction rather than concrete StorageService.
abstract class IStorageService {
  /// Initialize the storage backend
  Future<void> init();

  // ==================== WORKOUT SESSIONS ====================

  Future<void> saveWorkoutSession(WorkoutSession session);
  Future<List<WorkoutSession>> getAllWorkoutSessions();
  Future<WorkoutSession?> getWorkoutSession(String id);
  Future<void> deleteWorkoutSession(String id);
  Future<List<WorkoutSession>> getSessionsForExercise(String exerciseId);
  Future<List<WorkoutSession>> getSessionsInDateRange(
    DateTime start,
    DateTime end,
  );

  // ==================== ROUTINES ====================

  Future<void> saveRoutine(Routine routine);
  Future<List<Routine>> getAllRoutines();
  Future<Routine?> getRoutine(String id);
  Future<void> deleteRoutine(String id);

  // ==================== TARGETS ====================

  Future<void> saveTarget(Target target);
  Future<List<Target>> getAllTargets();
  Future<Target?> getTarget(String id);
  Future<void> deleteTarget(String id);
  Future<List<Target>> getTargetsForExercise(String exerciseId);

  // ==================== MUSCLE GROUPS ====================

  Future<void> updateMuscleGroupGrowthRate(String muscleGroupId, double rate);
  Future<List<MuscleGroup>> getAllMuscleGroups();
  Future<MuscleGroup?> getMuscleGroup(String id);

  // ==================== CUSTOM EXERCISES ====================

  Future<void> saveCustomExercise(Exercise exercise);
  Future<List<Exercise>> getCustomExercises();
  Future<void> deleteCustomExercise(String id);
  Future<List<Exercise>> getAllExercises();
  Future<Exercise?> getExercise(String id);

  // ==================== SETTINGS ====================

  Future<void> saveSetting(String key, String value);
  Future<String?> getSetting(String key);

  // ==================== TRAINING PROGRAMS ====================

  Future<void> saveTrainingProgram(TrainingProgram program);
  Future<List<TrainingProgram>> getAllTrainingPrograms();
  Future<TrainingProgram?> getTrainingProgram(String id);
  Future<void> deleteTrainingProgram(String id);

  // ==================== PERSONAL RECORDS ====================

  Future<void> savePersonalRecord(PersonalRecord record);
  Future<PersonalRecord?> getPersonalRecord(String exerciseId);
  Future<List<PersonalRecord>> getAllPersonalRecords();

  // ==================== EXPORT / IMPORT ====================

  Future<String> exportAllData();
  Future<void> importData(String jsonData);

  // ==================== STATS ====================

  Future<Map<String, dynamic>> getQuickStats();
}
