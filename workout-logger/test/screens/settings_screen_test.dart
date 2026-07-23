import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/settings_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';

Widget _wrapWithProviders({
  required WorkoutProvider workoutProvider,
  required SettingsProvider settingsProvider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Renders SettingsScreen title and preference options', (WidgetTester tester) async {
    final storage = MockStorageService();
    final settings = SettingsProvider(storage);
    await settings.init();

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      settingsProvider: settings,
      child: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Weight Unit'), findsOneWidget);
  });
}
