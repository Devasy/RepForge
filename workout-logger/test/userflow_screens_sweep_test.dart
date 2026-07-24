import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/home_screen.dart';
import 'package:repforge/screens/profile_screen.dart';
import 'package:repforge/screens/heart_rate_detail_screen.dart';
import 'package:repforge/screens/sleep_detail_screen.dart';
import 'package:repforge/screens/programs/program_designer_screen.dart';
import 'package:repforge/screens/workout_flow_screen.dart';
import 'package:repforge/screens/workout_summary_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';

import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';
import 'test_utils/test_robot.dart';
import 'test_utils/test_sweep.dart';

void main() {
  late MockStorageService storage;
  late WorkoutProvider workoutProvider;
  late SettingsProvider settingsProvider;
  late HistoryManager historyManager;
  late PRManager prManager;

  setUp(() async {
    storage = MockStorageService();
    settingsProvider = SettingsProvider(storage);
    historyManager = HistoryManager(storage);
    prManager = PRManager(storage);

    workoutProvider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
      historyManager: historyManager,
    );

    await workoutProvider.init();
    await settingsProvider.init();
    await historyManager.loadSessions();
    await prManager.load();

    // Save a custom session for history/home widgets
    final session = WorkoutSession(
      id: 'sess_sweep_1',
      date: DateTime.now(),
      duration: 50,
      exercises: [
        ExerciseLog(
          exerciseId: 'bench_press',
          sets: [WorkoutSet(weight: 100, reps: 10)],
        ),
      ],
    );
    await storage.saveWorkoutSession(session);
    await historyManager.loadSessions();
  });

  group('Comprehensive User Flow Sweeps across Screens', () {
    testWidgets('HomeScreen navigation bar tab sweep and dashboard actions', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const HomeScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        historyManager: historyManager,
      );

      robot.expectVisible(HomeScreen);

      // Sweep through navigation bar tabs
      final navIcons = [
        Icons.layers_rounded,
        Icons.history_rounded,
        Icons.bar_chart_rounded,
        Icons.home_rounded,
      ];
      await TestSweep.tapAll(tester, navIcons);

      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileScreen settings & data management sweep', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const ProfileScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(ProfileScreen);

      // Sweep unit preference chips
      final profileTargets = [
        'kg',
        'lbs',
      ];
      await TestSweep.tapAll(tester, profileTargets);

      expect(tester.takeException(), isNull);
    });

    testWidgets('HeartRateDetailScreen & SleepDetailScreen granularity chip sweep', (tester) async {
      final robot = TestRobot(tester);

      // 1. HeartRateDetailScreen
      await robot.pumpScreen(
        HeartRateDetailScreen(initialDate: DateTime.now()),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      await TestSweep.tapAll(tester, ['Day', 'Week', 'Month', 'Year']);

      // 2. SleepDetailScreen
      await robot.pumpScreen(
        SleepDetailScreen(initialDate: DateTime.now()),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      await TestSweep.tapAll(tester, ['Day', 'Week', 'Month', 'Year']);

      expect(tester.takeException(), isNull);
    });

    testWidgets('ProgramDesignerScreen comprehensive creation flow sweep', (tester) async {
      final robot = TestRobot(tester);

      await robot.pumpScreen(
        const ProgramDesignerScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
      );

      robot.expectVisible(ProgramDesignerScreen);

      // Enter form parameters
      final fields = find.byType(TextField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.first, 'Custom Power Program');
        await tester.pump();
      }

      // Tap action buttons (Add Phase, Add Week, Save Program)
      final actionButtons = [
        'Add Phase',
        'Add Week',
        'Save Program',
      ];
      await TestSweep.tapAll(tester, actionButtons);

      expect(tester.takeException(), isNull);
    });

    testWidgets('WorkoutFlowScreen & WorkoutSummaryScreen user logging sweep', (tester) async {
      final robot = TestRobot(tester);

      workoutProvider.startWorkout(exerciseIds: ['bench_press', 'squat']);

      await robot.pumpScreen(
        const WorkoutFlowScreen(),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(WorkoutFlowScreen);

      // Interact with set logging and rest timer
      final logSetBtn = find.text('LOG SET');
      if (logSetBtn.evaluate().isNotEmpty) {
        await tester.tap(logSetBtn);
        await tester.pumpAndSettle();

        final restTargets = ['+30s', 'SKIP REST'];
        await TestSweep.tapAll(tester, restTargets);
      }

      // Complete active workout and render summary screen
      final session = WorkoutSession(
        id: 'completed_summary_1',
        date: DateTime.now(),
        duration: 40,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [WorkoutSet(weight: 100, reps: 8)],
          ),
        ],
      );

      await robot.pumpScreen(
        WorkoutSummaryScreen(session: session),
        storage: storage,
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
      );

      robot.expectVisible(WorkoutSummaryScreen);
      expect(find.text('Workout Complete!'), findsOneWidget);
    });
  });
}
