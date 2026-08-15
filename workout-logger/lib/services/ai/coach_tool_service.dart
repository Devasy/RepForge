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
import 'sql_query_service.dart';

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
  })  : _wp = workoutProvider,
        _pr = prManager,
        _hh = healthHistory,
        _sql = sqlQuery;

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
            'get_exercise_performance',
            'Get how a specific exercise has progressed: per-session volume '
                'trend, the full per-session weight×reps set history, growth '
                'slope, best estimated 1RM, last logged sets, and personal '
                'record. Use for questions like "how is my bench press '
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
          FunctionDeclaration(
            'add_custom_exercise',
            'Create a new custom exercise in the catalogue when the one the user '
                'wants does not already exist. Match the muscle to an existing '
                'muscle group (call get_muscle_recovery or list routines first '
                'if unsure of the available muscle names). After creating it you '
                'can reference it by name in create_routine / update_routine.',
            Schema.object(
              properties: {
                'name': Schema.string(
                  description: 'Name of the new exercise, e.g. "Cable Crossover".',
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
              },
              requiredProperties: ['name', 'category', 'primary_muscle'],
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
                  description: 'Optional. Number of days to look back (defaults to 30).',
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
                  description: 'Health metric, e.g. "sleep_hours", "deep_sleep_min".',
                ),
                'y_metric': Schema.string(
                  description: 'Workout metric, e.g. "workout_volume", "session_duration", "exercise_max_weight".',
                ),
                'exercise_name': Schema.string(
                  description: 'Optional. Specific exercise name if y_metric is "exercise_max_weight".',
                  nullable: true,
                ),
                'days': Schema.integer(
                  description: 'Optional. Number of days to consider (defaults to 60).',
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
                  description: 'Optional. Number of days to analyze (defaults to 14).',
                  nullable: true,
                ),
              },
            ),
          ),
          if (_sql != null) _runSqlQueryDeclaration,
        ]),
      ];

  /// Schema-aware declaration for run_sql_query — only included when a
  /// SqlQueryService is wired (i.e. the app has cut over to SQLite).
  FunctionDeclaration get _runSqlQueryDeclaration => FunctionDeclaration(
        'run_sql_query',
        'Run a read-only SQL SELECT query directly against the workout database '
            'for questions the other tools cannot answer (custom joins, filters, '
            'or aggregations). Tables:\n'
            'sessions(id, date, routine_id, duration_min, notes, hc_synced_at)\n'
            'exercise_logs(id, session_id, exercise_id, notes, handle)\n'
            'sets(id, exercise_log_id, weight, reps, is_dropset, drops_json, '
            'time_taken, timestamp, assist_weight, extra_weight, handle)\n'
            'exercises(id, name, category, is_custom, available_handles) — custom '
            'exercises only; built-ins are not stored here\n'
            'muscle_groups(id, name, growth_rate, last_updated)\n'
            'exercise_muscle_activations(exercise_id, muscle_group_id, activation_percentage)\n'
            'routines(id, name, created_at)\n'
            'routine_exercises(routine_id, exercise_id, position)\n'
            'targets(id, exercise_id, target_type, target_value, current_value, '
            'estimated_completion_date, created_at, is_completed)\n'
            'personal_records(exercise_id, best_weight, best_reps, best_volume, achieved_at)\n'
            'health_samples(id, type, timestamp, value) — type is heart_rate | '
            'resting_heart_rate | hrv_rmssd; one row per Health Connect sample\n'
            'sleep_sessions(id, start_ts, end_ts, light_min, deep_min, rem_min, '
            'awake_min) — one row per night, id is the session start_ts\n'
            'sleep_stage_intervals(sleep_session_id, start_ts, end_ts, stage) — '
            'stage is deep | rem | light | awake\n'
            'When joining tables, select explicit columns with aliases (e.g. s.id AS '
            'session_id, l.id AS log_id) instead of SELECT *, since duplicate column '
            'names across joined tables will silently collide.\n'
            'Only SELECT/WITH statements are allowed, one statement per call.',
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
    switch (call.name) {
      case 'get_sleeping_hr_analytics':
        return await _getSleepingHrAnalytics(call.args);
      case 'get_health_metrics':
        return await _getHealthMetrics(call.args);
      case 'analyze_health_workout_correlation':
        return await _analyzeHealthWorkoutCorrelation(call.args);
      case 'get_muscle_group_volume':
        return _muscleGroupVolume(call.args);
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
      Map<String, Object?> args) async {
    final hh = _hh;
    if (hh == null) {
      return {
        'error':
            'Health Connect integration is not active or HealthHistoryManager unavailable.'
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

          final varSum =
              avgs.fold(0.0, (sum, x) => sum + (x - meanBpm) * (x - meanBpm));
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
        'error': 'No sleeping heart rate records found in the last $days days.'
      };
    }

    final p5Mean = p5List.reduce((a, b) => a + b) / p5List.length;
    final p5VarSum =
        p5List.fold(0.0, (sum, x) => sum + (x - p5Mean) * (x - p5Mean));
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

    final trendDirection =
        slope < -0.1 ? 'improving' : (slope > 0.1 ? 'elevated' : 'stable');

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

  Future<Map<String, Object?>> _getHealthMetrics(Map<String, Object?> args) async {
    final hh = _hh;
    if (hh == null) {
      return {'error': 'Health Connect integration is not active or HealthHistoryManager unavailable.'};
    }
    final days = _limitArg(args, 30, key: 'days', max: 31);
    final now = DateTime.now();
    // Week granularity only covers the last 7 days; anything wider needs the
    // month bucket. Both return per-night bars, so trim to the exact window.
    final granularity =
        days <= 7 ? HealthGranularity.week : HealthGranularity.month;
    final allBars = await hh.sleepBars(now, granularity);
    final bars =
        allBars.length > days ? allBars.sublist(allBars.length - days) : allBars;

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
          }
      ],
    };
  }

  Future<Map<String, Object?>> _analyzeHealthWorkoutCorrelation(
      Map<String, Object?> args) async {
    final xMetric = (args['x_metric'] as String?)?.trim() ?? 'sleep_hours';
    final yMetric = (args['y_metric'] as String?)?.trim() ?? 'workout_volume';
    final exName = (args['exercise_name'] as String?)?.trim();
    final days = (args['days'] as num?)?.toInt() ?? 60;

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final sessions = _wp.sessions.where((s) => !s.date.isBefore(cutoff)).toList();

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
            vol += (set.weight * set.reps);
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
      final bars = await hh.sleepBars(DateTime.now(), HealthGranularity.week);
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
      return {'error': 'Insufficient paired data points for correlation analysis.'};
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
    final r = (xVarSum > 0 && yVarSum > 0) ? (covSum / math.sqrt(xVarSum * yVarSum)) : 0.0;

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
      'trendline': {
        'slope': _round(slope),
        'intercept': _round(intercept),
      },
      'points': points,
    };
  }

  Map<String, Object?> _muscleGroupVolume(Map<String, Object?> args) {
    final rawGroups = (args['muscle_groups'] as List?)?.cast<String>() ?? [];
    final days = (args['days'] as num?)?.toInt() ?? 60;
    final cutoff = DateTime.now().subtract(Duration(days: days));

    final allExercises = _wp.allExercises;
    final allSessions = _wp.sessions
        .where((s) => !s.date.isBefore(cutoff))
        .toList()
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
          .where((e) => e.muscleActivations.any((m) => m.muscleGroupId == targetId))
          .map((e) => e.id)
          .toSet();

      for (final session in allSessions) {
        final dateKey = _d(session.date);
        var groupVol = 0.0;
        for (final exLog in session.exercises) {
          if (matchingExerciseIds.contains(exLog.exerciseId)) {
            for (final set in exLog.sets) {
              groupVol += (set.weight * set.reps);
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
      series.add({
        'name': groupName,
        'values': values,
      });
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

  Map<String, Object?> _exercisePerformance(Map<String, Object?> args) {
    final name = (args['exercise_name'] as String?)?.trim() ?? '';
    final days = (args['days'] as num?)?.toInt();

    final Exercise exercise;
    try {
      final resolved = _resolveExercise(name);
      if (resolved == null) {
        // Fallback: check if the prompt queried a muscle group (e.g., "biceps", "triceps")
        final muscleRes = _muscleGroupVolume({'muscle_groups': [name], 'days': days ?? 60});
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

    final cutoff =
        days != null ? DateTime.now().subtract(Duration(days: days)) : null;

    final progression = _wp
        .getVolumeProgression(exercise.id)
        .where((p) => cutoff == null || !p.date.isBefore(cutoff))
        .toList();

    final growth = _wp.getGrowthModel(exercise.id);
    final lastLog = _wp.getLastSessionForExercise(exercise.id);
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
      'volume_trend': [
        for (final p in progression.length > trendCap
            ? progression.sublist(progression.length - trendCap)
            : progression)
          {'date': _d(p.date), 'volume': _round(p.volume)},
      ],
      // Per-session weight×reps breakdown (most recent first), so the model can
      // answer "what weight/reps did I do" rather than only volume totals.
      'set_history': _setHistory(exercise.id, cutoff, setCap),
      'growth': growth == null
          ? null
          : {
              'slope_per_day': _round(growth.slope),
              'weekly_growth_percent': _round(growth.weeklyGrowthPercent),
              'curve': growth.curve.name,
              'r2': _round(growth.r2),
              'trend': growth.weeklyGrowthPercent > 0.5
                  ? 'improving'
                  : growth.weeklyGrowthPercent < -2
                      ? 'declining'
                      : 'plateauing',
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
      'window_days': ?days,
      'total_volume': _round(totalVolume),
      'volume_over_time': [
        for (final s in sessions.length > _limitArg(args, 40)
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

  Future<Map<String, Object?>> _addCustomExercise(
      Map<String, Object?> args) async {
    final name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return {'error': 'Exercise name cannot be empty.'};

    // Reject duplicates so the model reuses the existing exercise instead.
    final existing = _wp.allExercises.where(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      return {
        'error': 'An exercise named "${existing.first.name}" already exists. '
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

    try {
      await _wp.addCustomExercise(
        name: name,
        category: category,
        primaryMuscleGroupId: muscle.id,
      );
    } catch (e) {
      return {'error': 'Could not create exercise: $e'};
    }

    return {
      'created': true,
      'exercise_name': name,
      'category': category,
      'primary_muscle': muscle.name,
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Per-session weight×reps breakdown for [exerciseId], newest first.
  /// Bounded to the most recent [limit] sessions (after the optional [cutoff])
  /// to keep the tool payload small.
  List<Map<String, Object?>> _setHistory(
      String exerciseId, DateTime? cutoff, int limit) {
    final sessions = _wp.sessions
        .where((s) => cutoff == null || !s.date.isBefore(cutoff))
        .where((s) => s.exercises.any((e) => e.exerciseId == exerciseId))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return [
      for (final s in sessions.take(limit))
        {
          'date': _d(s.date),
          'sets': [
            for (final log in s.exercises.where((e) => e.exerciseId == exerciseId))
              for (final set in log.sets)
                {
                  'weight': _round(set.weight),
                  'reps': set.reps,
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

  MuscleGroup? _resolveMuscleGroup(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;
    for (final m in _wp.muscleGroups) {
      if (m.name.toLowerCase() == q) return m;
    }
    final partials = [
      for (final m in _wp.muscleGroups) if (m.name.toLowerCase().contains(q)) m
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
  int _limitArg(Map<String, Object?> args, int fallback,
      {String key = 'limit', int max = 40}) {
    final n = (args[key] as num?)?.toInt();
    if (n == null) return fallback;
    return n.clamp(1, max);
  }
}
