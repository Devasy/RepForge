import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/edit_workout_session_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_fixtures.dart';
import '../test_utils/test_robot.dart';

Future<WorkoutProvider> _createProvider(MockStorageService storage, {List<WorkoutSession> sessions = const []}) async {
  for (final s in sessions) {
    await storage.saveWorkoutSession(s);
  }
  final provider = WorkoutProvider(
    storage,
    mlService: MockMLService(),
    programManager: ProgramManager(storage),
  );
  await provider.init();
  return provider;
}

void main() {
  testWidgets('Renders EditWorkoutSessionScreen with session details', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final session = TestFixtures.sampleSession(notes: 'Feeling strong today');
    final provider = await _createProvider(storage, sessions: [session]);

    await robot.pumpScreen(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    );

    robot.expectVisible('Edit Workout');
    robot.expectVisible('Feeling strong today');
  });

  testWidgets('Adds a set to an existing exercise', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final session = TestFixtures.sampleSession();
    final provider = await _createProvider(storage, sessions: [session]);

    await robot.pumpScreen(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    );

    await robot.tap(find.text('Add Set').first);
    robot.expectVisible(EditWorkoutSessionScreen);
  });

  testWidgets('Deletes a set from an exercise log', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final session = TestFixtures.sampleSession();
    final provider = await _createProvider(storage, sessions: [session]);

    await robot.pumpScreen(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    );

    await robot.tap(find.byIcon(Icons.close_rounded).first);
  });

  testWidgets('Edits session notes and saves session', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final session = TestFixtures.sampleSession();
    final provider = await _createProvider(storage, sessions: [session]);

    await robot.pumpScreen(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    );

    await robot.fill('Sample session notes', 'Updated workout session note');
    await robot.tap('Save');

    final updated = provider.sessions.firstWhere((s) => s.id == session.id);
    expect(updated.notes, equals('Updated workout session note'));
  });

  testWidgets('Shows discard dialog on back navigation when modified', (WidgetTester tester) async {
    final robot = TestRobot(tester);
    final storage = MockStorageService();
    final session = TestFixtures.sampleSession();
    final provider = await _createProvider(storage, sessions: [session]);

    await robot.pumpScreen(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    );

    await robot.fill('45', '90');
    await robot.handlePop();

    robot.expectVisible('Discard Changes?');
    await robot.tap('Discard');
  });
}
