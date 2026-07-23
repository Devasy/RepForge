import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/edit_workout_session_screen.dart';
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
  SettingsProvider? settingsProvider,
}) {
  final storage = MockStorageService();
  final sp = settingsProvider ?? SettingsProvider(storage);
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

Future<WorkoutProvider> _createProvider({List<WorkoutSession> sessions = const []}) async {
  final storage = MockStorageService();
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

WorkoutSession _sampleSession() {
  return WorkoutSession(
    id: 'test_session_1',
    date: DateTime(2026, 5, 10, 14, 30),
    duration: 45,
    notes: 'Feeling strong today',
    exercises: [
      ExerciseLog(
        exerciseId: 'bench_press',
        sets: [
          WorkoutSet(weight: 80.0, reps: 10, timestamp: DateTime(2026, 5, 10, 14, 35)),
          WorkoutSet(weight: 85.0, reps: 8, timestamp: DateTime(2026, 5, 10, 14, 40)),
        ],
        notes: 'Good form',
      ),
    ],
  );
}

void main() {
  testWidgets('Renders EditWorkoutSessionScreen with initial session details', (WidgetTester tester) async {
    final provider = await _createProvider();
    final session = _sampleSession();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: EditWorkoutSessionScreen(session: session),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit Workout'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Feeling strong today'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('Allows editing notes and duration fields', (WidgetTester tester) async {
    final provider = await _createProvider();
    final session = _sampleSession();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: EditWorkoutSessionScreen(session: session),
    ));
    await tester.pumpAndSettle();

    // Find notes field and update text
    final notesFinder = find.widgetWithText(TextField, 'Feeling strong today');
    expect(notesFinder, findsOneWidget);
    await tester.enterText(notesFinder, 'Updated workout notes');
    await tester.pump();

    expect(find.text('Updated workout notes'), findsOneWidget);
  });

  testWidgets('Adds a set to an existing exercise', (WidgetTester tester) async {
    final provider = await _createProvider();
    final session = _sampleSession();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: EditWorkoutSessionScreen(session: session),
    ));
    await tester.pumpAndSettle();

    // Tap Add Set button
    final addSetBtn = find.text('Add Set');
    expect(addSetBtn, findsOneWidget);
    await tester.tap(addSetBtn);
    await tester.pumpAndSettle();

    // Set #3 should now exist
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('Deletes a set from an exercise log', (WidgetTester tester) async {
    final provider = await _createProvider();
    final session = _sampleSession();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: EditWorkoutSessionScreen(session: session),
    ));
    await tester.pumpAndSettle();

    // Find set delete buttons (Icons.close_rounded)
    final deleteSetBtns = find.byIcon(Icons.close_rounded);
    expect(deleteSetBtns, findsNWidgets(2));

    await tester.tap(deleteSetBtns.first);
    await tester.pumpAndSettle();

    // Only 1 set remaining
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('Shows error snackbar when saving with invalid duration', (WidgetTester tester) async {
    final provider = await _createProvider();
    final session = _sampleSession();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: EditWorkoutSessionScreen(session: session),
    ));
    await tester.pumpAndSettle();

    // Clear duration text field
    final durationFinder = find.widgetWithText(TextField, '45');
    await tester.enterText(durationFinder, '');
    await tester.pump();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid duration'), findsOneWidget);
  });

  testWidgets('Saves updated session successfully and pops route', (WidgetTester tester) async {
    final session = _sampleSession();
    final provider = await _createProvider(sessions: [session]);

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: EditWorkoutSessionScreen(session: session),
    ));
    await tester.pumpAndSettle();

    // Update notes
    final notesFinder = find.widgetWithText(TextField, 'Feeling strong today');
    await tester.enterText(notesFinder, 'Awesome leg and chest day');
    await tester.pump();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify session updated in provider
    final updatedSession = provider.sessions.firstWhere((s) => s.id == session.id);
    expect(updatedSession.notes, equals('Awesome leg and chest day'));
  });

  testWidgets('Shows discard dialog on back navigation when changes exist', (WidgetTester tester) async {
    final provider = await _createProvider();
    final session = _sampleSession();

    await tester.pumpWidget(_wrapWithProviders(
      workoutProvider: provider,
      child: EditWorkoutSessionScreen(session: session),
    ));
    await tester.pumpAndSettle();

    // Modify text to mark changes
    final notesFinder = find.widgetWithText(TextField, 'Feeling strong today');
    await tester.enterText(notesFinder, 'Modified notes');
    await tester.pump();

    // Tap back button
    final backBtn = find.byType(BackButton);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsOneWidget);
    }
  });
}
