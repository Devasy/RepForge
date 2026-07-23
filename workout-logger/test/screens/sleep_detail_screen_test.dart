import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/sleep_detail_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/health_history_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/stub_health_connect_service.dart';

Widget _wrapWithProviders({
  required WorkoutProvider workoutProvider,
  required HealthHistoryManager healthHistoryManager,
  required Widget child,
}) {
  final storage = MockStorageService();
  final sp = SettingsProvider(storage);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: sp),
      Provider<HealthHistoryManager>.value(value: healthHistoryManager),
      Provider<IHealthConnectService>.value(value: const StubHcService()),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Renders SleepDetailScreen title and granularities', (WidgetTester tester) async {
    final storage = MockStorageService();
    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    final healthHistory = HealthHistoryManager(const StubHcService());

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      healthHistoryManager: healthHistory,
      child: SleepDetailScreen(initialDate: DateTime(2026, 5, 10)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sleep'), findsOneWidget);
  });
}
