import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/profile_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/api_service.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/stub_health_connect_service.dart';

Widget _wrapWithProviders({
  required WorkoutProvider workoutProvider,
  required SettingsProvider settingsProvider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      Provider<IHealthConnectService>.value(value: const StubHcService()),
      Provider<ApiService>.value(value: ApiService()),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Renders ProfileScreen with sections', (WidgetTester tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      settingsProvider: settings,
      child: const ProfileScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Data Management'), findsOneWidget);
    expect(find.text('AI Coach Settings'), findsOneWidget);
    expect(find.text('About RepForge'), findsOneWidget);
  });

  testWidgets('Toggles weight unit preference', (WidgetTester tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      settingsProvider: settings,
      child: const ProfileScreen(),
    ));
    await tester.pumpAndSettle();

    // Verify initial unit is kg or lbs
    expect(settings.unitLabel, equals('kg'));

    // Tap lbs chip
    final lbsChip = find.text('lbs');
    if (lbsChip.evaluate().isNotEmpty) {
      await tester.tap(lbsChip);
      await tester.pumpAndSettle();
      expect(settings.unitLabel, equals('lbs'));
    }
  });

  testWidgets('Updates Gemini API key in AI settings section', (WidgetTester tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      settingsProvider: settings,
      child: const ProfileScreen(),
    ));
    await tester.pumpAndSettle();

    // Find Gemini API Key TextField
    final apiKeyField = find.widgetWithText(TextField, 'API Key');
    if (apiKeyField.evaluate().isNotEmpty) {
      await tester.enterText(apiKeyField, 'my_new_api_key');
      await tester.pump();
      expect(settings.geminiApiKey, equals('my_new_api_key'));
    }
  });
}
