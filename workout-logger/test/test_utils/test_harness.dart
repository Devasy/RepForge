// test_harness.dart — Unified MultiProvider wrapper and viewport manager for widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/api_service.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/managers/health_history_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/readiness_manager.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import 'mock_storage_service.dart';
import 'mock_ml_service.dart';
import 'stub_health_connect_service.dart';

class TestHarness {
  /// Builds a fully-loaded MultiProvider widget tree for testing any Flutter screen or widget.
  static Widget wrap(
    Widget child, {
    MockStorageService? storage,
    WorkoutProvider? workoutProvider,
    SettingsProvider? settingsProvider,
    HistoryManager? historyManager,
    HealthHistoryManager? healthHistoryManager,
    ReadinessManager? readinessManager,
    Size viewportSize = const Size(1080, 2400),
  }) {
    final mockStorage = storage ?? MockStorageService();
    final wp = workoutProvider ??
        WorkoutProvider(
          mockStorage,
          mlService: MockMLService(),
          programManager: ProgramManager(mockStorage),
        );
    final sp = settingsProvider ?? SettingsProvider(mockStorage);
    final hm = historyManager ?? HistoryManager(mockStorage);
    final hhm = healthHistoryManager ?? HealthHistoryManager(const StubHcService(), mockStorage);
    final rm = readinessManager ?? ReadinessManager(const StubHcService(), mockStorage, sp);
    final prm = PRManager(mockStorage);
    final conv = ConversationManager(mockStorage);
    final tools = CoachToolService(wp, prm);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkoutProvider>.value(value: wp),
        ChangeNotifierProvider<SettingsProvider>.value(value: sp),
        ChangeNotifierProvider<HistoryManager>.value(value: hm),
        ChangeNotifierProvider<PRManager>.value(value: prm),
        ChangeNotifierProvider<GeminiAiService>.value(value: GeminiAiService()),
        ChangeNotifierProvider<ConversationManager>.value(value: conv),
        ChangeNotifierProvider<ReadinessManager>.value(value: rm),
        Provider<HealthHistoryManager>.value(value: hhm),
        Provider<IHealthConnectService>.value(value: const StubHcService()),
        Provider<ApiService>.value(value: ApiService()),
        Provider<CoachToolService>.value(value: tools),
        Provider<IMLService>.value(value: MockMLService()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: viewportSize),
          child: child,
        ),
      ),
    );
  }

  /// Sets device physical dimensions for widget tests.
  static Future<void> prepareTester(WidgetTester tester, {Size size = const Size(1080, 2400)}) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
  }
}
