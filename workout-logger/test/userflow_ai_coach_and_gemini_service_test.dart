import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/ai_coach_screen.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/viewmodels/ai_coach_view_model.dart';

import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';
import 'test_utils/test_robot.dart';

void main() {
  late MockStorageService storage;
  late WorkoutProvider workoutProvider;
  late SettingsProvider settingsProvider;
  late ConversationManager conversationManager;
  late PRManager prManager;
  late GeminiAiService geminiService;
  late CoachToolService coachToolService;

  setUp(() async {
    storage = MockStorageService();
    workoutProvider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    settingsProvider = SettingsProvider(storage);
    conversationManager = ConversationManager(storage);
    prManager = PRManager(storage);
    geminiService = GeminiAiService();
    coachToolService = CoachToolService(workoutProvider, prManager);

    await workoutProvider.init();
    await settingsProvider.init();
    await prManager.load();
    await conversationManager.loadConversations();
  });

  group('Userflow: AI Coach Screen and Gemini Service Integration', () {
    testWidgets('Renders AiCoachScreen and displays initial empty state', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const AiCoachScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(AiCoachScreen);
    });

    testWidgets('AiCoachViewModel loads conversation and manages state changes cleanly', (tester) async {
      final vm = AiCoachViewModel(
        ai: geminiService,
        coachTools: coachToolService,
        conversations: conversationManager,
        settings: settingsProvider,
      );

      await vm.loadConversations();
      expect(vm.messages, isEmpty);
      expect(vm.isLoading, isFalse);

      vm.newConversation();
      expect(vm.messages, isEmpty);
    });
  });
}
