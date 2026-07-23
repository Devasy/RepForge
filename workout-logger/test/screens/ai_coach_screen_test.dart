import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/ai_coach_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';

Widget _wrapWithProviders({
  required WorkoutProvider workoutProvider,
  required SettingsProvider settingsProvider,
  required ConversationManager conversationManager,
  required CoachToolService coachToolService,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<GeminiAiService>.value(value: GeminiAiService()),
      Provider<CoachToolService>.value(value: coachToolService),
      ChangeNotifierProvider<ConversationManager>.value(value: conversationManager),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Renders No API Key state when apiKey is not set', (WidgetTester tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();
    final pr = PRManager(storage);
    await pr.load();

    final conv = ConversationManager(storage);
    await conv.init();
    final tools = CoachToolService(workout, pr);

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      settingsProvider: settings,
      conversationManager: conv,
      coachToolService: tools,
      child: const AiCoachScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('AI Coach'), findsOneWidget);
    expect(find.textContaining('API Key'), findsWidgets);
  });

  testWidgets('Renders chat interface when API Key is configured', (WidgetTester tester) async {
    final storage = MockStorageService();
    await storage.saveSetting('geminiApiKey', 'test_api_key_123');

    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();
    final pr = PRManager(storage);
    await pr.load();

    final conv = ConversationManager(storage);
    await conv.init();
    final tools = CoachToolService(workout, pr);

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      settingsProvider: settings,
      conversationManager: conv,
      coachToolService: tools,
      child: const AiCoachScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('AI Coach'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
