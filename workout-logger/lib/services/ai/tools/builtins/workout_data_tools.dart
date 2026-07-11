// workout_data_tools.dart — Read-only query tools backed by CoachToolService.
//
// Each tool is a self-describing AgentTool that wraps a CoachToolService
// data-access method. Tool declarations (ToolSpec) replace the inline
// FunctionDeclarations that were in CoachToolService.buildTools().

import '../../coach_tool_service.dart';
import '../agent_tool.dart';
import '../tool_metadata.dart';
import '../tool_result.dart';
import '../tool_spec.dart';

// ── GetExercisePerformanceTool ───────────────────────────────────────────────

class GetExercisePerformanceTool implements AgentTool {
  final CoachToolService _service;
  GetExercisePerformanceTool(this._service);

  @override
  String get id => 'get_exercise_performance';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Exercise performance',
        kind: ToolKind.query,
        readOnly: true,
        progressLabel: '{exercise_name} performance',
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'get_exercise_performance',
        description:
            'Get how a specific exercise has progressed: per-session volume '
            'trend, the full per-session weight×reps set history, growth '
            'slope, best estimated 1RM, last logged sets, and personal '
            'record. Use for questions like "how is my bench press '
            'progressing" or "what weight and reps did I do for squats '
            'last month".',
        parameters: {
          'exercise_name': ToolParam.string(
            description: 'Name of the exercise, e.g. "Bench Press" or "Squat".',
          ),
          'days': ToolParam.integer(
            description: 'Optional. Only consider sessions from the last N days.',
            nullable: true,
          ),
          'limit': ToolParam.integer(
            description:
                'Optional. Max number of most-recent sessions to return '
                'in set_history and volume_trend. Use a small value (e.g. '
                '1–5) when you only need recent sessions, to save tokens. '
                'Defaults to 20; capped at 40.',
            nullable: true,
          ),
        },
        required: ['exercise_name'],
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = _service.exercisePerformance(ctx.args);
    return ToolResult(data: data);
  }
}

// ── GetWorkoutsInRangeTool ──────────────────────────────────────────────────

class GetWorkoutsInRangeTool implements AgentTool {
  final CoachToolService _service;
  GetWorkoutsInRangeTool(this._service);

  @override
  String get id => 'get_workouts_in_range';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Workout history',
        kind: ToolKind.query,
        readOnly: true,
        progressLabel: 'Workouts (last {days}d)',
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'get_workouts_in_range',
        description:
            'Summarize workouts in a date range: session count, total volume, '
            'and a per-session breakdown. Use for "what did I do last week" '
            'or "how many workouts in the last 3 months".',
        parameters: {
          'start_date': ToolParam.string(
            description: 'Optional ISO date (YYYY-MM-DD) range start.',
            nullable: true,
          ),
          'end_date': ToolParam.string(
            description: 'Optional ISO date (YYYY-MM-DD) range end.',
            nullable: true,
          ),
          'days': ToolParam.integer(
            description:
                'Optional. Last N days; overrides start/end when set. '
                'Defaults to 30 if no dates are provided.',
            nullable: true,
          ),
          'limit': ToolParam.integer(
            description:
                'Optional. Max number of most-recent sessions to include '
                'in the per-session breakdown. The session_count and '
                'total_volume totals always cover the full range. Use a '
                'small value to save tokens. Defaults to 40; capped at 40.',
            nullable: true,
          ),
        },
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = _service.workoutsInRange(ctx.args);
    return ToolResult(data: data);
  }
}

// ── GetRoutinePerformanceTool ───────────────────────────────────────────────

class GetRoutinePerformanceTool implements AgentTool {
  final CoachToolService _service;
  GetRoutinePerformanceTool(this._service);

  @override
  String get id => 'get_routine_performance';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Routine performance',
        kind: ToolKind.query,
        readOnly: true,
        progressLabel: '{routine_name} routine data',
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'get_routine_performance',
        description:
            'Get how a named routine is performing: number of sessions logged '
            'against it, total volume, volume trend over time, and the '
            'exercises it contains.',
        parameters: {
          'routine_name': ToolParam.string(
            description: 'Name of the routine, e.g. "Push Day".',
          ),
          'days': ToolParam.integer(
            description: 'Optional. Only consider sessions from the last N days.',
            nullable: true,
          ),
          'limit': ToolParam.integer(
            description:
                'Optional. Max number of most-recent points to include in '
                'volume_over_time. session_count and total_volume always '
                'cover all matching sessions. Defaults to 40; capped at 40.',
            nullable: true,
          ),
        },
        required: ['routine_name'],
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = _service.routinePerformance(ctx.args);
    return ToolResult(data: data);
  }
}

// ── GetPersonalRecordsTool ──────────────────────────────────────────────────

class GetPersonalRecordsTool implements AgentTool {
  final CoachToolService _service;
  GetPersonalRecordsTool(this._service);

  @override
  String get id => 'get_personal_records';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Personal records',
        kind: ToolKind.query,
        readOnly: true,
        progressLabel: '{exercise_name} PR',
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'get_personal_records',
        description:
            'Get personal records (best weight, reps, and single-set volume). '
            'Pass an exercise name for one exercise, or omit for all PRs.',
        parameters: {
          'exercise_name': ToolParam.string(
            description: 'Optional exercise name to filter to.',
            nullable: true,
          ),
        },
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = _service.personalRecords(ctx.args);
    return ToolResult(data: data);
  }
}

// ── GetGoalProgressTool ─────────────────────────────────────────────────────

class GetGoalProgressTool implements AgentTool {
  final CoachToolService _service;
  GetGoalProgressTool(this._service);

  @override
  String get id => 'get_goal_progress';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Goal progress',
        kind: ToolKind.query,
        readOnly: true,
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'get_goal_progress',
        description:
            'Get progress toward training goals/targets: current vs target '
            'value, percent complete, and estimated completion date.',
        parameters: {
          'exercise_name': ToolParam.string(
            description: 'Optional exercise name to filter goals to.',
            nullable: true,
          ),
        },
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = _service.goalProgress(ctx.args);
    return ToolResult(data: data);
  }
}

// ── GetMuscleRecoveryTool ───────────────────────────────────────────────────

class GetMuscleRecoveryTool implements AgentTool {
  final CoachToolService _service;
  GetMuscleRecoveryTool(this._service);

  @override
  String get id => 'get_muscle_recovery';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Muscle recovery status',
        kind: ToolKind.query,
        readOnly: true,
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'get_muscle_recovery',
        description:
            'Get current per-muscle-group recovery status (percent recovered '
            'and whether each is ready, recovering, or fatigued). Use for '
            '"what can I train today".',
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = _service.muscleRecovery();
    return ToolResult(data: data);
  }
}

// ── GetAllRoutinesTool ──────────────────────────────────────────────────────

class GetAllRoutinesTool implements AgentTool {
  final CoachToolService _service;
  GetAllRoutinesTool(this._service);

  @override
  String get id => 'get_all_routines';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'All routines',
        kind: ToolKind.query,
        readOnly: true,
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'get_all_routines',
        description:
            'List all saved routines with their exercise names and count. '
            'Use when the user asks what routines they have or wants to '
            'pick one to view or modify.',
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = _service.getAllRoutines();
    return ToolResult(data: data);
  }
}
