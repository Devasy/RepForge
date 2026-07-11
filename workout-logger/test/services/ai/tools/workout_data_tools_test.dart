import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/ai/tools/agent_tool.dart';
import 'package:repforge/services/ai/tools/builtins/workout_data_tools.dart';

class FakeCoachToolService implements CoachToolService {
  @override
  Map<String, Object?> exercisePerformance(Map<String, Object?> args) => {'res': 'data'};
  
  @override
  Map<String, Object?> workoutsInRange(Map<String, Object?> args) => {'res': 'data'};

  @override
  Map<String, Object?> routinePerformance(Map<String, Object?> args) => {'res': 'data'};

  @override
  Map<String, Object?> personalRecords(Map<String, Object?> args) => {'res': 'data'};

  @override
  Map<String, Object?> goalProgress(Map<String, Object?> args) => {'res': 'data'};

  @override
  Map<String, Object?> muscleRecovery() => {'res': 'data'};

  @override
  Map<String, Object?> getAllRoutines() => {'res': 'data'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('WorkoutDataTools', () {
    late FakeCoachToolService mockService;

    setUp(() {
      mockService = FakeCoachToolService();
    });

    test('GetExercisePerformanceTool calls service', () async {
      final tool = GetExercisePerformanceTool(mockService);
      expect(tool.id, 'get_exercise_performance');
      final result = await tool.execute(ToolExecutionContext(args: {'exercise_name': 'Bench Press'}, callId: '1'));
      expect(result.data['res'], 'data');
    });

    test('GetWorkoutsInRangeTool calls service', () async {
      final tool = GetWorkoutsInRangeTool(mockService);
      expect(tool.id, 'get_workouts_in_range');
      final result = await tool.execute(ToolExecutionContext(args: {'range': 'last_week'}, callId: '1'));
      expect(result.data['res'], 'data');
    });

    test('GetRoutinePerformanceTool calls service', () async {
      final tool = GetRoutinePerformanceTool(mockService);
      expect(tool.id, 'get_routine_performance');
      final result = await tool.execute(ToolExecutionContext(args: {'routine': 'PPL'}, callId: '1'));
      expect(result.data['res'], 'data');
    });

    test('GetPersonalRecordsTool calls service', () async {
      final tool = GetPersonalRecordsTool(mockService);
      expect(tool.id, 'get_personal_records');
      final result = await tool.execute(ToolExecutionContext(args: {'exercise': 'Squat'}, callId: '1'));
      expect(result.data['res'], 'data');
    });

    test('GetGoalProgressTool calls service', () async {
      final tool = GetGoalProgressTool(mockService);
      expect(tool.id, 'get_goal_progress');
      final result = await tool.execute(ToolExecutionContext(args: {'exercise': 'Squat'}, callId: '1'));
      expect(result.data['res'], 'data');
    });

    test('GetMuscleRecoveryTool calls service', () async {
      final tool = GetMuscleRecoveryTool(mockService);
      expect(tool.id, 'get_muscle_recovery');
      final result = await tool.execute(const ToolExecutionContext(args: {}, callId: '1'));
      expect(result.data['res'], 'data');
    });

    test('GetAllRoutinesTool calls service', () async {
      final tool = GetAllRoutinesTool(mockService);
      expect(tool.id, 'get_all_routines');
      final result = await tool.execute(const ToolExecutionContext(args: {}, callId: '1'));
      expect(result.data['res'], 'data');
    });
  });
}
