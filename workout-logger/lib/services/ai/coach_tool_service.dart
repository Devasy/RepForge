// coach_tool_service.dart — DB-backed function-calling tools for the AI coach.
//
// Exposes a set of read-only query functions the model can call to ground its
// answers in the user's real data. Every tool reuses existing parameterized
// query methods on WorkoutProvider / PRManager — no new analytics logic lives
// here, only the schema + arg parsing + JSON shaping.

import 'dart:math' as math;

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../models/models.dart';
import '../../models/sleep_hr_models.dart';
import '../workout_provider.dart';
import '../managers/pr_manager.dart';
import '../managers/health_history_manager.dart';
import '../../data/exercise_database.dart';
import 'sql_query_service.dart';
import 'coach_program_tools.dart';

class AmbiguousMatchException implements Exception {
  const AmbiguousMatchException(this.candidates);
  final List<String> candidates;
}

class CoachToolService {
  final WorkoutProvider _wp;
  final PRManager _pr;
  final HealthHistoryManager? _hh;
  final SqlQueryService? _sql;

  CoachToolService({
    required WorkoutProvider workoutProvider,
    required PRManager prManager,
    HealthHistoryManager? healthHistory,
    SqlQueryService? sqlQuery,
  }) : _wp = workoutProvider,
       _pr = prManager,
       _hh = healthHistory,
       _sql = sqlQuery;

  static Schema get _muscleIntensitiesSchema => Schema.array(
    description:
        'Complete per-muscle estimated intensity scores, integers 1–10. '
        'Include all involved muscles once using known muscle names or IDs. '
        'Scores are independent and need not sum to 10. Omit to preserve existing scores; '
        'an empty list clears this dataset. Stretch never adds resistance load. '
        'For resistance, primary_muscle must have a highest score (ties allowed). '
        'Use separate resistance_intensities and stretch_intensities maps. '
        'These are estimates, not measured activation or muscle growth.',
    nullable: true,
    items: Schema.object(
      properties: {
        'muscle': Schema.string(description: 'Known muscle group name or ID.'),
        'intensity': Schema.integer(
          description: 'Independent estimated score, 1–10.',
        ),
      },
      requiredProperties: ['muscle', 'intensity'],
    ),
  );

  /// Tool declaration for the optimizer screen's `ask_user_questions` flow.
  /// NOT included in the coach's tool list — only the optimizer adds it.
  static FunctionDeclaration
  get askUserQuestionsDeclaration => FunctionDeclaration(
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
                description:
                    'The question text, e.g. "What is your primary goal?"',
              ),
              'options': Schema.array(
                items: Schema.string(),
                description:
                    '3–4 answer chips, e.g. ["Strength","Hypertrophy","Fat loss","Endurance"].',
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
    Tool(
      functionDeclarations: [
        ...CoachProgramTools.declarations,
        FunctionDeclaration(
          'get_progress_overview',
          'Start here for overall or multi-muscle progress. Retrieves logged exercises and dated first/latest observed sets within the requested window, grouped by major muscle. Includes coverage gaps; follow up with get_exercise_performance for details. Does not infer hypertrophy from tonnage.',
          Schema.object(
            properties: {
              'days': Schema.integer(
                description:
                    'Required requested window in days; six months is 183.',
              ),
              'muscle_groups': Schema.array(
                items: Schema.string(),
                description: 'Optional group names. Omit for all major groups.',
                nullable: true,
              ),
            },
            requiredProperties: ['days'],
          ),
        ),
        FunctionDeclaration(
          'get_muscle_group_volume',
          'Get volume history over time for one or multiple muscle groups '
              '(e.g. ["Biceps", "Triceps"] or ["Chest", "Back"]). Returns dates, '
              'per-muscle volume series over time, and totals. Use for muscle '
              'comparisons (like "biceps vs triceps graph") or muscle volume '
              'distribution breakdown.',
          Schema.object(
            properties: {
              'muscle_groups': Schema.array(
                items: Schema.string(),
                description:
                    'List of muscle group names, e.g. ["Biceps", "Triceps"] or '
                    '["Chest", "Back", "Legs"].',
              ),
              'days': Schema.integer(
                description:
                    'Optional. Number of days to look back (defaults to 60).',
                nullable: true,
              ),
            },
            requiredProperties: ['muscle_groups'],
          ),
        ),
        FunctionDeclaration(
          'get_logged_exercises',
          'Discover exact exercise IDs and names from the user’s logged workouts before querying performance. Filter by muscle group when requested; do not guess exercise names or ask the user to list data the app has.',
          Schema.object(
            properties: {
              'muscle_group': Schema.string(
                description: 'Optional muscle group, such as Biceps or Back.',
                nullable: true,
              ),
              'days': Schema.integer(
                description: 'History window in days; defaults to 90.',
                nullable: true,
              ),
            },
          ),
        ),
        FunctionDeclaration(
          'get_exercise_performance',
          'Get how a specific exercise has progressed: per-session volume '
              'trend, the full per-session weight×reps and duration set history, growth '
              'slope, best estimated 1RM, last logged sets, and personal '
              'record (including best duration). Use for questions like "how is my bench press '
              'progressing" or "what weight and reps did I do for squats '
              'last month".',
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
              'limit': Schema.integer(
                description:
                    'Optional. Max number of most-recent sessions to return '
                    'in set_history and volume_trend. Use a small value (e.g. '
                    '1–5) when you only need recent sessions, to save tokens. '
                    'Defaults to 20; capped at 40.',
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
              'limit': Schema.integer(
                description:
                    'Optional. Max number of most-recent sessions to include '
                    'in the per-session breakdown. The session_count and '
                    'total_volume totals always cover the full range. Use a '
                    'small value to save tokens. Defaults to 40; capped at 40.',
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
              'limit': Schema.integer(
                description:
                    'Optional. Max number of most-recent points to include in '
                    'volume_over_time. session_count and total_volume always '
                    'cover all matching sessions. Defaults to 40; capped at 40.',
                nullable: true,
              ),
            },
            requiredProperties: ['routine_name'],
          ),
        ),
        FunctionDeclaration(
          'get_personal_records',
          'Get personal records (best weight, reps, single-set volume, and duration for time-based exercises). '
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
              'exercises. Exercises are matched by name from the catalogue. '
              'Optionally provide default attachment handles for exercises in this routine.',
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
              'exercise_handles': Schema.array(
                items: Schema.object(
                  properties: {
                    'exercise_name': Schema.string(
                      description: 'Name of the exercise.',
                    ),
                    'handle': Schema.string(
                      description:
                          'Attachment or handle name, or empty string to clear.',
                    ),
                  },
                  requiredProperties: ['exercise_name', 'handle'],
                ),
                description:
                    'Optional. List of exercise-to-handle mappings, e.g. [{"exercise_name": "Cable Row", "handle": "V-Bar"}, {"exercise_name": "Triceps Pushdown", "handle": "Rope"}].',
                nullable: true,
              ),
            },
            requiredProperties: ['name', 'exercise_names'],
          ),
        ),
        FunctionDeclaration(
          'update_routine',
          'Modify an existing routine: add exercises, remove exercises, reorder them, '
              'or set default attachment handles. Specify the routine by name. '
              'Exercises are matched by name from the catalogue.',
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
              'exercise_handles': Schema.array(
                items: Schema.object(
                  properties: {
                    'exercise_name': Schema.string(
                      description: 'Name of the exercise.',
                    ),
                    'handle': Schema.string(
                      description:
                          'Attachment or handle name, or empty string to clear.',
                    ),
                  },
                  requiredProperties: ['exercise_name', 'handle'],
                ),
                description:
                    'Optional. List of exercise-to-handle mappings, e.g. [{"exercise_name": "Cable Row", "handle": "V-Bar"}]. Set handle to empty string to clear.',
                nullable: true,
              ),
            },
            requiredProperties: ['routine_name'],
          ),
        ),
        FunctionDeclaration(
          'add_custom_exercise',
          'Create a new custom exercise in the catalogue when the one the user '
              'wants does not already exist. Match the muscle to an existing '
              'muscle group (call get_muscle_recovery or list routines first '
              'if unsure of the available muscle names). After creating it you '
              'can reference it by name in create_routine / update_routine. '
              'Use resistance_intensities and stretch_intensities for all involved muscles.',
          Schema.object(
            properties: {
              'name': Schema.string(
                description:
                    'Name of the new exercise, e.g. "Cable Crossover".',
              ),
              'category': Schema.string(
                description:
                    'Either "compound" (multi-joint) or "isolation" (single-joint).',
              ),
              'primary_muscle': Schema.string(
                description:
                    'Primary muscle group this exercise targets, e.g. "Chest" '
                    'or "Biceps". Must match an existing muscle group.',
              ),
              'resistance_intensities': _muscleIntensitiesSchema,
              'stretch_intensities': _muscleIntensitiesSchema,
              'exercise_type': Schema.string(
                description:
                    'Optional. Either "weightAndReps" (standard sets/reps) or "timeBased" (duration holds). Defaults to "weightAndReps".',
                nullable: true,
              ),
              'available_handles': Schema.array(
                items: Schema.string(),
                description:
                    'Optional. List of attachment/handle variations, e.g. ["Rope", "V-Bar"].',
                nullable: true,
              ),
            },
            requiredProperties: ['name', 'category', 'primary_muscle'],
          ),
        ),
        FunctionDeclaration(
          'update_exercise',
          'Modify an existing exercise in the catalogue (both custom exercises and '
              'library exercises). You can update its name, exercise type '
              '("weightAndReps" or "timeBased"), category ("compound" or "isolation"), '
              'multiple per-muscle resistance and stretch intensities, primary and secondary '
              'involvement, or available attachments/handles '
              '(e.g. ["Rope", "V-Bar", "D-Handles"]).',
          Schema.object(
            properties: {
              'exercise_name': Schema.string(
                description:
                    'Current exercise name or exact exercise ID. Use the ID when names are ambiguous.',
              ),
              'new_name': Schema.string(
                description: 'Optional. New display name for the exercise.',
                nullable: true,
              ),
              'exercise_type': Schema.string(
                description: 'Optional. Either "weightAndReps" or "timeBased".',
                nullable: true,
              ),
              'category': Schema.string(
                description: 'Optional. Either "compound" or "isolation".',
                nullable: true,
              ),
              'primary_muscle': Schema.string(
                description:
                    'Optional. Primary muscle group name (e.g. "Chest", "Biceps").',
                nullable: true,
              ),
              'resistance_intensities': _muscleIntensitiesSchema,
              'stretch_intensities': _muscleIntensitiesSchema,
              'available_handles': Schema.array(
                items: Schema.string(),
                description:
                    'Optional. List of allowed attachment/handle variations, e.g. ["Rope", "V-Bar"].',
                nullable: true,
              ),
            },
            requiredProperties: ['exercise_name'],
          ),
        ),
        FunctionDeclaration(
          'get_health_metrics',
          'Fetch historical sleep sessions and sleep stage breakdown (deep, REM, '
              'light, awake minutes) over the last N days. Use for sleep & '
              'recovery queries.',
          Schema.object(
            properties: {
              'days': Schema.integer(
                description:
                    'Optional. Number of days to look back (defaults to 30).',
                nullable: true,
              ),
            },
          ),
        ),
        FunctionDeclaration(
          'analyze_health_workout_correlation',
          'Run an analytical statistical pipeline calculating Mean (µ), Standard Deviation (σ), '
              'Pearson Correlation Coefficient (r), and linear regression (y = mx + b) between a health metric '
              '(sleep_hours, deep_sleep_min) and a workout metric '
              '(workout_volume, session_duration, exercise_max_weight). Returns analytical stats '
              'and paired coordinates ready to visualize.',
          Schema.object(
            properties: {
              'x_metric': Schema.string(
                description:
                    'Health metric, e.g. "sleep_hours", "deep_sleep_min".',
              ),
              'y_metric': Schema.string(
                description:
                    'Workout metric, e.g. "workout_volume", "session_duration", "exercise_max_weight".',
              ),
              'exercise_name': Schema.string(
                description:
                    'Optional. Specific exercise name if y_metric is "exercise_max_weight".',
                nullable: true,
              ),
              'days': Schema.integer(
                description:
                    'Optional. Number of days to consider (defaults to 60).',
                nullable: true,
              ),
            },
            requiredProperties: ['x_metric', 'y_metric'],
          ),
        ),
        FunctionDeclaration(
          'get_sleeping_hr_analytics',
          'Fetch and compute sleeping heart rate statistics over the past N days (e.g. 14 days). '
              'Returns overnight p5 (5th percentile sleeping HR floor), p25, median, p75, p95, mean, min, max, '
              'standard deviation (stdev), variance, linear trend (slope/direction), and nightly '
              'time-series data as labels + series ready to chart. '
              'Use whenever the user asks to analyze sleeping HR, overnight HR variation, or recovery trends.',
          Schema.object(
            properties: {
              'days': Schema.integer(
                description:
                    'Optional. Number of days to analyze (defaults to 14).',
                nullable: true,
              ),
            },
          ),
        ),
        if (_sql != null) _runSqlQueryDeclaration,
      ],
    ),
  ];

  /// Schema-aware declaration for run_sql_query — only included when a
  /// SqlQueryService is wired (i.e. the app has cut over to SQLite).
  FunctionDeclaration get _runSqlQueryDeclaration => FunctionDeclaration(
    'run_sql_query',
    'Run a read-only SQL SELECT query directly against the workout database '
        'for complex questions and to verify contradictory or incomplete tool results (custom joins, filters, '
        'or aggregations). Tables:\n'
        'sessions(id, date, routine_id, duration_min, notes, hc_synced_at, session_effort, program_id, program_day_id, program_week_number, import_source)\n'
        'exercise_logs(id, session_id, exercise_id, notes, handle)\n'
        'sets(id, exercise_log_id, weight, reps, is_dropset, drops_json, '
        'time_taken, timestamp, assist_weight, extra_weight, handle, body_weight_at_log, load_mode, load_encoding_version)\n'
        'exercises(id, name, category, is_custom, available_handles, exercise_type, resistance_intensities, stretch_intensities, resistance_intensity_override) — custom '
        'exercises and built-in overrides (is_custom=0 indicates an override of a built-in exercise)\n'
        'resistance_intensities and stretch_intensities are JSON maps of muscle IDs to independent 1–10 scores. Legacy resistance may have decimals. Stretch never contributes to resistance load.\n'
        'muscle_groups(id, name, growth_rate, last_updated)\n'
        'routines(id, name, created_at)\n'
        'routine_exercises(routine_id, exercise_id, position, default_handle)\n'
        'targets(id, exercise_id, target_type, target_value, current_value, '
        'estimated_completion_date, created_at, is_completed)\n'
        'personal_records(exercise_id, handle, load_encoding_version, best_weight, best_reps, best_volume, best_duration, achieved_at)\n'
        'health_samples(id, type, start_ts, end_ts, utc_ts, value) — type is '
        'heart_rate | resting_heart_rate | hrv_rmssd; one row per Health '
        'Connect sample. Join on start_ts/end_ts (local wall-clock, same clock as '
        'workout_sessions.date); utc_ts is the UTC instant, for ordering '
        'and de-duplication only\n'
        'sleep_sessions(id, start_ts, end_ts, light_min, deep_min, rem_min, '
        'awake_min) — one row per night; start_ts/end_ts are local '
        'wall-clock, id is the UTC start instant\n'
        'sleep_stage_intervals(sleep_session_id, start_ts, end_ts, stage) — '
        'stage is deep | rem | light | awake\n'
        'skin_temperature_samples(record_id, source_package, measurement_location, '
        'record_start_ts, record_end_ts, timestamp, utc_ts, delta_c, baseline_c) — '
        'Previously saved Health Connect skin temperature from the '
        'bridge/source app. '
        'delta_c is a Celsius difference from the source baseline; baseline_c '
        'is optional. Absolute skin temperature is baseline_c + delta_c ONLY '
        'when baseline_c is present. Never interpret deltas as body temperature. '
        'For source_package com.repforge.healthbridge, baseline_c is the Samsung '
        'session summary or the mean of source samples, not a personal rolling '
        'baseline. Compare reconstructed absolute skin temperatures across nights, '
        'not raw deltas centered on different record baselines. '
        'All timestamps except utc_ts use local wall-clock. For sleep analysis '
        'join timestamp >= sleep_sessions.start_ts AND timestamp < sleep_sessions.end_ts; '
        'use EXISTS or deduplicate overlapping sleep sessions to avoid double counting. '
        'Aggregate per sleep session/morning date, source_package and measurement_location '
        'before joining workouts. Do not pool sources or measurement locations. '
        'Report nights with data and missing nights; missing is not zero. '
        'Skin-temperature collection is disabled in this release. Only analyze '
        'existing saved data; do not offer to collect or sync new temperature '
        'readings.\n'
        'When joining tables, select explicit columns with aliases (e.g. s.id AS '
        'session_id, l.id AS log_id) instead of SELECT *, since duplicate column '
        'names across joined tables will silently collide.\n'
        'Built-ins without overrides are absent from exercises: discover group IDs with get_logged_exercises, filter exercise_logs.exercise_id IN those IDs, and LEFT JOIN names. Do not require a catalogue row for built-in logs. The activation join table has been removed. Resolve muscle membership with get_logged_exercises; never multiply sets by muscle entries. Explicitly filter requested dates; separate handles and load encodings. Imported sets with load_mode=unknown have no known load; exclude them from tonnage and load trends and use reps, duration or weighted-set exposure instead. Reconstructed segment times are not measured HR boundaries. Only SELECT/WITH statements are allowed, one statement per call.',
    Schema.object(
      properties: {
        'query': Schema.string(
          description: 'A single read-only SQL SELECT statement.',
        ),
        'limit': Schema.integer(
          description: 'Optional. Max rows to return (default 200, max 500).',
          nullable: true,
        ),
      },
      requiredProperties: ['query'],
    ),
  );

  /// Dispatch a model function call to the matching query and return a
  /// JSON-serializable result map.
  Future<Map<String, Object?>> handleCall(FunctionCall call) async {
    if (CoachProgramTools.names.contains(call.name)) {
      return CoachProgramTools(_wp).handleCall(call);
    }
    switch (call.name) {
      case 'get_sleeping_hr_analytics':
        return await _getSleepingHrAnalytics(call.args);
      case 'get_health_metrics':
        return await _getHealthMetrics(call.args);
      case 'analyze_health_workout_correlation':
        return await _analyzeHealthWorkoutCorrelation(call.args);
      case 'get_muscle_group_volume':
        return _muscleGroupVolume(call.args);
      case 'get_progress_overview':
        return _progressOverview(call.args);
      case 'get_logged_exercises':
        return _loggedExercises(call.args);
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
      case 'add_custom_exercise':
        return await _addCustomExercise(call.args);
      case 'update_exercise':
        return await _updateExercise(call.args);
      case 'run_sql_query':
        final sql = _sql;
        if (sql == null) return {'error': 'SQL query tool is not available.'};
        return await sql.runQuery(
          (call.args['query'] as String?) ?? '',
          limit: (call.args['limit'] as num?)?.toInt(),
        );
      default:
        return {'error': 'Unknown tool: ${call.name}'};
    }
  }

  // ── Tool implementations ───────────────────────────────────────────────────

  Future<Map<String, Object?>> _getSleepingHrAnalytics(
    Map<String, Object?> args,
  ) async {
    final hh = _hh;
    if (hh == null) {
      return {
        'error':
            'Health Connect integration is not active or HealthHistoryManager unavailable.',
      };
    }

    // Clamp before the per-day loop below — an unbounded model-supplied value
    // (e.g. `days: 99999`) would otherwise fan out into a huge number of
    // sequential hh.sleepNight() lookups.
    final days = _limitArg(args, 14, key: 'days', max: 60);
    final now = DateTime.now();
    final dailyStats = <Map<String, Object?>>[];
    final p5List = <double>[];
    final p25List = <double>[];
    final meanList = <double>[];
    final labels = <String>[];

    for (var i = days - 1; i >= 0; i--) {
      final morning = now.subtract(Duration(days: i));
      final dateStr = _d(morning);
      final snap = await hh.sleepNight(morning);

      if (snap != null) {
        final p5 = snap.p5Bpm.toDouble();
        final p95 = snap.p95Bpm.toDouble();

        double meanBpm = 0;
        double stdevBpm = 0;
        double varianceBpm = 0;
        double p25Bpm = p5;

        if (snap.segments.isNotEmpty) {
          final avgs = snap.segments.map((s) => s.avgBpm).toList()..sort();
          meanBpm = avgs.reduce((a, b) => a + b) / avgs.length;
          p25Bpm = avgs[(avgs.length * 0.25).floor().clamp(0, avgs.length - 1)];

          final varSum = avgs.fold(
            0.0,
            (sum, x) => sum + (x - meanBpm) * (x - meanBpm),
          );
          varianceBpm = varSum / avgs.length;
          stdevBpm = math.sqrt(varianceBpm);
        } else {
          meanBpm = (p5 + p95) / 2.0;
        }

        p5List.add(p5);
        p25List.add(_round(p25Bpm));
        meanList.add(_round(meanBpm));
        labels.add('${morning.month}/${morning.day}');

        dailyStats.add({
          'date': dateStr,
          'p5_bpm': snap.p5Bpm,
          'p25_bpm': _round(p25Bpm),
          'mean_bpm': _round(meanBpm),
          'p95_bpm': snap.p95Bpm,
          'stdev': _round(stdevBpm),
          'variance': _round(varianceBpm),
          'segment_count': snap.segments.length,
        });
      }
    }

    if (p5List.isEmpty) {
      return {
        'error': 'No sleeping heart rate records found in the last $days days.',
      };
    }

    final p5Mean = p5List.reduce((a, b) => a + b) / p5List.length;
    final p5VarSum = p5List.fold(
      0.0,
      (sum, x) => sum + (x - p5Mean) * (x - p5Mean),
    );
    final p5Variance = p5VarSum / p5List.length;
    final p5Stdev = math.sqrt(p5Variance);

    double slope = 0.0;
    if (p5List.length > 1) {
      final n = p5List.length;
      double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
      for (var i = 0; i < n; i++) {
        sumX += i;
        sumY += p5List[i];
        sumXY += i * p5List[i];
        sumXX += i * i;
      }
      final denom = n * sumXX - sumX * sumX;
      if (denom != 0) {
        slope = (n * sumXY - sumX * sumY) / denom;
      }
    }

    final trendDirection = slope < -0.1
        ? 'improving'
        : (slope > 0.1 ? 'elevated' : 'stable');

    return {
      'days_analyzed': days,
      'valid_nights_count': p5List.length,
      'overall_summary': {
        'mean_p5_sleeping_hr': _round(p5Mean),
        'stdev_p5_sleeping_hr': _round(p5Stdev),
        'variance_p5_sleeping_hr': _round(p5Variance),
        'min_p5_sleeping_hr': p5List.reduce(math.min),
        'max_p5_sleeping_hr': p5List.reduce(math.max),
        'linear_trend_slope': _round(slope),
        'trend_direction': trendDirection,
      },
      'daily_breakdown': dailyStats,
      // Domain-neutral series the model can shape into any component. The tool
      // layer deliberately does not name A2UI components: presentation is the
      // prompt's decision, not the data layer's.
      'labels': labels,
      'series': [
        {'name': 'P5 Sleeping HR', 'values': p5List},
        {'name': 'P25 HR', 'values': p25List},
        {'name': 'Mean HR', 'values': meanList},
      ],
    };
  }

  Future<Map<String, Object?>> _getHealthMetrics(
    Map<String, Object?> args,
  ) async {
    final hh = _hh;
    if (hh == null) {
      return {
        'error':
            'Health Connect integration is not active or HealthHistoryManager unavailable.',
      };
    }
    final days = _limitArg(args, 30, key: 'days', max: 31);
    final now = DateTime.now();
    // Week granularity only covers the last 7 days; anything wider needs the
    // month bucket. Both return per-night bars, so trim to the exact window.
    final granularity = days <= 7
        ? HealthGranularity.week
        : HealthGranularity.month;
    final allBars = await hh.sleepBars(now, granularity);
    final bars = allBars.length > days
        ? allBars.sublist(allBars.length - days)
        : allBars;

    return {
      'days': days,
      'sleep_records': [
        for (final b in bars)
          {
            'date': _d(b.date),
            'total_hours': _round(b.totalMinutes / 60.0),
            'deep_min': b.deepMin,
            'rem_min': b.remMin,
            'light_min': b.lightMin,
            'awake_min': b.awakeMin,
          },
      ],
    };
  }

  Future<Map<String, Object?>> _analyzeHealthWorkoutCorrelation(
    Map<String, Object?> args,
  ) async {
    final xMetric = (args['x_metric'] as String?)?.trim() ?? 'sleep_hours';
    final yMetric = (args['y_metric'] as String?)?.trim() ?? 'workout_volume';
    final exName = (args['exercise_name'] as String?)?.trim();
    final days = _limitArg(args, 60, key: 'days', max: 365);

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final sessions = _wp.sessions
        .where((s) => !s.date.isBefore(cutoff))
        .toList();

    if (sessions.isEmpty) {
      return {'error': 'No workout sessions logged in the last $days days.'};
    }

    final dayData = <String, Map<String, double>>{};

    for (final s in sessions) {
      final key = _d(s.date);
      final m = dayData.putIfAbsent(key, () => {});

      if (yMetric == 'workout_volume') {
        var vol = 0.0;
        for (final exLog in s.exercises) {
          for (final set in exLog.sets) {
            vol += set.volume;
          }
        }
        m['y'] = vol;
      } else if (yMetric == 'session_duration') {
        m['y'] = s.duration.toDouble();
      } else if (yMetric == 'exercise_max_weight' && exName != null) {
        var maxW = 0.0;
        final ex = _resolveExercise(exName);
        if (ex != null) {
          for (final exLog in s.exercises.where((e) => e.exerciseId == ex.id)) {
            for (final set in exLog.sets) {
              if (set.weight > maxW) maxW = set.weight;
            }
          }
        }
        if (maxW > 0) m['y'] = maxW;
      }
    }

    final hh = _hh;
    if (hh != null) {
      // sleepBars(anchor, month) covers only the anchor's calendar month, so a
      // single call would drop every workout day before the 1st of this month
      // — the default window is 60 days. Walk each month the window touches
      // and merge the daily bars. Year granularity is not an option here: it
      // returns 12 monthly averages, not one bar per night.
      final lastMonth = DateTime(now.year, now.month, 1);
      final bars = <SleepDayBar>[];
      for (
        var m = DateTime(cutoff.year, cutoff.month, 1);
        !m.isAfter(lastMonth);
        m = DateTime(m.year, m.month + 1, 1)
      ) {
        bars.addAll(await hh.sleepBars(m, HealthGranularity.month));
      }
      for (final b in bars) {
        final key = _d(b.date);
        final m = dayData[key];
        if (m != null) {
          if (xMetric == 'sleep_hours') {
            m['x'] = _round(b.totalMinutes / 60.0);
          } else if (xMetric == 'deep_sleep_min') {
            m['x'] = b.deepMin.toDouble();
          }
        }
      }
    }

    final points = <Map<String, Object?>>[];
    final xVals = <double>[];
    final yVals = <double>[];

    for (final entry in dayData.entries) {
      final x = entry.value['x'];
      final y = entry.value['y'];
      if (x != null && y != null && x > 0 && y > 0) {
        xVals.add(x);
        yVals.add(y);
        points.add({'x': x, 'y': y, 'date': entry.key});
      }
    }

    final n = xVals.length;
    if (n < 2) {
      return {
        'error': 'Insufficient paired data points for correlation analysis.',
      };
    }

    final xMean = xVals.reduce((a, b) => a + b) / n;
    final yMean = yVals.reduce((a, b) => a + b) / n;

    var xVarSum = 0.0, yVarSum = 0.0, covSum = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = xVals[i] - xMean;
      final dy = yVals[i] - yMean;
      xVarSum += dx * dx;
      yVarSum += dy * dy;
      covSum += dx * dy;
    }

    final xStd = n > 1 ? math.sqrt(xVarSum / (n - 1)) : 0.0;
    final yStd = n > 1 ? math.sqrt(yVarSum / (n - 1)) : 0.0;
    final r = (xVarSum > 0 && yVarSum > 0)
        ? (covSum / math.sqrt(xVarSum * yVarSum))
        : 0.0;

    final slope = xVarSum > 0 ? (covSum / xVarSum) : 0.0;
    final intercept = yMean - (slope * xMean);

    String corrType;
    if (r >= 0.7) {
      corrType = 'strong_positive';
    } else if (r >= 0.3) {
      corrType = 'moderate_positive';
    } else if (r <= -0.7) {
      corrType = 'strong_negative';
    } else if (r <= -0.3) {
      corrType = 'moderate_negative';
    } else {
      corrType = 'neutral';
    }

    return {
      'pipeline': 'Health & Workout Statistical Correlation',
      'sample_count': n,
      'x_metric': xMetric,
      'x_mean': _round(xMean),
      'x_std_dev': _round(xStd),
      'y_metric': yMetric,
      'y_mean': _round(yMean),
      'y_std_dev': _round(yStd),
      'pearson_r': _round(r),
      'correlation_type': corrType,
      'trendline': {'slope': _round(slope), 'intercept': _round(intercept)},
      'points': points,
    };
  }

  Map<String, Object?> _progressOverview(Map<String, Object?> args) {
    if (args['days'] is! num) {
      return {'error': 'Provide the requested window in days.'};
    }
    final days = (args['days'] as num).toInt().clamp(1, 3650);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final sessionIndex = _indexSessions(cutoff);
    final rawGroups = args['muscle_groups'];
    final requested = [
      for (final group in rawGroups is List ? rawGroups : const [])
        if (group is String && group.trim().isNotEmpty) group.trim(),
    ];
    final groups = requested.isNotEmpty
        ? requested
        : [
            'Chest',
            'Back',
            'Shoulders',
            'Biceps',
            'Triceps',
            'Quadriceps',
            'Hamstrings',
            'Glutes',
            'Calves',
            'Core',
          ];
    final coverage = <Map<String, Object?>>[];
    for (final name in groups.take(20).toSet()) {
      final discovered = _loggedExercises({
        'muscle_group': name,
        'days': days,
      }, sessionIndex: sessionIndex);
      if (discovered['error'] != null) {
        coverage.add({'muscle_group': name, ...discovered});
        continue;
      }
      final exercises = (discovered['exercises'] as List)
          .cast<Map<String, Object?>>();
      // Prefer frequently logged lifts for comparisons, then recent activity.
      exercises.sort(
        (a, b) =>
            (b['session_count'] as int).compareTo(a['session_count'] as int),
      );
      coverage.add({
        'muscle_group': name,
        'logged_exercise_count': exercises.length,
        'omitted_exercise_count': math.max(0, exercises.length - 3),
        'exercises': [
          for (final e in exercises.take(3))
            {
              ...e,
              'earliest_session_in_window': _setHistory(
                e['exercise_id'] as String,
                cutoff,
                1,
                oldestFirst: true,
                sessionIndex: sessionIndex,
              ).firstOrNull,
              'latest_session_in_window': _setHistory(
                e['exercise_id'] as String,
                cutoff,
                1,
                sessionIndex: sessionIndex,
              ).firstOrNull,
            },
        ],
      });
    }
    return {
      'window_days': days,
      'metric':
          'Observed external load and reps; volume is load times reps, not measured hypertrophy.',
      'overlap':
          'Exercises may appear in multiple groups. Do not sum group totals as unique workload.',
      'coverage': coverage,
      'omitted_group_count': math.max(0, groups.length - 20),
    };
  }

  // Match parent groups explicitly and count each log once; subgroup requests stay precise.
  Set<String> _muscleIds(String id) => switch (id) {
    MuscleGroups.chest => {id, MuscleGroups.upperChest},
    MuscleGroups.back => {id, MuscleGroups.lats, MuscleGroups.lowerBack},
    MuscleGroups.shoulders => {
      id,
      MuscleGroups.frontDelts,
      MuscleGroups.sideDelts,
      MuscleGroups.rearDelts,
    },
    _ => {id},
  };

  Map<String, Object?> _muscleGroupVolume(Map<String, Object?> args) {
    final rawGroups = (args['muscle_groups'] as List?)?.cast<String>() ?? [];
    final days = _limitArg(args, 60, key: 'days', max: 365);
    final cutoff = DateTime.now().subtract(Duration(days: days));

    final allExercises = _wp.allExercises;
    final allSessions =
        _wp.sessions.where((s) => !s.date.isBefore(cutoff)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final dateMap = <String, Map<String, double>>{};
    final muscleTotals = <String, double>{};

    for (final groupName in rawGroups) {
      muscleTotals[groupName] = 0.0;

      // Resolve the requested display name to its muscle group ID first —
      // `Exercise.primaryMuscle` is itself an ID (e.g. "quads"), not a
      // display name, so comparing it against the raw group name via
      // substring matching is unreliable (false misses for e.g. "Quadriceps"
      // vs id "quads", false matches for unrelated short ids). Matching by
      // resolved ID also lets us include secondary muscle activations, not
      // just each exercise's primary one.
      MuscleGroup? resolvedGroup;
      try {
        resolvedGroup = _resolveMuscleGroup(groupName);
      } on AmbiguousMatchException {
        resolvedGroup = null;
      }
      if (resolvedGroup == null) continue;
      final targetId = resolvedGroup.id;

      final matchingExerciseIds = allExercises
          .where(
            (e) => e.muscleActivations.any(
              (m) => _muscleIds(targetId).contains(m.muscleGroupId),
            ),
          )
          .map((e) => e.id)
          .toSet();

      for (final session in allSessions) {
        final dateKey = _d(session.date);
        var groupVol = 0.0;
        for (final exLog in session.exercises) {
          if (matchingExerciseIds.contains(exLog.exerciseId)) {
            for (final set in exLog.sets) {
              groupVol += set.volume;
            }
          }
        }
        if (groupVol > 0) {
          dateMap.putIfAbsent(dateKey, () => {})[groupName] =
              (dateMap[dateKey]?[groupName] ?? 0.0) + groupVol;
          muscleTotals[groupName] = (muscleTotals[groupName] ?? 0) + groupVol;
        }
      }
    }

    final dates = dateMap.keys.toList()..sort();
    final series = <Map<String, Object?>>[];
    for (final groupName in rawGroups) {
      final values = <double>[];
      for (final d in dates) {
        values.add(_round(dateMap[d]?[groupName] ?? 0.0));
      }
      series.add({'name': groupName, 'values': values});
    }

    return {
      'dates': dates,
      'labels': dates.map((d) => d.length > 5 ? d.substring(5) : d).toList(),
      'series': series,
      'totals': {
        for (final entry in muscleTotals.entries)
          entry.key: _round(entry.value),
      },
    };
  }

  Map<String, List<WorkoutSession>> _indexSessions(DateTime cutoff) {
    final index = <String, List<WorkoutSession>>{};
    final sessions =
        _wp.sessions.where((s) => !s.date.isBefore(cutoff)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    for (final session in sessions) {
      for (final id in session.exercises.map((e) => e.exerciseId).toSet()) {
        index.putIfAbsent(id, () => []).add(session);
      }
    }
    return index;
  }

  Map<String, Object?> _loggedExercises(
    Map<String, Object?> args, {
    Map<String, List<WorkoutSession>>? sessionIndex,
  }) {
    final days = ((args['days'] as num?)?.toInt() ?? 90).clamp(1, 3650);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final indexed = sessionIndex ?? _indexSessions(cutoff);
    final name = (args['muscle_group'] as String?)?.trim();
    MuscleGroup? group;
    if (name != null && name.isNotEmpty) {
      try {
        group = _resolveMuscleGroup(name);
      } on AmbiguousMatchException catch (error) {
        return {'error': 'Ambiguous muscle group', 'matches': error.candidates};
      }
      if (group == null) return {'error': 'Unknown muscle group'};
    }
    final result = <Map<String, Object?>>[];
    for (final exercise in _wp.allExercises) {
      if (group != null &&
          !exercise.muscleActivations.any(
            (m) => _muscleIds(group!.id).contains(m.muscleGroupId),
          )) {
        continue;
      }
      final sessions = indexed[exercise.id] ?? const <WorkoutSession>[];
      if (sessions.isEmpty) continue;
      result.add({
        'exercise_id': exercise.id,
        'exercise': exercise.name,
        'session_count': sessions.length,
        'last_logged_date': _d(sessions.last.date),
        'available_handles': exercise.availableHandles,
      });
    }
    result.sort(
      (a, b) => (b['last_logged_date'] as String).compareTo(
        a['last_logged_date'] as String,
      ),
    );
    return {'window_days': days, 'exercises': result};
  }

  Map<String, Object?> _exercisePerformance(Map<String, Object?> args) {
    final name = (args['exercise_name'] as String?)?.trim() ?? '';
    final days = (args['days'] as num?)?.toInt();

    final Exercise exercise;
    try {
      final resolved = _resolveExercise(name);
      if (resolved == null) {
        // Fallback: check if the prompt queried a muscle group (e.g., "biceps", "triceps")
        final muscleRes = _muscleGroupVolume({
          'muscle_groups': [name],
          'days': days ?? 60,
        });
        final series = (muscleRes['series'] as List?) ?? [];
        if (series.isNotEmpty && (series[0]['values'] as List).isNotEmpty) {
          return {
            'is_muscle_group': true,
            'muscle_group': name,
            'labels': muscleRes['labels'],
            'series': series,
            'totals': muscleRes['totals'],
          };
        }
        return {
          'error': 'No exercise or muscle group found matching "$name".',
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

    final cutoff = days != null
        ? DateTime.now().subtract(Duration(days: days))
        : null;

    final progression = _wp
        .getVolumeProgression(exercise.id)
        .where((p) => cutoff == null || !p.date.isBefore(cutoff))
        .toList();

    final growth = _wp.getGrowthModel(exercise.id);
    final recentHistory = _setHistory(exercise.id, cutoff, 40);
    final earliestHistory = _setHistory(
      exercise.id,
      cutoff,
      1,
      oldestFirst: true,
    );
    final lastLoggedHistory = _setHistory(exercise.id, null, 1);
    final pr = _pr.getRecord(exercise.id);

    // Optional model-supplied cap; defaults preserve prior behaviour
    // (40 trend points, 20 set-history sessions).
    final hasLimit = args['limit'] != null;
    final trendCap = hasLimit ? _limitArg(args, 40) : 40;
    final setCap = hasLimit ? _limitArg(args, 20) : 20;

    return {
      'exercise': exercise.name,
      'session_count': progression.length,
      'window_days': ?days,
      'earliest_session_in_window': earliestHistory.isEmpty
          ? null
          : earliestHistory.first,
      'comparison_note':
          'Compare observed sets at similar reps and handle. First/latest alone can be noisy; use the history before concluding a trend.',
      'volume_trend': [
        for (final p
            in progression.length > trendCap
                ? progression.sublist(progression.length - trendCap)
                : progression)
          {'date': _d(p.date), 'volume': _round(p.volume)},
      ],
      // Per-session weight×reps breakdown (most recent first), so the model can
      // answer "what weight/reps did I do" rather than only volume totals.
      'set_history': _setHistory(exercise.id, cutoff, setCap),
      'growth': growth == null || progression.length < 2
          ? null
          : {
              'metric': 'session_load_times_reps',
              'scope': 'all_time',
              'requested_window_applied': false,
              'interpretation':
                  'Training volume, not measured muscle growth or strength; changes with set count.',
              'slope_per_day': _round(growth.slope),
              'weekly_growth_percent': _round(growth.weeklyGrowthPercent),
              'curve': growth.curve.name,
              'r2': _round(growth.r2),
              'trend': growth.r2 < 0.5
                  ? 'uncertain'
                  : growth.weeklyGrowthPercent > 0.5
                  ? 'volume_increasing'
                  : growth.weeklyGrowthPercent < -2
                  ? 'volume_decreasing'
                  : 'volume_stable',
            },
      'best_estimated_1rm_scope': 'all_time',
      'best_estimated_1rm': _roundOrNull(_wp.getBestOneRM(exercise.id)),
      'last_session': recentHistory.isEmpty
          ? null
          : recentHistory.first['sets'],
      'last_session_date': recentHistory.isEmpty
          ? null
          : recentHistory.first['date'],
      'last_session_scope': days == null ? 'all_time' : 'requested_window',
      'last_logged_session': lastLoggedHistory.isEmpty
          ? null
          : lastLoggedHistory.first,
      'personal_record': pr == null
          ? null
          : {
              'handle': pr.handle,
              'load_encoding_version': pr.loadEncodingVersion,
              'record_semantics':
                  'Independent maxima. Never combine best_weight and best_reps into a set; use set_history for observed pairs.',
              'best_weight': _round(pr.bestWeight),
              'best_reps': pr.bestReps,
              'best_volume': _round(pr.bestVolume),
              if (pr.bestDuration != null) 'best_duration': pr.bestDuration,
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

    final sessions =
        _wp.sessions
            .where((s) => !s.date.isBefore(start) && !s.date.isAfter(end))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final totalVolume = sessions.fold<double>(
      0,
      (sum, s) => sum + s.totalVolume,
    );

    return {
      'start_date': _d(start),
      'end_date': _d(end),
      'session_count': sessions.length,
      'total_volume': _round(totalVolume),
      'sessions': [
        for (final s in sessions.take(_limitArg(args, 40)))
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
    final cutoff = days != null
        ? DateTime.now().subtract(Duration(days: days))
        : null;

    final sessions =
        _wp.sessions
            .where((s) => s.routineId == routine.id)
            .where((s) => cutoff == null || !s.date.isBefore(cutoff))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final totalVolume = sessions.fold<double>(
      0,
      (sum, s) => sum + s.totalVolume,
    );

    return {
      'routine': routine.name,
      'exercises': [
        for (final id in routine.exerciseIds) _wp.getExerciseName(id),
      ],
      'session_count': sessions.length,
      'window_days': ?days,
      'total_volume': _round(totalVolume),
      'volume_over_time': [
        for (final s
            in sessions.length > _limitArg(args, 40)
                ? sessions.sublist(sessions.length - _limitArg(args, 40))
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
                'handle': pr.handle,
                'load_encoding_version': pr.loadEncodingVersion,
                'record_semantics':
                    'Independent maxima. Never combine best_weight and best_reps into a set; use set_history for observed pairs.',
                'best_weight': _round(pr.bestWeight),
                'best_reps': pr.bestReps,
                'best_volume': _round(pr.bestVolume),
                if (pr.bestDuration != null) 'best_duration': pr.bestDuration,
                'achieved_at': _d(pr.achievedAt),
              },
      };
    }

    return {
      'records': [
        for (final pr in _pr.allRecords)
          {
            'exercise': _wp.getExerciseName(pr.exerciseId),
            'record_semantics':
                'Independent maxima. Never combine best_weight and best_reps into a set.',
            'handle': pr.handle,
            'load_encoding_version': pr.loadEncodingVersion,
            'best_weight': _round(pr.bestWeight),
            'best_reps': pr.bestReps,
            'best_volume': _round(pr.bestVolume),
            if (pr.bestDuration != null) 'best_duration': pr.bestDuration,
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
      ..sort(
        (a, b) => a.value.recoveryPercent.compareTo(b.value.recoveryPercent),
      );
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
            'exercises': [
              for (final id in r.exerciseIds) _wp.getExerciseName(id),
            ],
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

    final handlesArg = _parseExerciseHandles(args['exercise_handles']);
    final defaultHandles = <String, String>{};
    if (handlesArg != null) {
      for (final entry in handlesArg.entries) {
        final exName = entry.key.trim();
        final handle = entry.value.trim();
        try {
          final ex = _resolveExercise(exName);
          if (ex != null && handle.isNotEmpty) {
            defaultHandles[ex.id] = handle;
          }
        } catch (_) {}
      }
    }

    await _wp.createRoutine(
      name,
      resolvedIds,
      defaultHandles: defaultHandles.isEmpty ? null : defaultHandles,
    );
    return {
      'created': true,
      'routine_name': name,
      'exercise_count': resolvedIds.length,
      'exercises': [for (final id in resolvedIds) _wp.getExerciseName(id)],
      if (defaultHandles.isNotEmpty) 'default_handles': defaultHandles,
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
    final reorderNames = (args['reorder_exercise_names'] as List?)
        ?.cast<String>();
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
    final removeNames = (args['remove_exercise_names'] as List?)
        ?.cast<String>();
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

    final handlesArg = _parseExerciseHandles(args['exercise_handles']);
    final defaultHandles = Map<String, String>.from(
      routine.defaultHandles ?? {},
    );
    if (handlesArg != null) {
      for (final entry in handlesArg.entries) {
        final exName = entry.key.trim();
        final handle = entry.value.trim();
        try {
          final ex = _resolveExercise(exName);
          if (ex != null) {
            if (handle.isEmpty) {
              defaultHandles.remove(ex.id);
            } else {
              defaultHandles[ex.id] = handle;
            }
          }
        } catch (_) {}
      }
    }

    final updated = routine.copyWith(
      exerciseIds: ids,
      defaultHandles: defaultHandles,
    );
    await _wp.updateRoutine(updated);

    return {
      'updated': true,
      'routine_name': routine.name,
      'exercise_count': ids.length,
      'exercises': [for (final id in ids) _wp.getExerciseName(id)],
      if (defaultHandles.isNotEmpty) 'default_handles': defaultHandles,
    };
  }

  Future<Map<String, Object?>> _addCustomExercise(
    Map<String, Object?> args,
  ) async {
    final name =
        (args['name'] as String?)?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (name.isEmpty) return {'error': 'Exercise name cannot be empty.'};

    // Reject duplicates so the model reuses the existing exercise instead.
    final existing = _wp.allExercises.where(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      return {
        'error':
            'An exercise named "${existing.first.name}" already exists. '
            'Use it by name instead of creating a duplicate.',
      };
    }

    final category = (args['category'] as String?)?.trim().toLowerCase() ?? '';
    if (category != 'compound' && category != 'isolation') {
      return {
        'error': 'category must be "compound" or "isolation", got "$category".',
      };
    }

    final muscleName = (args['primary_muscle'] as String?)?.trim() ?? '';
    final MuscleGroup muscle;
    try {
      final resolved = _resolveMuscleGroup(muscleName);
      if (resolved == null) {
        return {
          'error': 'No muscle group found matching "$muscleName".',
          'available_muscles': [for (final m in _wp.muscleGroups) m.name],
        };
      }
      muscle = resolved;
    } on AmbiguousMatchException catch (e) {
      return {
        'error': 'Multiple muscle groups match "$muscleName". Did you mean:',
        'ambiguous_matches': e.candidates,
      };
    }

    ExerciseType exerciseType = ExerciseType.weightAndReps;
    if (args.containsKey('exercise_type')) {
      final typeStr = (args['exercise_type'] as String?)?.trim();
      if (typeStr == null ||
          typeStr.isEmpty ||
          (typeStr != 'timeBased' && typeStr != 'weightAndReps')) {
        return {
          'error':
              'Invalid exercise_type "$typeStr". Allowed values are "weightAndReps" or "timeBased".',
        };
      }
      exerciseType = typeStr == 'timeBased'
          ? ExerciseType.timeBased
          : ExerciseType.weightAndReps;
    }

    final handles = (args['available_handles'] as List?)
        ?.map((h) => h.toString().trim())
        .where((h) => h.isNotEmpty)
        .toList();

    try {
      await _wp.addCustomExercise(
        name: name,
        category: category,
        primaryMuscleGroupId: muscle.id,
        muscleActivations: _readMuscleActivations(args),
        resistanceIntensities: _readMuscleIntensities(
          args,
          'resistance_intensities',
        ),
        stretchIntensities: _readMuscleIntensities(args, 'stretch_intensities'),
        exerciseType: exerciseType,
        availableHandles: handles?.isEmpty == true ? null : handles,
      );
    } catch (e) {
      return {'error': 'Could not create exercise: $e'};
    }

    final created = _wp.allExercises.firstWhere((e) => e.name == name);
    return {
      'created': true,
      'exercise_id': created.id,
      'exercise_name': name,
      'category': category,
      'primary_muscle': muscle.name,
      'muscle_activations': _activationSummary(created),
      ..._resistanceResult(created),
      'stretch_intensities': [
        for (final e in (created.stretchIntensities ?? <String, int>{}).entries)
          {'muscle': e.key, 'intensity': e.value},
      ],
      'activation_interpretation':
          'Estimated involvement, not measured activation or growth.',
      'exercise_type': exerciseType.name,
      if (handles != null && handles.isNotEmpty) 'available_handles': handles,
    };
  }

  Future<Map<String, Object?>> _updateExercise(
    Map<String, Object?> args,
  ) async {
    final name = (args['exercise_name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return {'error': 'exercise_name cannot be empty.'};

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

    final newName = (args['new_name'] as String?)?.trim();
    final category = (args['category'] as String?)?.trim().toLowerCase();
    if (category != null &&
        category.isNotEmpty &&
        category != 'compound' &&
        category != 'isolation') {
      return {
        'error': 'category must be "compound" or "isolation", got "$category".',
      };
    }

    String? primaryMuscleId;
    String? primaryMuscleName;
    final muscleName = (args['primary_muscle'] as String?)?.trim();
    if (muscleName != null && muscleName.isNotEmpty) {
      try {
        final resolved = _resolveMuscleGroup(muscleName);
        if (resolved == null) {
          return {
            'error': 'No muscle group found matching "$muscleName".',
            'available_muscles': [for (final m in _wp.muscleGroups) m.name],
          };
        }
        primaryMuscleId = resolved.id;
        primaryMuscleName = resolved.name;
      } on AmbiguousMatchException catch (e) {
        return {
          'error': 'Multiple muscle groups match "$muscleName". Did you mean:',
          'ambiguous_matches': e.candidates,
        };
      }
    }

    ExerciseType? exerciseType;
    if (args.containsKey('exercise_type')) {
      final typeStr = (args['exercise_type'] as String?)?.trim();
      if (typeStr == null ||
          typeStr.isEmpty ||
          (typeStr != 'timeBased' && typeStr != 'weightAndReps')) {
        return {
          'error':
              'Invalid exercise_type "$typeStr". Allowed values are "weightAndReps" or "timeBased".',
        };
      }
      exerciseType = typeStr == 'timeBased'
          ? ExerciseType.timeBased
          : ExerciseType.weightAndReps;
    }

    List<String>? availableHandles;
    if (args.containsKey('available_handles')) {
      final handlesList = (args['available_handles'] as List?)
          ?.map((h) => h.toString().trim())
          .where((h) => h.isNotEmpty)
          .toList();
      availableHandles = handlesList;
    }

    try {
      final updated = await _wp.updateExercise(
        id: exercise.id,
        name: (newName != null && newName.isNotEmpty) ? newName : null,
        category: (category != null && category.isNotEmpty) ? category : null,
        primaryMuscleGroupId: primaryMuscleId,
        muscleActivations: _readMuscleActivations(args),
        resistanceIntensities: _readMuscleIntensities(
          args,
          'resistance_intensities',
        ),
        stretchIntensities: _readMuscleIntensities(args, 'stretch_intensities'),
        exerciseType: exerciseType,
        availableHandles: availableHandles,
      );

      return {
        'updated': true,
        'exercise_id': updated.id,
        'exercise_name': updated.name,
        'category': updated.category,
        'primary_muscle':
            primaryMuscleName ?? _wp.getMuscleGroupName(updated.primaryMuscle),
        'muscle_activations': _activationSummary(updated),
        ..._resistanceResult(updated),
        'stretch_intensities': [
          for (final e
              in (updated.stretchIntensities ?? <String, int>{}).entries)
            {'muscle': e.key, 'intensity': e.value},
        ],
        'activation_interpretation':
            'Estimated involvement, not measured activation or growth.',
        'exercise_type': updated.exerciseType.name,
        'available_handles': updated.availableHandles,
      };
    } catch (e) {
      return {'error': 'Could not update exercise: $e'};
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, Object?> _resistanceResult(Exercise exercise) => {
    'resistance_reference': exercise.resistanceIntensities,
    if (exercise.resistanceIntensities.values.every(
      (score) => score >= 1 && score <= 10 && score == score.round(),
    ))
      'resistance_intensities': [
        for (final entry in exercise.resistanceIntensities.entries)
          {'muscle': entry.key, 'intensity': entry.value.toInt()},
      ],
  };

  Map<String, int>? _readMuscleIntensities(
    Map<String, Object?> args,
    String field,
  ) {
    if (!args.containsKey(field)) return null;
    final input = args[field];
    if (input == null) return null;
    if (input is! List) throw ArgumentError('$field must be a list.');
    final scores = <String, int>{};
    for (final item in input) {
      if (item is! Map ||
          item['muscle'] is! String ||
          item['intensity'] is! int ||
          (item['intensity'] as int) < 1 ||
          (item['intensity'] as int) > 10) {
        throw ArgumentError(
          '$field requires muscle names and integer intensity scores from 1 to 10.',
        );
      }
      final muscle = _resolveMuscleGroup((item['muscle'] as String).trim());
      if (muscle == null) throw ArgumentError('Unknown muscle in $field.');
      if (scores.containsKey(muscle.id)) {
        throw ArgumentError('Duplicate muscle in $field.');
      }
      scores[muscle.id] = item['intensity'] as int;
    }
    return scores;
  }

  List<MuscleActivation>? _readMuscleActivations(Map<String, Object?> args) {
    if (!args.containsKey('muscle_activations')) return null;
    final raw = args['muscle_activations'];
    if (raw == null) return null;
    if (raw is! List || raw.isEmpty) {
      throw ArgumentError('muscle_activations must be a nonempty list');
    }
    return raw.map((entry) {
      if (entry is! Map ||
          entry['muscle'] is! String ||
          entry['activation_percentage'] is! int) {
        throw ArgumentError(
          'Each activation requires a muscle and an integer weight',
        );
      }
      final name = (entry['muscle'] as String).trim();
      final MuscleGroup? muscle;
      try {
        muscle = _resolveMuscleGroup(name);
      } on AmbiguousMatchException catch (e) {
        throw ArgumentError(
          'Ambiguous muscle "$name": ${e.candidates.join(", ")}',
        );
      }
      if (muscle == null) throw ArgumentError('Unknown muscle "$name"');
      return MuscleActivation(
        muscleGroupId: muscle.id,
        activationPercentage: entry['activation_percentage'] as int,
      );
    }).toList();
  }

  List<Map<String, Object?>> _activationSummary(Exercise exercise) => [
    for (final activation in exercise.muscleActivations)
      {
        'muscle_id': activation.muscleGroupId,
        'muscle':
            MuscleGroups.names[activation.muscleGroupId] ??
            _wp.getMuscleGroupName(activation.muscleGroupId),
        'role': activation.muscleGroupId == exercise.primaryMuscle
            ? 'primary'
            : 'secondary',
        'activation_percentage': activation.activationPercentage,
      },
  ];

  /// Per-session weight×reps breakdown for [exerciseId], newest first.
  /// Bounded to the most recent [limit] sessions (after the optional [cutoff])
  /// to keep the tool payload small.
  List<Map<String, Object?>> _setHistory(
    String exerciseId,
    DateTime? cutoff,
    int limit, {
    bool oldestFirst = false,
    Map<String, List<WorkoutSession>>? sessionIndex,
  }) {
    final Iterable<WorkoutSession> sessions;
    if (sessionIndex != null) {
      final indexed = sessionIndex[exerciseId] ?? const <WorkoutSession>[];
      sessions = oldestFirst ? indexed : indexed.reversed;
    } else {
      final matching =
          _wp.sessions
              .where((s) => cutoff == null || !s.date.isBefore(cutoff))
              .where((s) => s.exercises.any((e) => e.exerciseId == exerciseId))
              .toList()
            ..sort(
              (a, b) => oldestFirst
                  ? a.date.compareTo(b.date)
                  : b.date.compareTo(a.date),
            );
      sessions = matching;
    }

    return [
      for (final s in sessions.take(limit))
        {
          'date': _d(s.date),
          'sets': [
            for (final log in s.exercises.where(
              (e) => e.exerciseId == exerciseId,
            ))
              for (final set in log.sets)
                {
                  'weight': _round(set.weight),
                  'reps': set.reps,
                  'handle': set.handle ?? log.handle,
                  'weight_unit': 'kg',
                  'load_mode': set.loadMode.name,
                  'load_encoding_version': set.loadEncodingVersion,
                  if (set.assistWeight != null)
                    'assist_weight': set.assistWeight,
                  if (set.extraWeight != null) 'extra_weight': set.extraWeight,
                  if (set.bodyWeightAtLog != null)
                    'body_weight_at_log': set.bodyWeightAtLog,
                  if (set.timeTaken != null && set.timeTaken! > 0)
                    'duration_seconds': set.timeTaken,
                  if (set.isDropset) 'dropset': true,
                  if (set.isDropset && set.drops != null)
                    'drops': [
                      for (final d in set.drops!)
                        {'weight': _round(d.weight), 'reps': d.reps},
                    ],
                },
          ],
        },
    ];
  }

  Map<String, String>? _parseExerciseHandles(Object? handlesArg) {
    if (handlesArg == null) return null;
    final map = <String, String>{};
    if (handlesArg is List) {
      for (final item in handlesArg) {
        if (item is Map) {
          final name = item['exercise_name']?.toString().trim();
          final handle = item['handle']?.toString().trim();
          if (name != null && name.isNotEmpty && handle != null) {
            map[name] = handle;
          }
        }
      }
    } else if (handlesArg is Map) {
      for (final entry in handlesArg.entries) {
        map[entry.key.toString().trim()] = entry.value.toString().trim();
      }
    }
    return map;
  }

  Exercise? _resolveExercise(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;
    final all = _wp.allExercises;
    for (final e in all) {
      if (e.id.toLowerCase() == q) return e;
    }
    final exact = [
      for (final e in all)
        if (e.name.toLowerCase() == q) e,
    ];
    if (exact.length == 1) return exact.single;
    if (exact.length > 1) {
      throw AmbiguousMatchException([
        for (final e in exact) '${e.name} (ID: ${e.id})',
      ]);
    }
    final partials = [
      for (final e in all)
        if (e.name.toLowerCase().contains(q)) e,
    ];
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
      for (final r in _wp.routines)
        if (r.name.toLowerCase().contains(q)) r,
    ];
    if (partials.isEmpty) return null;
    if (partials.length == 1) return partials.first;
    throw AmbiguousMatchException([for (final r in partials) r.name]);
  }

  MuscleGroup? _resolveMuscleGroup(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;
    final groups = _wp.muscleGroups.isNotEmpty
        ? _wp.muscleGroups
        : MuscleGroups.getAll();
    for (final m in groups) {
      if (m.name.toLowerCase() == q || m.id.toLowerCase() == q) return m;
    }
    final partials = [
      for (final m in groups)
        if (m.name.toLowerCase().contains(q) || m.id.toLowerCase().contains(q))
          m,
    ];
    if (partials.isEmpty) return null;
    if (partials.length == 1) return partials.first;
    throw AmbiguousMatchException([for (final m in partials) m.name]);
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

  /// Read an optional numeric arg (defaults to the `limit` key), clamped to
  /// [1, max]; [fallback] when absent. Reused by any tool that accepts a
  /// model-supplied bound (e.g. `limit`, `days`) to prevent runaway loops.
  int _limitArg(
    Map<String, Object?> args,
    int fallback, {
    String key = 'limit',
    int max = 40,
  }) {
    final n = (args[key] as num?)?.toInt();
    if (n == null) return fallback;
    return n.clamp(1, max);
  }
}
