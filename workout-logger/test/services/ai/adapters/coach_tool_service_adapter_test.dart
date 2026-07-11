import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/adapters/coach_tool_service_adapter.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';

// Mock dependencies
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/storage_service.dart';
import 'package:repforge/services/managers/program_manager.dart';

class _FakeWorkoutProvider extends WorkoutProvider {
  _FakeWorkoutProvider() : super(
          StorageService(),
          programManager: ProgramManager(StorageService()),
        );
}

class _FakePRManager extends PRManager {
  _FakePRManager() : super(StorageService());
}

void main() {
  group('CoachToolServiceAdapter', () {
    test('buildTools returns all supported tools', () {
      final fakeProvider = _FakeWorkoutProvider();
      final fakePRManager = _FakePRManager();
      final coachService = CoachToolService(fakeProvider, fakePRManager);
      final registry = CoachToolServiceAdapter.buildRegistry(
        coachService,
        includeAskUser: true,
        includeShowGraph: true,
      );

      final tools = registry.tools.toList();
      expect(tools.isNotEmpty, isTrue);

      final toolNames = tools.map((t) => t.id).toList();
      expect(toolNames, contains('ask_user_questions'));
      expect(toolNames, contains('show_graph'));
      // And others from routine_tools and workout_data_tools
      expect(toolNames, contains('get_exercise_performance'));
      expect(toolNames, contains('create_routine'));
    });
  });
}
