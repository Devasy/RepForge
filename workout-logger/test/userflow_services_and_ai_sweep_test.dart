import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/gemini_context_builder.dart';
import 'package:repforge/services/health_connect_service.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';

import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

void main() {
  late MockStorageService storage;
  late WorkoutProvider workoutProvider;
  late SettingsProvider settingsProvider;
  late PRManager prManager;
  late GeminiAiService geminiService;
  late CoachToolService coachToolService;
  late HealthConnectService healthConnectService;

  setUp(() async {
    storage = MockStorageService();
    settingsProvider = SettingsProvider(storage);
    prManager = PRManager(storage);
    workoutProvider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    geminiService = GeminiAiService(storage: storage);
    coachToolService = CoachToolService(workoutProvider: workoutProvider, prManager: prManager);
    healthConnectService = HealthConnectService();

    await workoutProvider.init();
    await settingsProvider.init();
    await prManager.load();
  });

  group('Deep Service & AI Engine Unit/Integration Sweeps', () {
    test('GeminiAiService lifecycle, token usage, and model selection sweep', () async {
      expect(geminiService.isConfigured, isFalse);
      expect(geminiService.currentModel, equals(kDefaultGeminiModel));
      expect(geminiService.promptTokensUsed, equals(0));
      expect(geminiService.responseTokensUsed, equals(0));

      geminiService.init('fake_test_api_key', model: 'gemini-3.5-flash');
      expect(geminiService.isConfigured, isTrue);
      expect(geminiService.currentModel, equals('gemini-3.5-flash'));

      await geminiService.loadUsage();
      expect(geminiService.totalTokensUsed, equals(0));
    });

    test('CoachToolService tool declaration and tool call execution sweep', () async {
      final prRes = await coachToolService.handleCall(
        FunctionCall('get_personal_records', {}),
      );
      expect(prRes, isNotNull);

      final goalRes = await coachToolService.handleCall(
        FunctionCall('get_goal_progress', {}),
      );
      expect(goalRes, isNotNull);

      final routinesRes = await coachToolService.handleCall(
        FunctionCall('get_all_routines', {}),
      );
      expect(routinesRes, isNotNull);
    });

    test('GeminiContextBuilder prompt context formatting sweep', () {
      final contextText = GeminiContextBuilder.buildCoachSystemPrompt(
        unitLabel: 'kg',
      );

      expect(contextText, isNotEmpty);
      expect(contextText, contains('RepForge'));
    });

    test('HealthConnectService safe stub invocation sweep', () async {
      final isAvailable = await healthConnectService.isAvailable();
      expect(isAvailable, isFalse);

      final hasPermission = await healthConnectService.hasPermissions();
      expect(hasPermission, isFalse);

      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));

      final rhr = await healthConnectService.readRestingHeartRate(start, now);
      expect(rhr, isEmpty);

      final hrv = await healthConnectService.readHrvRmssd(start, now);
      expect(hrv, isEmpty);

      final sleep = await healthConnectService.readSleepSessions(start, now);
      expect(sleep, isEmpty);
    });
  });
}
