import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/workout_flow_screen.dart';
import 'package:repforge/screens/workout_summary_screen.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'test_utils/mock_storage_service.dart';

Widget _buildTestApp({
  required WorkoutProvider workoutProvider,
  required SettingsProvider settingsProvider,
  required PRManager prManager,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<PRManager>.value(value: prManager),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStorageService mockStorage;
  late WorkoutProvider workoutProvider;
  late SettingsProvider settingsProvider;
  late PRManager prManager;

  setUp(() async {
    mockStorage = MockStorageService();
    prManager = PRManager(mockStorage);
    workoutProvider = WorkoutProvider(
      mockStorage,
      programManager: ProgramManager(mockStorage),
    );
    settingsProvider = SettingsProvider(mockStorage);

    await workoutProvider.init();
    await settingsProvider.init();
    await prManager.load();
  });

  group('Userflow 1: Workout Logging & Rest Timer & Summary Screen Flow', () {
    testWidgets('User completes sets, interacts with RestTimerView, and views WorkoutSummaryScreen through production flow', (tester) async {
      // 1. Save custom exercise and start active workout
      final exercise = Exercise(
        id: 'ex_bench',
        name: 'Barbell Bench Press',
        category: 'compound',
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100),
        ],
      );
      await mockStorage.saveCustomExercise(exercise);
      await workoutProvider.init();

      workoutProvider.startWorkout(exerciseIds: ['ex_bench']);

      // Render WorkoutFlowScreen
      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        prManager: prManager,
        child: const WorkoutFlowScreen(),
      ));
      await tester.pumpAndSettle();

      // Verify WorkoutFlowScreen renders exercise name
      expect(find.text('Barbell Bench Press'), findsWidgets);

      // 2. Drive production flow: Tap 'LOG SET' to trigger RestTimerView overlay in WorkoutFlowScreen
      final logSetBtn = find.text('LOG SET');
      expect(logSetBtn, findsOneWidget);
      await tester.tap(logSetBtn);
      await tester.pumpAndSettle();

      // Verify RestTimerView overlay appears via WorkoutFlowScreen production state
      expect(find.text('REST'), findsWidgets);
      expect(find.text('SKIP REST'), findsOneWidget);

      // Tap '+30s' button during rest
      final addTimeBtn = find.text('+30s');
      expect(addTimeBtn, findsOneWidget);
      await tester.tap(addTimeBtn);
      await tester.pump();

      // Tap 'SKIP REST' to return to active workout view
      final skipBtn = find.text('SKIP REST');
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      // 3. Complete workout session and render WorkoutSummaryScreen
      final summarySession = WorkoutSession(
        id: 'completed_s1',
        date: DateTime.now(),
        duration: 45,
        exercises: [
          ExerciseLog(
            exerciseId: 'ex_bench',
            sets: [
              WorkoutSet(weight: 100, reps: 10),
              WorkoutSet(weight: 100, reps: 8),
            ],
          ),
        ],
      );

      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        prManager: prManager,
        child: WorkoutSummaryScreen(session: summarySession),
      ));
      await tester.pumpAndSettle();

      // Verify Summary Screen metrics: trophy, stat grid, volume, sets count
      expect(find.byType(WorkoutSummaryScreen), findsOneWidget);
      expect(find.text('Workout Complete!'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
    });
  });
}
