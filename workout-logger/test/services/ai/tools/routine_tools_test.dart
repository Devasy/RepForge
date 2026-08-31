import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/ai/tools/agent_tool.dart';
import 'package:repforge/services/ai/tools/builtins/routine_tools.dart';

class FakeCoachToolService implements CoachToolService {
  @override
  Future<Map<String, Object?>> createRoutine(Map<String, Object?> args) async {
    return {'res': 'data'};
  }

  @override
  Future<Map<String, Object?>> updateRoutine(Map<String, Object?> args) async {
    return {'res': 'data'};
  }

  @override
  Future<Map<String, Object?>> addCustomExercise(Map<String, Object?> args) async {
    return {'res': 'data'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RoutineTools', () {
    late FakeCoachToolService mockService;

    setUp(() {
      mockService = FakeCoachToolService();
    });

    test('CreateRoutineTool calls service', () async {
      final tool = CreateRoutineTool(mockService);
      expect(tool.id, 'create_routine');
      
      final result = await tool.execute(ToolExecutionContext(args: {'name': 'PPL', 'exercises': []}, callId: '1'));
      expect(result.data['res'], 'data');
    });

    test('UpdateRoutineTool calls service', () async {
      final tool = UpdateRoutineTool(mockService);
      expect(tool.id, 'update_routine');
      
      final result = await tool.execute(ToolExecutionContext(args: {'id': '1', 'name': 'PPL', 'exercises': []}, callId: '1'));
      expect(result.data['res'], 'data');
    });

    test('AddCustomExerciseTool calls service', () async {
      final tool = AddCustomExerciseTool(mockService);
      expect(tool.id, 'add_custom_exercise');
      
      final result = await tool.execute(ToolExecutionContext(args: {'name': 'Curls', 'muscleGroup': 'Biceps'}, callId: '1'));
      expect(result.data['res'], 'data');
    });
  });
}
