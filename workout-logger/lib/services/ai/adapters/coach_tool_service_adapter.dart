// coach_tool_service_adapter.dart — Factory for building a ToolRegistry
// from CoachToolService.
//
// This is the bridge between the existing data-access layer and the new
// typed-tool architecture. It creates a ToolRegistry with all available
// tools backed by CoachToolService.

import '../coach_tool_service.dart';
import '../tools/agent_tool.dart';
import '../tools/tool_registry.dart';
import '../tools/builtins/workout_data_tools.dart';
import '../tools/builtins/routine_tools.dart';
import '../tools/builtins/ask_user_questions_tool.dart';
import '../tools/builtins/show_graph_tool.dart';

class CoachToolServiceAdapter {
  const CoachToolServiceAdapter._();

  /// Build a [ToolRegistry] from a [CoachToolService], with all standard
  /// query and mutation tools.
  ///
  /// Set [includeAskUser] to true for the optimizer flow.
  /// Set [includeShowGraph] to true to enable inline chart visualization.
  static ToolRegistry buildRegistry(
    CoachToolService service, {
    bool includeAskUser = false,
    bool includeShowGraph = false,
  }) {
    final tools = <AgentTool>[
      // Query tools (read-only)
      GetExercisePerformanceTool(service),
      GetWorkoutsInRangeTool(service),
      GetRoutinePerformanceTool(service),
      GetPersonalRecordsTool(service),
      GetGoalProgressTool(service),
      GetMuscleRecoveryTool(service),
      GetAllRoutinesTool(service),

      // Mutation tools
      CreateRoutineTool(service),
      UpdateRoutineTool(service),
      AddCustomExerciseTool(service),

      // Optional tools
      if (includeAskUser) AskUserQuestionsTool(),
      if (includeShowGraph) ShowGraphTool(),
    ];

    return ToolRegistry(tools);
  }
}
