// coach_tool_service.dart — DB-backed function-calling tools for the AI coach.
//
// Exposes a set of read-only query functions the model can call to ground its
// answers in the user's real data. Every tool reuses existing parameterized
// query methods on WorkoutProvider / PRManager — no new analytics logic lives
// here, only the schema + arg parsing + JSON shaping.

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../models/models.dart';
import '../workout_provider.dart';
import '../managers/pr_manager.dart';

class AmbiguousMatchException implements Exception {
  const AmbiguousMatchException(this.candidates);
  final List<String> candidates;
}

class CoachToolService {
  final WorkoutProvider _wp;
  final PRManager _pr;

  CoachToolService(this._wp, this._pr);

  /// Tool declaration for the optimizer screen's `ask_user_questions` flow.
  /// NOT included in the coach's tool list — only the optimizer adds it.
  static FunctionDeclaration get askUserQuestionsDeclaration =>
      FunctionDeclaration(
        'ask_user_questions',
        'Ask the user 1–3 clarifying questions before proceeding. '
            'Provide an optional preamble (short context sentence shown above the '
            'questions). Each question has 3–4 option chips; set multiSelect:true '
            'when the user should be able to pick multiple options. '
            'allowCustom is always treated as true.',
        Schema.object(
          properties: {
            'preamble': Schema.string(
              description:
                  'Optional. A short sentence shown above the questions, '
                  'e.g. "Before I analyse your routine, I have a few quick '
                  'questions."',
              nullable: true,
            ),
            'questions': Schema.array(
              items: Schema.object(
                properties: {
                  'question': Schema.string(
                    description: 'The question text, e.g. "What is your primary goal?"',
                  ),
                  'options': Schema.array(
                    items: Schema.string(),
                    description: '3–4 answer chips, e.g. ["Strength","Hypertrophy","Fat loss","Endurance"].',
                  ),
                  'multiSelect': Schema.boolean(
                    description:
                        'If true the user can select multiple chips. '
                        'Use for confirmation questions (e.g. "Which changes should I apply?").',
                    nullable: true,
                  ),
                },
                requiredProperties: ['question', 'options'],
              ),
              description: '1–3 questions to display.',
            ),
          },
          requiredProperties: ['questions'],
        ),
      );

  /// Tool declarations advertised to the model.
  List<Tool> buildTools() => [
        Tool(functionDeclarations: [
          FunctionDeclaration(
            'get_exercise_performance',
            'Get how a specific exercise has progressed: per-session volume '
                'trend, growth slope, best estimated 1RM, last logged sets, and '
                'personal record. Use for questions like "how is my bench press '
                'progressing".',
            Schema.object(
              properties: {
                'exercise_name': Schema.string(
                  description:
                      'Name of the exercise, e.g. "Bench Press" or "Squat".',
                ),
                'days': Schema.integer(
                  description:
                      'Optional. Only consider sessions from the last N days.',
                  nullable: true,
                ),
              },
              requiredProperties: ['exercise_name'],
            ),
          ),
          FunctionDeclaration(
            'get_workouts_in_range',
            'Summarize workouts in a date range: session count, total volume, '
                'and a per-session breakdown. Use for "what did I do last week" '
                'or "how many workouts in the last 3 months".',
            Schema.object(
              properties: {
                'start_date': Schema.string(
                  description: 'Optional ISO date (YYYY-MM-DD) range start.',
                  nullable: true,
                ),
                'end_date': Schema.string(
                  description: 'Optional ISO date (YYYY-MM-DD) range end.',
                  nullable: true,
                ),
                'days': Schema.integer(
                  description:
                      'Optional. Last N days; overrides start/end when set. '
                      'Defaults to 30 if no dates are provided.',
                  nullable: true,
                ),
              },
            ),
          ),
          FunctionDeclaration(
            'get_routine_performance',
            'Get how a named routine is performing: number of sessions logged '
                'against it, total volume, volume trend over time, and the '
                'exercises it contains.',
            Schema.object(
              properties: {
                'routine_name': Schema.string(
                  description: 'Name of the routine, e.g. "Push Day".',
                ),
                'days': Schema.integer(
                  description:
                      'Optional. Only consider sessions from the last N days.',
                  nullable: true,
                ),
              },
              requiredProperties: ['routine_name'],
            ),
          ),
          FunctionDeclaration(
            'get_personal_records',
            'Get personal records (best weight, reps, and single-set volume). '
                'Pass an exercise name for one exercise, or omit for all PRs.',
            Schema.object(
              properties: {
                'exercise_name': Schema.string(
                  description: 'Optional exercise name to filter to.',
                  nullable: true,
                ),
              },
            ),
          ),
          FunctionDeclaration(
            'get_goal_progress',
            'Get progress toward training goals/targets: current vs target '
                'value, percent complete, and estimated completion date.',
            Schema.object(
              properties: {
                'exercise_name': Schema.string(
                  description: 'Optional exercise name to filter goals to.',
                  nullable: true,
                ),
              },
            ),
          ),
          FunctionDeclaration(
            'get_muscle_recovery',
            'Get current per-muscle-group recovery status (percent recovered '
                'and whether each is ready, recovering, or fatigued). Use for '
                '"what can I train today".',
            Schema.object(properties: {}),
          ),
          FunctionDeclaration(
            'get_all_routines',
            'List all saved routines with their exercise names and count. '
                'Use when the user asks what routines they have or wants to '
                'pick one to view or modify.',
            Schema.object(properties: {}),
          ),
          FunctionDeclaration(
            'create_routine',
            'Create a new workout routine with a name and an ordered list of '
                'exercises. Exercises are matched by name from the catalogue.',
            Schema.object(
              properties: {
                'name': Schema.string(
                  description: 'Name for the new routine, e.g. "Push Day".',
                ),
                'exercise_names': Schema.array(
                  items: Schema.string(),
                  description:
                      'Ordered list of exercise names to include in the routine.',
                ),
              },
              requiredProperties: ['name', 'exercise_names'],
            ),
          ),
          FunctionDeclaration(
            'update_routine',
            'Modify an existing routine: add exercises, remove exercises, or '
                'reorder them. Specify the routine by name. Exercises are '
                'matched by name from the catalogue.',
            Schema.object(
              properties: {
                'routine_name': Schema.string(
                  description: 'Name of the routine to update.',
                ),
                'add_exercise_names': Schema.array(
                  items: Schema.string(),
                  description: 'Optional. Exercise names to add.',
                  nullable: true,
                ),
                'remove_exercise_names': Schema.array(
                  items: Schema.string(),
                  description: 'Optional. Exercise names to remove.',
                  nullable: true,
                ),
                'reorder_exercise_names': Schema.array(
                  items: Schema.string(),
                  description:
                      'Optional. Full new ordering of all exercise names in '
                      'the routine. Must include every exercise you want to keep.',
                  nullable: true,
                ),
              },
              requiredProperties: ['routine_name'],
            ),
          ),
        ]),
      ];

  /// Dispatch a model function call to the matching query and return a
  /// JSON-serializable result map.
  Future<Map<String, Object?>> handleCall(FunctionCall call) async {
    switch (call.name) {
      case 'get_exercise_performance':
        return _exercisePerformance(call.args);
      case 'get_workouts_in_range':
        return _workoutsInRange(call.args);
      case 'get_routine_performance':
        return _routinePerformance(call.args);
      case 'get_personal_records':
        return _personalRecords(call.args);
      case 'get_goal_progress':
        return _goalProgress(call.args);
      case 'get_muscle_recovery':
        return _muscleRecovery();
      case 'get_all_routines':
        return _getAllRoutines();
      case 'create_routine':
        return _createRoutine(call.args);
      case 'update_routine':
        return await _updateRoutine(call.args);
      default:
        return {'error': 'Unknown tool: ${call.name}'};
    }
  }

  // ── Tool implementations ───────────────────────────────────────────────────

  Map<String, Object?> _exercisePerformance(Map<String, Object?> args) {
    final name = (args['exercise_name'] as String?)?.trim() ?? '';
    final Exercise exercise;
    try {
      final resolved = _resolveExercise(name);
      if (resolved == null) {
        return {
          'error': 'No exercise found matching "$name".',
          'available_examples': _exampleExerciseNames(),
        };
      }
      exercise = resolved;
    } on AmbiguousMatchException catch (e) {
      return {
        'error': 'Multiple exercises match "$name". Did you mean one of:',
        'ambiguous_matches': e.candidates,
      };
    }

    final days = (args['days'] as num?)?.toInt();
    final cutoff =
        days != null ? DateTime.now().subtract(Duration(days: days)) : null;

    final progression = _wp
        .getVolumeProgression(exercise.id)
        .where((p) => cutoff == null || !p.date.isBefore(cutoff))
        .toList();

    final growth = _wp.getGrowthModel(exercise.id);
    final lastLog = _wp.getLastSessionForExercise(exercise.id);
    final pr = _pr.getRecord(exercise.id);

    return {
      'exercise': exercise.name,
      'session_count': progression.length,
      if (days != null) 'window_days': days,
      'volume_trend': [
        for (final p in progression.length > 40
            ? progression.sublist(progression.length - 40)
            : progression)
          {'date': _d(p.date), 'volume': _round(p.volume)},
      ],
      'growth': growth == null
          ? null
          : {
              'slope_per_session': _round(growth.slope),
              'r2': _round(growth.r2),
              'trend': growth.slope > 0
                  ? 'improving'
                  : growth.slope < 0
                      ? 'declining'
                      : 'flat',
            },
      'best_estimated_1rm': _roundOrNull(_wp.getBestOneRM(exercise.id)),
      'last_session': lastLog == null
          ? null
          : [
              for (final s in lastLog.sets)
                {'weight': _round(s.weight), 'reps': s.reps},
            ],
      'personal_record': pr == null
          ? null
          : {
              'best_weight': _round(pr.bestWeight),
              'best_reps': pr.bestReps,
              'best_volume': _round(pr.bestVolume),
              'achieved_at': _d(pr.achievedAt),
            },
    };
  }

  Map<String, Object?> _workoutsInRange(Map<String, Object?> args) {
    final now = DateTime.now();
    final days = (args['days'] as num?)?.toInt();
    final startArg = DateTime.tryParse((args['start_date'] as String?) ?? '');
    final endArg = DateTime.tryParse((args['end_date'] as String?) ?? '');

    final DateTime start;
    final DateTime end;
    if (days != null) {
      start = now.subtract(Duration(days: days));
      end = now;
    } else if (startArg != null || endArg != null) {
      start = startArg ?? now.subtract(const Duration(days: 30));
      end = endArg ?? now;
    } else {
      start = now.subtract(const Duration(days: 30));
      end = now;
    }

    final sessions = _wp.sessions
        .where((s) => !s.date.isBefore(start) && !s.date.isAfter(end))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final totalVolume =
        sessions.fold<double>(0, (sum, s) => sum + s.totalVolume);

    return {
      'start_date': _d(start),
      'end_date': _d(end),
      'session_count': sessions.length,
      'total_volume': _round(totalVolume),
      'sessions': [
        for (final s in sessions.take(40))
          {
            'date': _d(s.date),
            'duration_min': s.duration,
            'exercise_count': s.exercises.length,
            'volume': _round(s.totalVolume),
            'exercises': [
              for (final e in s.exercises) _wp.getExerciseName(e.exerciseId),
            ],
          },
      ],
    };
  }

  Map<String, Object?> _routinePerformance(Map<String, Object?> args) {
    final name = (args['routine_name'] as String?)?.trim() ?? '';
    final Routine routine;
    try {
      final resolved = _resolveRoutine(name);
      if (resolved == null) {
        return {
          'error': 'No routine found matching "$name".',
          'available_routines': [for (final r in _wp.routines) r.name],
        };
      }
      routine = resolved;
    } on AmbiguousMatchException catch (e) {
      return {
        'error': 'Multiple routines match "$name". Did you mean one of:',
        'ambiguous_matches': e.candidates,
      };
    }

    final days = (args['days'] as num?)?.toInt();
    final cutoff =
        days != null ? DateTime.now().subtract(Duration(days: days)) : null;

    final sessions = _wp.sessions
        .where((s) => s.routineId == routine.id)
        .where((s) => cutoff == null || !s.date.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalVolume =
        sessions.fold<double>(0, (sum, s) => sum + s.totalVolume);

    return {
      'routine': routine.name,
      'exercises': [for (final id in routine.exerciseIds) _wp.getExerciseName(id)],
      'session_count': sessions.length,
      if (days != null) 'window_days': days,
      'total_volume': _round(totalVolume),
      'volume_over_time': [
        for (final s in sessions.length > 40
            ? sessions.sublist(sessions.length - 40)
            : sessions)
          {'date': _d(s.date), 'volume': _round(s.totalVolume)},
      ],
    };
  }

  Map<String, Object?> _personalRecords(Map<String, Object?> args) {
    final name = (args['exercise_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) {
      final Exercise exercise;
      try {
        final resolved = _resolveExercise(name);
        if (resolved == null) {
          return {'error': 'No exercise found matching "$name".'};
        }
        exercise = resolved;
      } on AmbiguousMatchException catch (e) {
        return {
          'error': 'Multiple exercises match "$name". Did you mean one of:',
          'ambiguous_matches': e.candidates,
        };
      }
      final pr = _pr.getRecord(exercise.id);
      return {
        'exercise': exercise.name,
        'personal_record': pr == null
            ? null
            : {
                'best_weight': _round(pr.bestWeight),
                'best_reps': pr.bestReps,
                'best_volume': _round(pr.bestVolume),
                'achieved_at': _d(pr.achievedAt),
              },
      };
    }

    return {
      'records': [
        for (final pr in _pr.allRecords)
          {
            'exercise': _wp.getExerciseName(pr.exerciseId),
            'best_weight': _round(pr.bestWeight),
            'best_reps': pr.bestReps,
            'best_volume': _round(pr.bestVolume),
            'achieved_at': _d(pr.achievedAt),
          },
      ],
    };
  }

  Map<String, Object?> _goalProgress(Map<String, Object?> args) {
    final name = (args['exercise_name'] as String?)?.trim();
    Iterable<Target> targets = _wp.targets;
    if (name != null && name.isNotEmpty) {
      final Exercise exercise;
      try {
        final resolved = _resolveExercise(name);
        if (resolved == null) {
          return {'error': 'No exercise found matching "$name".'};
        }
        exercise = resolved;
      } on AmbiguousMatchException catch (e) {
        return {
          'error': 'Multiple exercises match "$name". Did you mean one of:',
          'ambiguous_matches': e.candidates,
        };
      }
      targets = targets.where((t) => t.exerciseId == exercise.id);
    }

    return {
      'goals': [
        for (final t in targets)
          {
            'exercise': _wp.getExerciseName(t.exerciseId),
            'type': t.targetType,
            'current_value': _round(t.currentValue),
            'target_value': _round(t.targetValue),
            'progress_percent': _round(t.progressPercentage),
            'completed': t.isCompleted,
            'estimated_completion': t.estimatedCompletionDate == null
                ? null
                : _d(t.estimatedCompletionDate!),
          },
      ],
    };
  }

  Map<String, Object?> _muscleRecovery() {
    final scores = _wp.getMuscleRecoveryScores();
    final entries = scores.entries.toList()
      ..sort((a, b) => a.value.recoveryPercent.compareTo(b.value.recoveryPercent));
    return {
      'muscles': [
        for (final e in entries)
          {
            'muscle': _wp.getMuscleGroupName(e.key),
            'recovery_percent': e.value.recoveryPercent,
            'status': e.value.isRecovered
                ? 'ready'
                : e.value.isUnderRecovered
                    ? 'fatigued'
                    : 'recovering',
          },
      ],
    };
  }

  // ── Routine CRUD tools ────────────────────────────────────────────────────

  Map<String, Object?> _getAllRoutines() {
    return {
      'routines': [
        for (final r in _wp.routines)
          {
            'id': r.id,
            'name': r.name,
            'exercise_count': r.exerciseIds.length,
            'exercises': [for (final id in r.exerciseIds) _wp.getExerciseName(id)],
          },
      ],
    };
  }

  Future<Map<String, Object?>> _createRoutine(Map<String, Object?> args) async {
    final name = ((args['name'] as String?)?.trim()) ?? '';
    if (name.isEmpty) return {'error': 'Routine name cannot be empty.'};

    final rawNames = (args['exercise_names'] as List?)?.cast<String>() ?? [];
    final resolvedIds = <String>[];
    final unresolved = <String>[];

    for (final n in rawNames) {
      try {
        final ex = _resolveExercise(n.trim());
        if (ex == null) {
          unresolved.add(n);
        } else {
          resolvedIds.add(ex.id);
        }
      } on AmbiguousMatchException catch (e) {
        return {
          'error': 'Ambiguous exercise name "$n". Did you mean one of:',
          'candidates': e.candidates,
        };
      }
    }

    if (unresolved.isNotEmpty) {
      return {
        'error': 'Could not find exercises: $unresolved',
        'available_examples': _exampleExerciseNames(),
      };
    }

    await _wp.createRoutine(name, resolvedIds);
    return {
      'created': true,
      'routine_name': name,
      'exercise_count': resolvedIds.length,
      'exercises': [for (final id in resolvedIds) _wp.getExerciseName(id)],
    };
  }

  Future<Map<String, Object?>> _updateRoutine(Map<String, Object?> args) async {
    final routineName = (args['routine_name'] as String?)?.trim() ?? '';
    final Routine routine;
    try {
      final resolved = _resolveRoutine(routineName);
      if (resolved == null) {
        return {'error': 'No routine found matching "$routineName".'};
      }
      routine = resolved;
    } on AmbiguousMatchException catch (e) {
      return {
        'error': 'Multiple routines match "$routineName". Did you mean one of:',
        'ambiguous_matches': e.candidates,
      };
    }

    var ids = List<String>.from(routine.exerciseIds);

    // Reorder (full replacement of order)
    final reorderNames = (args['reorder_exercise_names'] as List?)?.cast<String>();
    if (reorderNames != null && reorderNames.isNotEmpty) {
      final reorderedIds = <String>[];
      for (final n in reorderNames) {
        try {
          final ex = _resolveExercise(n.trim());
          if (ex != null) reorderedIds.add(ex.id);
        } on AmbiguousMatchException {
          // skip ambiguous entries in reorder
        }
      }
      if (reorderedIds.isNotEmpty) ids = reorderedIds;
    }

    // Remove exercises
    final removeNames = (args['remove_exercise_names'] as List?)?.cast<String>();
    if (removeNames != null) {
      for (final n in removeNames) {
        try {
          final ex = _resolveExercise(n.trim());
          if (ex != null) ids.remove(ex.id);
        } on AmbiguousMatchException {
          // skip ambiguous entries
        }
      }
    }

    // Add exercises
    final addNames = (args['add_exercise_names'] as List?)?.cast<String>();
    if (addNames != null) {
      for (final n in addNames) {
        try {
          final ex = _resolveExercise(n.trim());
          if (ex != null && !ids.contains(ex.id)) ids.add(ex.id);
        } on AmbiguousMatchException {
          // skip ambiguous entries
        }
      }
    }

    final updated = Routine(
      id: routine.id,
      name: routine.name,
      exerciseIds: ids,
      createdAt: routine.createdAt,
    );
    await _wp.updateRoutine(updated);

    return {
      'updated': true,
      'routine_name': routine.name,
      'exercise_count': ids.length,
      'exercises': [for (final id in ids) _wp.getExerciseName(id)],
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Exercise? _resolveExercise(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;
    final all = _wp.allExercises;
    for (final e in all) {
      if (e.name.toLowerCase() == q) return e;
    }
    final partials = [for (final e in all) if (e.name.toLowerCase().contains(q)) e];
    if (partials.isEmpty) return null;
    if (partials.length == 1) return partials.first;
    throw AmbiguousMatchException([for (final e in partials) e.name]);
  }

  Routine? _resolveRoutine(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;
    for (final r in _wp.routines) {
      if (r.name.toLowerCase() == q) return r;
    }
    final partials = [
      for (final r in _wp.routines) if (r.name.toLowerCase().contains(q)) r
    ];
    if (partials.isEmpty) return null;
    if (partials.length == 1) return partials.first;
    throw AmbiguousMatchException([for (final r in partials) r.name]);
  }

  List<String> _exampleExerciseNames() =>
      _wp.allExercises.take(8).map((e) => e.name).toList();

  String _d(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  double _round(double v) => (v * 10).round() / 10;
  double? _roundOrNull(double? v) => v == null ? null : _round(v);
}
