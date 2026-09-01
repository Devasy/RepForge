import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/ai_coach_screen.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';

import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';

import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_robot.dart';

void main() {
  late MockStorageService storage;
  late GeminiAiService aiService;
  late WorkoutProvider workoutProvider;
  late PRManager prManager;

  late SettingsProvider settingsProvider;

  setUp(() async {
    storage = MockStorageService();
    aiService = GeminiAiService(storage: storage);
    workoutProvider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    prManager = PRManager(storage);

    settingsProvider = SettingsProvider(storage);

    await workoutProvider.init();
    await prManager.load();
    await settingsProvider.init();
  });

  group('AiCoachScreen Full Suite', () {
    testWidgets('Renders unconfigured no-key state when API key missing', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const AiCoachScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
        geminiAiService: aiService,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(AiCoachScreen);
      expect(find.text('API Key Required'), findsOneWidget);
    });

    testWidgets('Renders configured state and prompt suggestions when API key present', (tester) async {
      final robot = TestRobot(tester);

      aiService.init('valid_mock_api_key');

      await robot.pumpScreen(
        const AiCoachScreen(seedPrompt: 'How can I improve my Bench Press?'),
        storage: storage,
        workoutProvider: workoutProvider,
        geminiAiService: aiService,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(AiCoachScreen);
      expect(find.byType(TextField), findsOneWidget);

      final sendIcon = find.byIcon(Icons.arrow_upward_rounded);
      if (sendIcon.evaluate().isNotEmpty) {
        await tester.tap(sendIcon);
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });
  });
}
