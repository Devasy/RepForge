import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/history_screen.dart';
import 'package:repforge/services/managers/health_history_manager.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/workout_provider.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/stub_health_connect_service.dart';

Widget _buildTestApp({
  required WorkoutProvider workoutProvider,
  required SettingsProvider settingsProvider,
  required HistoryManager historyManager,
  required HealthHistoryManager healthHistoryManager,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      Provider<HealthHistoryManager>.value(value: healthHistoryManager),
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<HistoryManager>.value(value: historyManager),
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
  late HistoryManager historyManager;
  late HealthHistoryManager healthHistoryManager;

  setUp(() async {
    mockStorage = MockStorageService();
    historyManager = HistoryManager(mockStorage);
    healthHistoryManager = HealthHistoryManager(StubHcService(), mockStorage);
    workoutProvider = WorkoutProvider(
      mockStorage,
      programManager: ProgramManager(mockStorage),
      historyManager: historyManager,
    );
    settingsProvider = SettingsProvider(mockStorage);

    await workoutProvider.init();
    await settingsProvider.init();
  });

  group('Userflow 2: History & Session Details Sheet Flow', () {
    testWidgets('HistoryScreen renders title when no sessions recorded', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        historyManager: historyManager,
        healthHistoryManager: healthHistoryManager,
        child: const HistoryScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('HistoryScreen lists sessions and opens SessionDetailsSheet on tap', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final session = WorkoutSession(
        id: 'hist_s1',
        date: DateTime.now(),
        duration: 60,
        exercises: [
          ExerciseLog(
            exerciseId: 'squat_id',
            sets: [
              WorkoutSet(weight: 140, reps: 5),
              WorkoutSet(weight: 140, reps: 5),
            ],
          ),
        ],
      );

      await mockStorage.saveWorkoutSession(session);
      await historyManager.loadSessions();
      await workoutProvider.init(); // Reload sessions from storage

      await tester.pumpWidget(_buildTestApp(
        workoutProvider: workoutProvider,
        settingsProvider: settingsProvider,
        historyManager: historyManager,
        healthHistoryManager: healthHistoryManager,
        child: const HistoryScreen(),
      ));
      await tester.pumpAndSettle();

      // Tap session item in HistoryScreen to open SessionDetailsSheet
      final sessionCard = find.text('Quick Workout');
      expect(sessionCard, findsOneWidget);
      await tester.tap(sessionCard);
      await tester.pumpAndSettle();

      // Verify SessionDetailsSheet displays details
      expect(find.textContaining('60 min'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
    });
  });
}
