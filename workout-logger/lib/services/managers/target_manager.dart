// Target Manager (Single Responsibility Principle)
//
// This class is responsible ONLY for managing workout targets/goals.
// It handles:
// - Creating/updating/deleting targets
// - Tracking progress towards targets
// - Predicting target completion
//
// It uses the Strategy Pattern for calculating target values,
// following the Open/Closed Principle.

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';
import '../interfaces/ml_service_interface.dart';
import '../strategies/target_calculator.dart';

/// Manages workout targets and goals.
///
/// Following Single Responsibility Principle: this class only handles
/// target management, not workout execution or history.
///
/// Following Open/Closed Principle: uses TargetCalculatorStrategy for
/// calculating target values, allowing new target types to be added
/// without modifying this class.
class TargetManager extends ChangeNotifier {
  final IStorageService _storage;
  final IMLService _mlService;
  final Uuid _uuid = const Uuid();

  List<Target> _targets = [];

  // Growth models for prediction (keyed by exerciseId)
  final Map<String, GrowthModel> _growthModels = {};

  TargetManager(this._storage, this._mlService);

  // Getters
  List<Target> get targets => List.unmodifiable(_targets);
  int get totalTargets => _targets.length;
  List<Target> get activeTargets =>
      _targets.where((t) => !t.isCompleted).toList();
  List<Target> get completedTargets =>
      _targets.where((t) => t.isCompleted).toList();

  /// Load all targets from storage
  Future<void> loadTargets() async {
    _targets = await _storage.getAllTargets();
    notifyListeners();
  }

  /// Get targets for a specific exercise
  List<Target> getTargetsForExercise(String exerciseId) {
    return _targets.where((t) => t.exerciseId == exerciseId).toList();
  }

  /// Update growth model for an exercise
  void updateGrowthModel(String exerciseId, GrowthModel model) {
    _growthModels[exerciseId] = model;
  }

  /// Get growth model for an exercise
  GrowthModel? getGrowthModel(String exerciseId) => _growthModels[exerciseId];

  /// Create a new target
  Future<Target> createTarget({
    required String exerciseId,
    required String type,
    required double targetValue,
    required List<WorkoutSession> sessions,
  }) async {
    // Calculate current value using strategy pattern
    final currentValue = TargetCalculatorFactory.calculateCurrentValue(
      exerciseId,
      type,
      sessions,
    );

    // Predict completion date using growth model
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

    return target;
  }

  /// Recalculate targets for affected exercises
  Future<void> recalculateTargets(
    Set<String> exerciseIds,
    List<WorkoutSession> sessions,
  ) async {
    for (var exerciseId in exerciseIds) {
      final relevantTargets = _targets
          .where((t) => t.exerciseId == exerciseId)
          .toList();

      for (var target in relevantTargets) {
        // Recalculate current value using strategy pattern
        final newValue = TargetCalculatorFactory.calculateCurrentValue(
          exerciseId,
          target.targetType,
          sessions,
        );

        target.currentValue = newValue;
        target.isCompleted = newValue >= target.targetValue;

        // Update prediction if not completed
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
    notifyListeners();
  }

  /// Delete a target
  Future<void> deleteTarget(String id) async {
    await _storage.deleteTarget(id);
    _targets.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Check if an exercise is used in any target
  bool isExerciseUsedInTargets(String exerciseId) {
    return _targets.any((t) => t.exerciseId == exerciseId);
  }
}
