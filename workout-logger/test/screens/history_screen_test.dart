import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/history_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';

Widget _wrapWithProviders({
  required WorkoutProvider workoutProvider,
  required HistoryManager historyManager,
  required Widget child,
}) {
  final storage = MockStorageService();
  final sp = SettingsProvider(storage);
  final prm = PRManager(storage);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: sp),
      ChangeNotifierProvider<PRManager>.value(value: prm),
      ChangeNotifierProvider<HistoryManager>.value(value: historyManager),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Renders HistoryScreen title and empty history state', (WidgetTester tester) async {
    final storage = MockStorageService();
    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    final historyManager = HistoryManager(storage);
    await historyManager.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      historyManager: historyManager,
      child: const HistoryScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Workout History'), findsOneWidget);
  });

  testWidgets('Displays session item in history list', (WidgetTester tester) async {
    final storage = MockStorageService();
    final session = WorkoutSession(
      id: 'history_session_1',
      date: DateTime(2026, 5, 12, 10, 0),
      duration: 30,
      notes: 'Morning Leg Workout',
      exercises: [
        ExerciseLog(exerciseId: 'squats', sets: [WorkoutSet(weight: 100, reps: 5, timestamp: DateTime.now())]),
      ],
    );
    await storage.saveWorkoutSession(session);

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    final historyManager = HistoryManager(storage);
    await historyManager.init();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: workout,
      historyManager: historyManager,
      child: const HistoryScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Morning Leg Workout'), findsOneWidget);
  });
}
