// routine_tools.dart — Mutation tools for routine and exercise management.
//
// These tools write data (create/update routines, add exercises).
// They're separated from query tools because their ToolKind is 'mutation'.

import '../../coach_tool_service.dart';
import '../agent_tool.dart';
import '../tool_metadata.dart';
import '../tool_result.dart';
import '../tool_spec.dart';

// ── CreateRoutineTool ───────────────────────────────────────────────────────

class CreateRoutineTool implements AgentTool {
  final CoachToolService _service;
  CreateRoutineTool(this._service);

  @override
  String get id => 'create_routine';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Create routine',
        kind: ToolKind.mutation,
        readOnly: false,
        progressLabel: 'Creating "{name}"',
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'create_routine',
        description:
            'Create a new workout routine with a name and an ordered list of '
            'exercises. Exercises are matched by name from the catalogue.',
        parameters: {
          'name': ToolParam.string(
            description: 'Name for the new routine, e.g. "Push Day".',
          ),
          'exercise_names': ToolParam.array(
            items: ToolParam.string(),
            description: 'Ordered list of exercise names to include in the routine.',
          ),
        },
        required: ['name', 'exercise_names'],
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = await _service.createRoutine(ctx.args);
    return ToolResult(data: data);
  }
}

// ── UpdateRoutineTool ───────────────────────────────────────────────────────

class UpdateRoutineTool implements AgentTool {
  final CoachToolService _service;
  UpdateRoutineTool(this._service);

  @override
  String get id => 'update_routine';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Update routine',
        kind: ToolKind.mutation,
        readOnly: false,
        progressLabel: 'Updating "{routine_name}"',
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'update_routine',
        description:
            'Modify an existing routine: add exercises, remove exercises, or '
            'reorder them. Specify the routine by name. Exercises are '
            'matched by name from the catalogue.',
        parameters: {
          'routine_name': ToolParam.string(
            description: 'Name of the routine to update.',
          ),
          'add_exercise_names': ToolParam.array(
            items: ToolParam.string(),
            description: 'Optional. Exercise names to add.',
            nullable: true,
          ),
          'remove_exercise_names': ToolParam.array(
            items: ToolParam.string(),
            description: 'Optional. Exercise names to remove.',
            nullable: true,
          ),
          'reorder_exercise_names': ToolParam.array(
            items: ToolParam.string(),
            description:
                'Optional. Full new ordering of all exercise names in '
                'the routine. Must include every exercise you want to keep.',
            nullable: true,
          ),
        },
        required: ['routine_name'],
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = await _service.updateRoutine(ctx.args);
    return ToolResult(data: data);
  }
}

// ── AddCustomExerciseTool ───────────────────────────────────────────────────

class AddCustomExerciseTool implements AgentTool {
  final CoachToolService _service;
  AddCustomExerciseTool(this._service);

  @override
  String get id => 'add_custom_exercise';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Add custom exercise',
        kind: ToolKind.mutation,
        readOnly: false,
        progressLabel: 'Adding "{name}"',
      );

  @override
  ToolSpec get spec => const ToolSpec(
        name: 'add_custom_exercise',
        description:
            'Create a new custom exercise in the catalogue when the one the user '
            'wants does not already exist. Match the muscle to an existing '
            'muscle group (call get_muscle_recovery or list routines first '
            'if unsure of the available muscle names). After creating it you '
            'can reference it by name in create_routine / update_routine.',
        parameters: {
          'name': ToolParam.string(
            description: 'Name of the new exercise, e.g. "Cable Crossover".',
          ),
          'category': ToolParam.string(
            description:
                'Either "compound" (multi-joint) or "isolation" (single-joint).',
          ),
          'primary_muscle': ToolParam.string(
            description:
                'Primary muscle group this exercise targets, e.g. "Chest" '
                'or "Biceps". Must match an existing muscle group.',
          ),
        },
        required: ['name', 'category', 'primary_muscle'],
      );

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    final data = await _service.addCustomExercise(ctx.args);
    return ToolResult(data: data);
  }
}
