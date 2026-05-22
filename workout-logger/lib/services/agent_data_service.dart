// Agent Data Service
//
// Read façade that exposes RepForge's workout data to the on-device AI agent
// (OS Gemini via Android AppFunctions). Every method returns plain
// JSON-encodable maps/lists so a result can be serialized straight into an
// AppFunction response or into the agent mirror file consumed by the native
// AppFunction handlers.
//
// All query logic is built on WorkoutProvider's public surface — the single
// source of truth that is wired into the app's composition root.

import '../data/exercise_database.dart';
import '../models/models.dart';
import 'ml_service.dart';
import 'workout_provider.dart';

/// Exposes workout data to the OS AI agent as JSON-encodable structures.
class AgentDataService {
  final WorkoutProvider _wp;

  AgentDataService(this._wp);

  // ── name resolution ────────────────────────────────────────────────────────

  /// Resolve a free-text exercise reference to an [Exercise].
  ///
  /// The agent speaks in names, not UUIDs. Tries exact id, then exact
  /// (case-insensitive) name, then a substring match.
  Exercise? resolveExercise(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final all = _wp.allExercises;
    for (final e in all) {
      if (e.id.toLowerCase() == q) return e;
    }
    for (final e in all) {
      if (e.name.toLowerCase() == q) return e;
    }
    for (final e in all) {
      if (e.name.toLowerCase().contains(q)) return e;
    }
    return null;
  }

  /// Resolve a free-text muscle reference to a muscle group id.
  String? resolveMuscleGroup(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final names = MuscleGroups.names; // id -> display name
    for (final id in names.keys) {
      if (id.toLowerCase() == q) return id;
    }
    for (final entry in names.entries) {
      if (entry.value.toLowerCase() == q) return entry.key;
    }
    for (final entry in names.entries) {
      if (entry.value.toLowerCase().contains(q) ||
          entry.key.toLowerCase().contains(q)) {
        return entry.key;
      }
    }
    return null;
  }

  // ── 1. exercise history ────────────────────────────────────────────────────

  /// Workout history for one exercise — the most recent [limit] sessions.
  Map<String, dynamic> getExerciseHistory(
    String exerciseQuery, {
    int limit = 15,
  }) {
    final exercise = resolveExercise(exerciseQuery);
    if (exercise == null) {
      return _notFound('exercise', exerciseQuery);
    }
    final sessions = _sessionsForExercise(exercise.id).take(limit).toList();
    return {
      'exerciseId': exercise.id,
      'exerciseName': exercise.name,
      'sessionCount': sessions.length,
      'sessions': [
        for (final s in sessions) _sessionJson(s, onlyExerciseId: exercise.id),
      ],
    };
  }

  // ── 2. muscle group sessions ───────────────────────────────────────────────

  /// The most recent [limit] sessions that trained a given muscle group.
  Map<String, dynamic> getMuscleGroupSessions(
    String muscleQuery, {
    int limit = 15,
  }) {
    final muscleId = resolveMuscleGroup(muscleQuery);
    if (muscleId == null) {
      return _notFound('muscle group', muscleQuery);
    }
    final sessions = _sessionsForMuscleGroup(muscleId).take(limit).toList();
    return {
      'muscleGroupId': muscleId,
      'muscleGroupName': _muscleName(muscleId),
      'sessionCount': sessions.length,
      'sessions': [
        for (final s in sessions) _sessionJson(s, onlyMuscleId: muscleId),
      ],
    };
  }

  // ── 3. recovery rate ───────────────────────────────────────────────────────

  /// Per-muscle recovery status. Pass [muscleQuery] to scope to one muscle.
  Map<String, dynamic> getMuscleRecovery({String? muscleQuery}) {
    final scores = _wp.getMuscleRecoveryScores();
    if (muscleQuery != null && muscleQuery.trim().isNotEmpty) {
      final muscleId = resolveMuscleGroup(muscleQuery);
      if (muscleId == null) return _notFound('muscle group', muscleQuery);
      final status = scores[muscleId];
      if (status == null) {
        return {
          'muscleGroupId': muscleId,
          'muscleGroupName': _muscleName(muscleId),
          'trained': false,
          'message': 'No recorded sessions train this muscle yet.',
        };
      }
      return _recoveryJson(status);
    }
    return {
      'muscles': [
        for (final status in scores.values) _recoveryJson(status),
      ],
    };
  }

  // ── 4. sessions this week ──────────────────────────────────────────────────

  /// Sessions logged in the current calendar week (Monday → now).
  Map<String, dynamic> getSessionsThisWeek() {
    final start = _weekStart();
    final sessions =
        _sortedSessions.where((s) => !s.date.isBefore(start)).toList();
    final totalVolume =
        sessions.fold<double>(0, (sum, s) => sum + s.totalVolume);
    return {
      'weekStart': start.toIso8601String(),
      'sessionCount': sessions.length,
      'totalVolume': _round(totalVolume),
      'sessions': [for (final s in sessions) _sessionJson(s)],
    };
  }

  // ── 5. muscle group progress ───────────────────────────────────────────────

  /// Volume trend for a muscle group: per-session effective volume (oldest
  /// first) plus the trained growth-model slope/fit.
  Map<String, dynamic> getMuscleGroupProgress(String muscleQuery) {
    final muscleId = resolveMuscleGroup(muscleQuery);
    if (muscleId == null) return _notFound('muscle group', muscleQuery);

    // Oldest-first effective volume per session that trains this muscle.
    final ordered = _sortedSessions.reversed
        .where((s) => _muscleVolume(s, muscleId) > 0)
        .toList();
    final points = [
      for (final s in ordered)
        {
          'date': s.date.toIso8601String(),
          'effectiveVolume': _round(_muscleVolume(s, muscleId)),
        },
    ];

    final model = _wp.getMuscleGrowthModels()[muscleId];
    return {
      'muscleGroupId': muscleId,
      'muscleGroupName': _muscleName(muscleId),
      'dataPointCount': points.length,
      'volumeBySession': points,
      'trend': model == null
          ? null
          : {
              'slopePerDay': _round(model.slope),
              'fitQualityR2': _round(model.r2),
              'direction': model.slope > 0
                  ? 'increasing'
                  : (model.slope < 0 ? 'decreasing' : 'flat'),
            },
    };
  }

  // ── 6. list exercises ──────────────────────────────────────────────────────

  /// All available exercises, optionally filtered by muscle group or category.
  Map<String, dynamic> listExercises({String? muscleQuery, String? category}) {
    String? muscleId;
    if (muscleQuery != null && muscleQuery.trim().isNotEmpty) {
      muscleId = resolveMuscleGroup(muscleQuery);
      if (muscleId == null) return _notFound('muscle group', muscleQuery);
    }
    final normalizedCategory = category?.toLowerCase().trim();

    final exercises = _wp.allExercises.where((e) {
      if (muscleId != null &&
          !e.muscleActivations.any((m) => m.muscleGroupId == muscleId)) {
        return false;
      }
      if (normalizedCategory != null &&
          normalizedCategory.isNotEmpty &&
          e.category.toLowerCase() != normalizedCategory) {
        return false;
      }
      return true;
    }).toList();

    return {
      'count': exercises.length,
      'exercises': [for (final e in exercises) _exerciseJson(e)],
    };
  }

  // ── 7. flexible session query ──────────────────────────────────────────────

  /// Ad-hoc session query for questions beyond the dedicated capabilities.
  ///
  /// All filters are optional and combined with AND. Results are newest-first.
  Map<String, dynamic> querySessions({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? exerciseQuery,
    String? muscleQuery,
    double? minVolume,
    int? limit,
  }) {
    String? exerciseId;
    if (exerciseQuery != null && exerciseQuery.trim().isNotEmpty) {
      final exercise = resolveExercise(exerciseQuery);
      if (exercise == null) return _notFound('exercise', exerciseQuery);
      exerciseId = exercise.id;
    }
    String? muscleId;
    if (muscleQuery != null && muscleQuery.trim().isNotEmpty) {
      muscleId = resolveMuscleGroup(muscleQuery);
      if (muscleId == null) return _notFound('muscle group', muscleQuery);
    }

    var sessions = _sortedSessions.where((s) {
      if (dateFrom != null && s.date.isBefore(dateFrom)) return false;
      if (dateTo != null && s.date.isAfter(dateTo)) return false;
      if (exerciseId != null &&
          !s.exercises.any((e) => e.exerciseId == exerciseId)) {
        return false;
      }
      if (muscleId != null && _muscleVolume(s, muscleId) <= 0) return false;
      if (minVolume != null && s.totalVolume < minVolume) return false;
      return true;
    }).toList();

    if (limit != null && limit > 0 && sessions.length > limit) {
      sessions = sessions.take(limit).toList();
    }

    return {
      'filters': {
        'dateFrom': dateFrom?.toIso8601String(),
        'dateTo': dateTo?.toIso8601String(),
        'exerciseId': exerciseId,
        'muscleGroupId': muscleId,
        'minVolume': minVolume,
        'limit': limit,
      },
      'sessionCount': sessions.length,
      'sessions': [
        for (final s in sessions)
          _sessionJson(s, onlyExerciseId: exerciseId, onlyMuscleId: muscleId),
      ],
    };
  }

  // ── mirror snapshot ────────────────────────────────────────────────────────

  /// Build the full denormalized snapshot written to the agent mirror file.
  ///
  /// The native AppFunction handlers read this to answer queries without a
  /// running Flutter engine. Recovery is stored as raw inputs (lastTrainedAt +
  /// τ) so the decay model can be recomputed fresh at query time.
  Map<String, dynamic> buildSnapshot() {
    final now = DateTime.now();
    final recovery = _wp.getMuscleRecoveryScores();
    final growthModels = _wp.getMuscleGrowthModels();

    return {
      'schemaVersion': 1,
      'generatedAt': now.toIso8601String(),
      'weightUnit': 'kg',
      'muscleGroups': [
        for (final entry in MuscleGroups.names.entries)
          {'id': entry.key, 'name': entry.value},
      ],
      'exercises': [for (final e in _wp.allExercises) _exerciseJson(e)],
      'routines': [
        for (final r in _wp.routines)
          {
            'id': r.id,
            'name': r.name,
            'exerciseIds': r.exerciseIds,
            'createdAt': r.createdAt.toIso8601String(),
          },
      ],
      'sessions': [
        for (final s in _sortedSessions) _sessionJson(s, includeSets: true),
      ],
      'recovery': [
        for (final entry in recovery.entries)
          {
            'muscleGroupId': entry.key,
            'muscleGroupName': _muscleName(entry.key),
            'lastTrainedAt': now
                .subtract(entry.value.timeSinceLastTrained)
                .toIso8601String(),
            'tauHours': MLService.recoveryTimeConstantsHours[entry.key] ??
                MLService.defaultRecoveryTimeConstantHours,
            'recoveryPercent': entry.value.recoveryPercent,
          },
      ],
      'muscleGrowth': {
        for (final entry in growthModels.entries)
          entry.key: {
            'slopePerDay': _round(entry.value.slope),
            'fitQualityR2': _round(entry.value.r2),
          },
      },
    };
  }

  // ── internals ──────────────────────────────────────────────────────────────

  /// Sessions newest-first. [WorkoutProvider.sessions] is only best-effort
  /// ordered, so order-sensitive queries sort defensively.
  List<WorkoutSession> get _sortedSessions {
    final list = List<WorkoutSession>.from(_wp.sessions);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<WorkoutSession> _sessionsForExercise(String exerciseId) =>
      _sortedSessions
          .where((s) => s.exercises.any((e) => e.exerciseId == exerciseId))
          .toList();

  List<WorkoutSession> _sessionsForMuscleGroup(String muscleId) =>
      _sortedSessions.where((s) => _trainsMuscle(s, muscleId)).toList();

  bool _trainsMuscle(WorkoutSession session, String muscleId) {
    for (final log in session.exercises) {
      final exercise = _wp.getExercise(log.exerciseId);
      if (exercise == null) continue;
      if (exercise.muscleActivations.any((m) => m.muscleGroupId == muscleId)) {
        return true;
      }
    }
    return false;
  }

  /// Effective volume a session contributes to one muscle group, weighted by
  /// each exercise's activation percentage.
  double _muscleVolume(WorkoutSession session, String muscleId) {
    var total = 0.0;
    for (final log in session.exercises) {
      final exercise = _wp.getExercise(log.exerciseId);
      if (exercise == null) continue;
      for (final activation in exercise.muscleActivations) {
        if (activation.muscleGroupId == muscleId) {
          total += log.totalVolume * activation.activationPercentage / 100.0;
        }
      }
    }
    return total;
  }

  Map<String, dynamic> _sessionJson(
    WorkoutSession session, {
    String? onlyExerciseId,
    String? onlyMuscleId,
    bool includeSets = false,
  }) {
    final logs = session.exercises.where((log) {
      if (onlyExerciseId != null && log.exerciseId != onlyExerciseId) {
        return false;
      }
      if (onlyMuscleId != null) {
        final exercise = _wp.getExercise(log.exerciseId);
        if (exercise == null) return false;
        if (!exercise.muscleActivations
            .any((m) => m.muscleGroupId == onlyMuscleId)) {
          return false;
        }
      }
      return true;
    });

    return {
      'id': session.id,
      'date': session.date.toIso8601String(),
      'durationMinutes': session.duration,
      'totalVolume': _round(session.totalVolume),
      'exercises': [
        for (final log in logs)
          {
            'exerciseId': log.exerciseId,
            'exerciseName': _wp.getExerciseName(log.exerciseId),
            'muscleGroupIds': [
              for (final m
                  in _wp.getExercise(log.exerciseId)?.muscleActivations ??
                      const <MuscleActivation>[])
                m.muscleGroupId,
            ],
            'setCount': log.sets.length,
            'totalVolume': _round(log.totalVolume),
            if (includeSets)
              'sets': [
                for (final set in log.sets)
                  {
                    'weight': set.weight,
                    'reps': set.reps,
                    'volume': _round(set.volume),
                    'isDropset': set.isDropset,
                  },
              ],
          },
      ],
    };
  }

  Map<String, dynamic> _exerciseJson(Exercise e) => {
        'id': e.id,
        'name': e.name,
        'category': e.category,
        'isCustom': e.isCustom,
        'primaryMuscle': e.primaryMuscle,
        'muscles': [
          for (final m in e.muscleActivations)
            {
              'id': m.muscleGroupId,
              'name': _muscleName(m.muscleGroupId),
              'activationPercentage': m.activationPercentage,
            },
        ],
      };

  Map<String, dynamic> _recoveryJson(MuscleRecoveryStatus status) => {
        'muscleGroupId': status.muscleGroupId,
        'muscleGroupName': _muscleName(status.muscleGroupId),
        'recoveryPercent': status.recoveryPercent,
        'hoursSinceLastTrained':
            _round(status.timeSinceLastTrained.inMinutes / 60.0),
        'estimatedHoursToFullRecovery': status.estimatedTimeToFullRecovery ==
                null
            ? 0
            : _round(status.estimatedTimeToFullRecovery!.inMinutes / 60.0),
        'state': status.isRecovered
            ? 'recovered'
            : (status.isUnderRecovered ? 'fatigued' : 'recovering'),
      };

  Map<String, dynamic> _notFound(String kind, String query) =>
      {'error': 'No $kind found matching "$query".'};

  String _muscleName(String muscleId) =>
      MuscleGroups.names[muscleId] ?? muscleId;

  /// Start of the current calendar week (Monday at 00:00 local time).
  DateTime _weekStart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  double _round(double value) => (value * 100).roundToDouble() / 100;
}
