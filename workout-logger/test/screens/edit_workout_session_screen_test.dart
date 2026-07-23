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

    // Count set-delete icons before adding (fixture has 3 sets total = 3 close icons).
    final initialCount = find.byIcon(Icons.close_rounded).evaluate().length;

    await robot.tap(find.text('Add Set').first);

    // After adding a set, there should be one more close icon.
    final updatedCount = find.byIcon(Icons.close_rounded).evaluate().length;
    expect(updatedCount, greaterThan(initialCount));
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

    // Count set-delete icons before deletion (fixture has 3 sets total = 3 close icons).
    final initialCount = find.byIcon(Icons.close_rounded).evaluate().length;
    expect(initialCount, greaterThan(0));

    await robot.tap(find.byIcon(Icons.close_rounded).first);

    // After deletion, one fewer close icon should be visible.
    final updatedCount = find.byIcon(Icons.close_rounded).evaluate().length;
    expect(updatedCount, lessThan(initialCount));
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

    // Verify in-memory provider update.
    final updated = provider.sessions.firstWhere((s) => s.id == session.id);
    expect(updated.notes, equals('Updated workout session note'));

    // Verify persistence through storage.
    final persisted = await storage.getWorkoutSession(session.id);
    expect(persisted, isNotNull);
    expect(persisted!.notes, equals('Updated workout session note'));
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

    // After confirming discard, the dialog and the edit screen should both be gone.
    robot.expectNotVisible('Discard Changes?');
    robot.expectNotVisible(EditWorkoutSessionScreen);
  });
}
