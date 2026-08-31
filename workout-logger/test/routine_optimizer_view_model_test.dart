
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/ai/provider/model_step.dart';
import 'package:repforge/services/ai/runtime/agent_policies.dart';
import 'package:repforge/services/ai/runtime/agent_runtime.dart';
import 'package:repforge/services/ai/tools/tool_registry.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/viewmodels/routine_optimizer_view_model.dart';
import 'test_utils/fake_model_runtime.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  group('RoutineOptimizerViewModel', () {
    test('startForRoutine sends seed prompt', () async {
      final storage = MockStorageService();
      final conversations = ConversationManager(storage, kind: 'optimizer');
      final settings = SettingsProvider(storage);
      await settings.init();

      final fakeAi = FakeModelRuntime(steps: [
        const ModelTextDelta('Ready to optimize.'),
        const ModelFinish('stop'),
      ]);

      final runtime = DefaultAgentRuntime(
        model: fakeAi,
        tools: const ToolRegistry.empty(),
        policies: const AgentPolicies(maxModelSteps: 1),
      );

      final vm = RoutineOptimizerViewModel(
        runtime: runtime,
        conversations: conversations,
        settings: settings,
      );

      final routine = Routine(
        id: '1',
        name: 'Push Day',
        exerciseIds: const [],
        createdAt: DateTime.now(),
      );

      await vm.startForRoutine(routine);

      expect(vm.messages.length, 2);
      expect(vm.messages[0].text, contains('Optimize my "Push Day" routine'));
      expect(vm.messages[0].role, 'user');
      expect(vm.messages[1].text, 'Ready to optimize.');
      expect(vm.messages[1].role, 'model');
    });
  });
}
