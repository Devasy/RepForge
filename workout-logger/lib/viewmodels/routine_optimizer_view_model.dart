// routine_optimizer_view_model.dart — ViewModel for AI-driven routine optimization.
//
// Builds performance context from WorkoutProvider, calls IAiService.generateOptimization,
// resolves AI-supplied exercise names to IDs, and applies accepted suggestions
// back to the routine via WorkoutProvider.updateRoutine.

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/interfaces/ai_service_interface.dart';
import '../services/workout_provider.dart';

enum OptimizerState { idle, loading, success, error }

class RoutineOptimizerViewModel extends ChangeNotifier {
  final IAiService _ai;
  final WorkoutProvider _wp;

  RoutineOptimizerViewModel({required IAiService ai, required WorkoutProvider wp})
      : _ai = ai,
        _wp = wp;

  OptimizerState _state = OptimizerState.idle;
  RoutineOptimizationResult? _result;
  String? _errorMessage;
  final Map<int, bool> _accepted = {};
  bool _applied = false;

  OptimizerState get state => _state;
  RoutineOptimizationResult? get result => _result;
  String? get errorMessage => _errorMessage;
  Map<int, bool> get accepted => Map.unmodifiable(_accepted);
  bool get applied => _applied;

  bool isSuggestionAccepted(int index) => _accepted[index] ?? true;

  void toggleSuggestion(int index) {
    _accepted[index] = !(_accepted[index] ?? true);
    notifyListeners();
  }

  Future<void> analyzeRoutine(Routine routine) async {
    _state = OptimizerState.loading;
    _result = null;
    _errorMessage = null;
    _applied = false;
    _accepted.clear();
    notifyListeners();

    try {
      final payload = _buildContext(routine);
      final result = await _ai.generateOptimization(contextPayload: payload);
      _resolveExerciseIds(result);
      _result = result;
      for (var i = 0; i < result.suggestions.length; i++) {
        _accepted[i] = true;
      }
      _state = OptimizerState.success;
    } catch (e) {
      _errorMessage = e.toString();
      _state = OptimizerState.error;
    }
    notifyListeners();
  }

  Future<void> applyAccepted(Routine routine) async {
    final res = _result;
    if (res == null) return;

    var ids = List<String>.from(routine.exerciseIds);

    for (var i = 0; i < res.suggestions.length; i++) {
      if (!(_accepted[i] ?? true)) continue;
      final s = res.suggestions[i];
      switch (s.type) {
        case SuggestionType.reorder:
          final reordered = s.reorderedExerciseIds;
          if (reordered != null && reordered.isNotEmpty) {
            ids = List<String>.from(reordered);
          }
        case SuggestionType.replace:
          final removeId = s.removeExerciseId;
          final addId = s.replaceWithId;
          if (removeId != null && addId != null) {
            final idx = ids.indexOf(removeId);
            if (idx != -1) {
              ids[idx] = addId;
            } else {
              ids.add(addId);
            }
          }
        case SuggestionType.add:
          final addId = s.addExerciseId;
          if (addId != null && !ids.contains(addId)) {
            ids.add(addId);
          }
      }
    }

    await _wp.updateRoutine(routine.copyWith(exerciseIds: ids));
    _applied = true;
    notifyListeners();
  }

  // ── Context builder ────────────────────────────────────────────────────────

  String _buildContext(Routine routine) {
    final buf = StringBuffer();

    buf.writeln('Routine: "${routine.name}"');
    buf.writeln('Exercises (in current order):');

    for (var i = 0; i < routine.exerciseIds.length; i++) {
      final id = routine.exerciseIds[i];
      final name = _wp.getExerciseName(id);
      final model = _wp.getGrowthModel(id);
      final sessions = _wp.getVolumeProgression(id).length;

      if (model != null) {
        final slope = model.slope >= 0
            ? '+${model.slope.toStringAsFixed(1)}'
            : model.slope.toStringAsFixed(1);
        buf.writeln(
          '  ${i + 1}. [id: $id] $name — slope: $slope kg/session, '
          'r²: ${model.r2.toStringAsFixed(2)}, sessions: $sessions',
        );
      } else {
        buf.writeln(
          '  ${i + 1}. [id: $id] $name — no data (0 sessions)',
        );
      }
    }

    buf.writeln();

    // Weekly muscle volume
    final weeklyVolume = _wp.getWeeklyVolumeByMuscle();
    if (weeklyVolume.isNotEmpty) {
      buf.writeln('Weekly muscle volume (last 7 days):');
      final sorted = weeklyVolume.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        final muscleName = _wp.getMuscleGroupName(e.key);
        buf.writeln('  $muscleName: ${e.value.toStringAsFixed(0)} kg');
      }

      // Detect muscles that appear in the exercise catalog but have zero weekly volume
      final coveredMuscles = weeklyVolume.keys.toSet();
      final allMusclesInCatalog = <String>{};
      for (final ex in _wp.allExercises) {
        for (final a in ex.muscleActivations) {
          allMusclesInCatalog.add(a.muscleGroupId);
        }
      }
      final missing = allMusclesInCatalog
          .difference(coveredMuscles)
          .map(_wp.getMuscleGroupName)
          .toSet();
      if (missing.isNotEmpty) {
        buf.writeln('Missing coverage (zero weekly volume): ${missing.join(', ')}');
      }
    } else {
      buf.writeln('Weekly muscle volume: no data for last 7 days.');
    }

    buf.writeln();

    // Available exercise catalogue grouped by primary muscle (first 60)
    buf.writeln('Available exercises for replace/add suggestions:');
    final grouped = <String, List<String>>{};
    for (final ex in _wp.allExercises.take(60)) {
      final muscle = _wp.getMuscleGroupName(
        ex.muscleActivations.isNotEmpty
            ? ex.muscleActivations.first.muscleGroupId
            : 'unknown',
      );
      grouped.putIfAbsent(muscle, () => []).add(ex.name);
    }
    for (final entry in grouped.entries) {
      buf.writeln('  [${entry.key}] ${entry.value.join(', ')}');
    }

    return buf.toString();
  }

  // ── Exercise name resolution ───────────────────────────────────────────────

  void _resolveExerciseIds(RoutineOptimizationResult result) {
    for (final s in result.suggestions) {
      if (s.type == SuggestionType.replace && s.replaceWithName != null) {
        s.replaceWithId = _findExerciseId(s.replaceWithName!);
      }
      if (s.type == SuggestionType.add && s.addExerciseName != null) {
        s.addExerciseId = _findExerciseId(s.addExerciseName!);
      }
    }
  }

  String? _findExerciseId(String name) {
    final lower = name.toLowerCase();
    // Exact match first
    for (final ex in _wp.allExercises) {
      if (ex.name.toLowerCase() == lower) return ex.id;
    }
    // Partial match
    for (final ex in _wp.allExercises) {
      if (ex.name.toLowerCase().contains(lower) ||
          lower.contains(ex.name.toLowerCase())) {
        return ex.id;
      }
    }
    return null;
  }
}
