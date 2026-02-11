// Exercise Manager (Single Responsibility Principle)
//
// This class is responsible ONLY for managing exercises (built-in and custom).
// It handles:
// - Loading exercises from storage and database
// - Adding/deleting custom exercises
// - Exercise lookups
//
// It does NOT handle workout sessions or analytics.

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/exercise_database.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';

/// Manages exercises (built-in and custom).
///
/// Following Single Responsibility Principle: this class only handles
/// exercise management, not workout execution or history.
class ExerciseManager extends ChangeNotifier {
  final IStorageService _storage;
  final Uuid _uuid = const Uuid();

  List<Exercise> _allExercises = [];

  /// Allowed category values for exercises
  static const Set<String> allowedCategories = {'compound', 'isolation'};

  ExerciseManager(this._storage);

  // Getters
  List<Exercise> get allExercises => List.unmodifiable(_allExercises);
  List<Exercise> get customExercises =>
      _allExercises.where((e) => e.isCustom).toList();
  List<Exercise> get builtInExercises =>
      _allExercises.where((e) => !e.isCustom).toList();

  /// Load all exercises from storage and database
  Future<void> loadExercises() async {
    _allExercises = await _storage.getAllExercises();
    notifyListeners();
  }

  /// Get an exercise by ID
  ///
  /// Returns null if not found. Caller should ensure loadExercises() has been
  /// called first to populate the in-memory exercise list.
  Exercise? getExercise(String id) {
    final index = _allExercises.indexWhere((e) => e.id == id);
    return index != -1 ? _allExercises[index] : null;
  }

  /// Get exercise name by ID
  String getExerciseName(String id) {
    return getExercise(id)?.name ?? 'Unknown Exercise';
  }

  /// Get muscle group name by ID
  String getMuscleGroupName(String id) {
    return MuscleGroups.names[id] ?? 'Unknown';
  }

  /// Add a custom exercise
  ///
  /// Throws [ArgumentError] if inputs are invalid.
  Future<Exercise> addCustomExercise({
    required String name,
    required String category,
    required String primaryMuscleGroupId,
  }) async {
    // Validate and normalize name
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
    if (!allowedCategories.contains(normalizedCategory)) {
      throw ArgumentError(
        'Invalid category "$category". Must be one of: ${allowedCategories.join(", ")}',
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

    final exercise = Exercise(
      id: id,
      name: normalizedName,
      muscleActivations: muscleActivations,
      category: normalizedCategory,
      isCustom: true,
    );

    await _storage.saveCustomExercise(exercise);
    _allExercises = List.from(_allExercises)..add(exercise);
    notifyListeners();

    return exercise;
  }

  /// Delete a custom exercise
  ///
  /// [canDelete] callback should check if the exercise is used elsewhere.
  /// Returns false if exercise not found, not custom, or canDelete returns false.
  Future<bool> deleteCustomExercise(
    String exerciseId, {
    bool Function(String exerciseId)? canDelete,
  }) async {
    final exercise = getExercise(exerciseId);
    if (exercise == null || !exercise.isCustom) {
      return false;
    }

    // Check if deletion is allowed
    if (canDelete != null && !canDelete(exerciseId)) {
      return false;
    }

    await _storage.deleteCustomExercise(exerciseId);
    _allExercises = List.from(_allExercises)
      ..removeWhere((e) => e.id == exerciseId);
    notifyListeners();

    return true;
  }

  /// Get exercises by muscle group
  List<Exercise> getExercisesByMuscleGroup(String muscleGroupId) {
    return _allExercises
        .where(
          (e) =>
              e.muscleActivations.any((m) => m.muscleGroupId == muscleGroupId),
        )
        .toList();
  }

  /// Get exercises by category
  ///
  /// Performs case-insensitive comparison to match both built-in and custom exercises.
  List<Exercise> getExercisesByCategory(String category) {
    final normalizedCategory = category.toLowerCase();
    return _allExercises
        .where((e) => e.category.toLowerCase() == normalizedCategory)
        .toList();
  }

  /// Search exercises by name
  List<Exercise> searchExercises(String query) {
    final lowerQuery = query.toLowerCase();
    return _allExercises
        .where((e) => e.name.toLowerCase().contains(lowerQuery))
        .toList();
  }
}
