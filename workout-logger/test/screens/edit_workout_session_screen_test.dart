import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/edit_workout_session_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../test_utils/mock_storage_service.dart';
import '../test_utils/mock_ml_service.dart';
import '../test_utils/test_fixtures.dart';
import '../test_utils/test_harness.dart';

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
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final session = TestFixtures.sampleSession(notes: 'Feeling strong today');
    final provider = await _createProvider(storage, sessions: [session]);

    await tester.pumpWidget(TestHarness.wrap(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit Workout'), findsOneWidget);
    expect(find.text('Feeling strong today'), findsOneWidget);
  });

  testWidgets('Adds a set to an existing exercise', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final session = TestFixtures.sampleSession();
    final provider = await _createProvider(storage, sessions: [session]);

    await tester.pumpWidget(TestHarness.wrap(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();

    // Tap Add Set
    final addSetBtn = find.text('Add Set').first;
    await tester.tap(addSetBtn);
    await tester.pumpAndSettle();

    expect(find.byType(EditWorkoutSessionScreen), findsOneWidget);
  });

  testWidgets('Deletes a set from an exercise log', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final session = TestFixtures.sampleSession();
    final provider = await _createProvider(storage, sessions: [session]);

    await tester.pumpWidget(TestHarness.wrap(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();

    final deleteIcons = find.byIcon(Icons.close_rounded);
    expect(deleteIcons, findsWidgets);

    await tester.tap(deleteIcons.first);
    await tester.pumpAndSettle();
  });

  testWidgets('Edits session notes and saves session', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final session = TestFixtures.sampleSession();
    final provider = await _createProvider(storage, sessions: [session]);

    await tester.pumpWidget(TestHarness.wrap(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();

    // Enter notes in prepopulated notes textfield
    final notesField = find.widgetWithText(TextField, 'Sample session notes');
    await tester.enterText(notesField, 'Updated workout session note');
    await tester.pump();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = provider.sessions.firstWhere((s) => s.id == session.id);
    expect(updated.notes, equals('Updated workout session note'));
  });

  testWidgets('Shows discard dialog on back navigation when modified', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final session = TestFixtures.sampleSession();
    final provider = await _createProvider(storage, sessions: [session]);

    await tester.pumpWidget(TestHarness.wrap(
      EditWorkoutSessionScreen(session: session),
      storage: storage,
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();

    // Modify duration field
    final durationField = find.widgetWithText(TextField, '45');
    await tester.enterText(durationField, '90');
    await tester.pump();

    // Trigger back navigation
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard Changes?'), findsOneWidget);

    // Tap Discard
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
  });
}
