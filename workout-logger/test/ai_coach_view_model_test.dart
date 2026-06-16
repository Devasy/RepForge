// Unit tests for AiCoachViewModel — verifies orchestration (send → stream →
// persist) using a fake IAiService, so the View has no logic left to test.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, Tool, FunctionCall;
import 'package:repforge/models/models.dart';
import 'package:repforge/services/interfaces/ai_service_interface.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/viewmodels/ai_coach_view_model.dart';
import 'test_utils/mock_storage_service.dart';

/// Scripted IAiService: yields fixed chunks; optionally invokes a tool first.
class _FakeAiService implements IAiService {
  _FakeAiService({this.chunks = const ['Hello ', 'world'], this.invokeTool = false});

  final List<String> chunks;
  final bool invokeTool;
  int toolCallsMade = 0;

  @override
  bool get isConfigured => true;

  @override
  String get currentModel => 'fake-model';

  @override
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  }) async* {
    if (invokeTool && onToolCall != null) {
      await onToolCall(FunctionCall('get_muscle_recovery', {}));
      toolCallsMade++;
    }
    for (final c in chunks) {
      yield c;
    }
  }

  @override
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  }) =>
      throw UnimplementedError();

  @override
  Future<String> generateWeeklyInsights(String contextText) async => '';

  @override
  Future<String> generateInsight(String system, String context) async => '';

}

void main() {
  group('AiCoachViewModel', () {
    late MockStorageService storage;
    late WorkoutProvider provider;
    late ConversationManager conversations;
    late SettingsProvider settings;
    late PRManager pr;

    Future<AiCoachViewModel> buildVm(_FakeAiService ai) async {
      provider = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await provider.init();
      pr = PRManager(storage);
      settings = SettingsProvider(storage);
      conversations = ConversationManager(storage);
      return AiCoachViewModel(
        ai: ai,
        coachTools: CoachToolService(provider, pr),
        conversations: conversations,
        settings: settings,
      );
    }

    setUp(() {
      storage = MockStorageService();
    });

    test('sendMessage appends user + model messages and persists', () async {
      final vm = await buildVm(_FakeAiService());

      await vm.sendMessage('How am I doing?');

      expect(vm.messages, hasLength(2));
      expect(vm.messages[0].role, 'user');
      expect(vm.messages[0].text, 'How am I doing?');
      expect(vm.messages[1].role, 'model');
      expect(vm.messages[1].text, 'Hello world');
      expect(vm.isLoading, isFalse);
      expect(vm.streamingText, isEmpty);

      // Persisted.
      final stored = await storage.getAllConversations();
      expect(stored, hasLength(1));
      expect(stored.first.messages, hasLength(2));
    });

    test('blank or whitespace messages are ignored', () async {
      final vm = await buildVm(_FakeAiService());
      await vm.sendMessage('   ');
      expect(vm.messages, isEmpty);
    });

    test('runs the tool-call loop via CoachToolService', () async {
      final ai = _FakeAiService(invokeTool: true, chunks: const ['done']);
      final vm = await buildVm(ai);

      await vm.sendMessage('what can I train?');

      expect(ai.toolCallsMade, 1);
      expect(vm.messages.last.text, 'done');
    });

    test('newConversation then selectConversation swaps active state',
        () async {
      final vm = await buildVm(_FakeAiService());

      await vm.sendMessage('first chat');
      final firstId = vm.activeConversationId;
      expect(firstId, isNotNull);

      vm.newConversation();
      expect(vm.messages, isEmpty);

      await vm.sendMessage('second chat');
      final secondId = vm.activeConversationId;
      expect(secondId, isNot(firstId));
      expect(vm.conversations, hasLength(2));

      vm.selectConversation(firstId!);
      expect(vm.activeConversationId, firstId);
      expect(vm.messages.first.text, 'first chat');
    });
  });
}
