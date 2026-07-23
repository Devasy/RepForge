import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/home_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import 'package:repforge/services/api_service.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/stub_health_connect_service.dart';

Widget _wrapWithProviders({
  required WorkoutProvider workoutProvider,
  required SettingsProvider settingsProvider,
  required Widget child,
}) {
  final storage = MockStorageService();
  final prm = PRManager(storage);
  final conv = ConversationManager(storage);
  final tools = CoachToolService(workoutProvider, prm);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<PRManager>.value(value: prm),
      ChangeNotifierProvider<GeminiAiService>.value(value: GeminiAiService()),
      Provider<IHealthConnectService>.value(value: const StubHcService()),
      Provider<ApiService>.value(value: ApiService()),
      Provider<CoachToolService>.value(value: tools),
      Provider<ConversationManager>.value(value: conv),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Renders HomeScreen with navigation bar items', (WidgetTester tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      settingsProvider: settings,
      child: const HomeScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Routines'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
  });

  testWidgets('Switches tabs when floating nav bar item is tapped', (WidgetTester tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      settingsProvider: settings,
      child: const HomeScreen(),
    ));
    await tester.pumpAndSettle();

    // Tap Routines tab
    await tester.tap(find.text('Routines'));
    await tester.pumpAndSettle();

    // RoutinesScreen content should be displayed
    expect(find.text('Workout Routines'), findsOneWidget);
  });
}
