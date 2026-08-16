import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/provider/model_step.dart';
import 'package:repforge/services/ai/runtime/agent_runtime.dart';
import 'package:repforge/services/ai/tools/tool_registry.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/viewmodels/ai_coach_view_model.dart';
import 'test_utils/fake_model_runtime.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  group('AiCoachViewModel', () {
    test('sendMessage runs graph and persists reply', () async {
      final storage = MockStorageService();
      final conversations = ConversationManager(storage);
      final settings = SettingsProvider(storage);
      await settings.init();

      final fakeAi = FakeModelRuntime(steps: [
        const ModelTextDelta('Hello '),
        const ModelTextDelta('world'),
        const ModelFinish('stop'),
      ]);

      final runtime = DefaultAgentRuntime(
        model: fakeAi,
        tools: const ToolRegistry.empty(),
      );

      final vm = AiCoachViewModel(
        runtime: runtime,
        conversations: conversations,
        settings: settings,
      );

      vm.newConversation();
      await vm.sendMessage('test message');

      expect(vm.messages.length, 2);
      expect(vm.messages[0].text, 'test message');
      expect(vm.messages[0].role, 'user');
      expect(vm.messages[1].text, 'Hello world');
      expect(vm.messages[1].role, 'model');
    });
  });
}
