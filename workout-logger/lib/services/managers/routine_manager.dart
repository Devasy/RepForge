// Routine Manager (Single Responsibility Principle)
//
// This class is responsible ONLY for managing workout routines.
// It handles:
// - Creating/updating/deleting routines
// - Loading routines from storage
//
// It does NOT handle workout execution or session history.

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';

/// Manages workout routines.
///
/// Following Single Responsibility Principle: this class only handles
/// routine management, not workout execution or history.
class RoutineManager extends ChangeNotifier {
  final IStorageService _storage;
  final Uuid _uuid = const Uuid();

  List<Routine> _routines = [];

  RoutineManager(this._storage);

  // Getters
  List<Routine> get routines => List.unmodifiable(_routines);
  int get totalRoutines => _routines.length;

  /// Load all routines from storage
  Future<void> loadRoutines() async {
    _routines = await _storage.getAllRoutines();
    notifyListeners();
  }

  /// Get a routine by ID
  Routine? getRoutine(String id) {
    final index = _routines.indexWhere((r) => r.id == id);
    return index != -1 ? _routines[index] : null;
  }

  /// Create a new routine
  Future<Routine> createRoutine(String name, List<String> exerciseIds) async {
    final routine = Routine(
      id: _uuid.v4(),
      name: name,
      exerciseIds: exerciseIds,
    );
    await _storage.saveRoutine(routine);
    _routines.add(routine);
    notifyListeners();
    return routine;
  }

  /// Update an existing routine
  ///
  /// If the routine is not found in memory, it will be added.
  Future<void> updateRoutine(Routine routine) async {
    await _storage.saveRoutine(routine);
    final index = _routines.indexWhere((r) => r.id == routine.id);
    if (index != -1) {
      _routines[index] = routine;
    } else {
      _routines.add(routine);
    }
    notifyListeners();
  }

  /// Delete a routine
  Future<void> deleteRoutine(String id) async {
    await _storage.deleteRoutine(id);
    _routines.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// Check if an exercise is used in any routine
  bool isExerciseUsedInRoutines(String exerciseId) {
    return _routines.any((r) => r.exerciseIds.contains(exerciseId));
  }

  /// Get all routines containing a specific exercise
  List<Routine> getRoutinesWithExercise(String exerciseId) {
    return _routines.where((r) => r.exerciseIds.contains(exerciseId)).toList();
  }
}
