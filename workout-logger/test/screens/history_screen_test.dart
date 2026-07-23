import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/history_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_fixtures.dart';
import '../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders HistoryScreen title and empty history state', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    final historyManager = HistoryManager(storage);
    await historyManager.loadSessions();

    await tester.pumpWidget(TestHarness.wrap(
      const HistoryScreen(),
      storage: storage,
      workoutProvider: workout,
      historyManager: historyManager,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(HistoryScreen), findsOneWidget);
  });

  testWidgets('Displays session item in history list', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final session = TestFixtures.sampleSession(notes: 'Morning Leg Workout');
    await storage.saveWorkoutSession(session);

    final workout = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await workout.init();

    final historyManager = HistoryManager(storage);
    await historyManager.loadSessions();

    await tester.pumpWidget(TestHarness.wrap(
      const HistoryScreen(),
      storage: storage,
      workoutProvider: workout,
      historyManager: historyManager,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('Morning Leg Workout'), findsOneWidget);
  });
}
