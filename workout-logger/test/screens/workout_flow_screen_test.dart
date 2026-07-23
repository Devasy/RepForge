import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/workout_flow_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/interfaces/ml_service_interface.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';

Widget _wrapWithProviders({
  required WorkoutProvider workoutProvider,
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
      ChangeNotifierProvider<GeminiAiService>.value(value: GeminiAiService()),
      Provider<IMLService>.value(value: MockMLService()),
    ],
    child: MaterialApp(home: child),
  );
}

Future<WorkoutProvider> _createStartedProvider() async {
  final storage = MockStorageService();
  final provider = WorkoutProvider(
    storage,
    mlService: MockMLService(),
    programManager: ProgramManager(storage),
  );
  await provider.init();

  final routine = Routine(
    id: 'chest_day',
    name: 'Chest & Triceps',
    exerciseIds: ['bench_press', 'incline_dumbbells'],
  );
  provider.startWorkout(routine: routine);
  return provider;
}

void main() {
  testWidgets('Renders WorkoutFlowScreen with active exercise details', (WidgetTester tester) async {
    final provider = await _createStartedProvider();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: const WorkoutFlowScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chest & Triceps'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('Logs a set and completes exercise', (WidgetTester tester) async {
    final provider = await _createStartedProvider();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: const WorkoutFlowScreen(),
    ));
    await tester.pumpAndSettle();

    // Add set
    provider.addSet(WorkoutSet(
      weight: 100.0,
      reps: 5,
      timestamp: DateTime.now(),
    ));
    await tester.pumpAndSettle();

    expect(provider.currentExerciseLog?.sets.length, equals(1));
  });

  testWidgets('Finishes active workout session', (WidgetTester tester) async {
    final provider = await _createStartedProvider();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: const WorkoutFlowScreen(),
    ));
    await tester.pumpAndSettle();

    // Add set so workout has data
    provider.addSet(WorkoutSet(
      weight: 80.0,
      reps: 10,
      timestamp: DateTime.now(),
    ));
    await tester.pumpAndSettle();

    // Tap Finish button
    final finishBtn = find.text('Finish');
    await tester.tap(finishBtn);
    await tester.pumpAndSettle();

    // Workout summary or home return should occur
    expect(provider.hasActiveWorkout, isFalse);
  });
}
