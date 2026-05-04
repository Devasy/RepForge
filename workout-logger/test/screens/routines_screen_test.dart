import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/routines_screen.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import '../test_utils/mock_storage_service.dart';

void main() {
  group('RoutinesScreen clone routine tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(
        mockStorage,
        programManager: ProgramManager(mockStorage),
      );
      await provider.init();

      // Setup a pre-existing routine
      await provider.createRoutine('Leg Day', ['squat', 'leg_press']);
    });

    testWidgets('shows clone option and clones routine successfully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<WorkoutProvider>.value(
            value: provider,
            child: const RoutinesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the routine card
      final routineCard = find.text('Leg Day');
      expect(routineCard, findsOneWidget);

      // Long press to open options
      await tester.longPress(routineCard);
      await tester.pumpAndSettle();

      // Find and tap the clone option
      final cloneOption = find.text('Clone Routine');
      expect(cloneOption, findsOneWidget);
      await tester.tap(cloneOption);
      await tester.pumpAndSettle();

      // Verify clone dialog appears
      final dialogTitle = find.text('Clone Routine');
      expect(dialogTitle, findsOneWidget);

      // Provide a new name
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Leg Day Copy');
      await tester.pumpAndSettle();

      // Tap Clone button
      final cloneButton = find.widgetWithText(FilledButton, 'Clone');
      expect(cloneButton, findsOneWidget);
      await tester.tap(cloneButton);
      await tester.pumpAndSettle();

      // Verify dialog is closed and new routine is in the provider
      expect(find.text('Clone Routine'), findsNothing);
      expect(provider.routines.length, 2);
      expect(provider.routines[1].name, 'Leg Day Copy');
      expect(provider.routines[1].exerciseIds, ['squat', 'leg_press']);

      // Verify new routine is shown in UI
      expect(find.text('Leg Day Copy'), findsOneWidget);
    });

    testWidgets('clones with original name if text field is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<WorkoutProvider>.value(
            value: provider,
            child: const RoutinesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Long press to open options
      await tester.longPress(find.text('Leg Day'));
      await tester.pumpAndSettle();

      // Tap clone
      await tester.tap(find.text('Clone Routine'));
      await tester.pumpAndSettle();

      // Do NOT enter text, just tap Clone button
      await tester.tap(find.widgetWithText(FilledButton, 'Clone'));
      await tester.pumpAndSettle();

      // Verify provider has the cloned routine with the original name
      expect(provider.routines.length, 2);
      expect(provider.routines[1].name, 'Leg Day');
      expect(provider.routines[1].exerciseIds, ['squat', 'leg_press']);
    });
  });
}
