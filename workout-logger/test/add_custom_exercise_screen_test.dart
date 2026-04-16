// Widget Tests for AddCustomExerciseScreen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/add_custom_exercise_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';

Widget createTestWidget({
  required Widget child,
  required WorkoutProvider provider,
}) {
  return ChangeNotifierProvider<WorkoutProvider>.value(
    value: provider,
    child: MaterialApp(home: child),
  );
}

void main() {
  group('AddCustomExerciseScreen Widget Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage, programManager: ProgramManager(mockStorage));
      await provider.init();
    });

    testWidgets('should show validation error for empty name', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const AddCustomExerciseScreen(),
          provider: provider,
        ),
      );

      // Act - Try to save without entering a name
      // First select a muscle group (required)
      await tester.ensureVisible(find.text('Chest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chest'));
      await tester.pump();

      // Find and tap the Save button in AppBar
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - Should show validation error
      expect(find.text('Please enter an exercise name'), findsOneWidget);
    });

    testWidgets(
      'should show validation error for name less than 3 characters',
      (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestWidget(
            child: const AddCustomExerciseScreen(),
            provider: provider,
          ),
        );

        // Act - Enter a short name
        await tester.enterText(find.byType(TextFormField), 'Ab');
        await tester.ensureVisible(find.text('Chest'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chest'));
        await tester.pump();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Name must be at least 3 characters'), findsOneWidget);
      },
    );

    testWidgets('should show error when no muscle group selected', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const AddCustomExerciseScreen(),
          provider: provider,
        ),
      );

      // Act - Enter valid name but don't select muscle group
      await tester.enterText(find.byType(TextFormField), 'My Exercise');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - Should show snackbar error
      expect(find.text('Please select a primary muscle group'), findsOneWidget);
    });

    testWidgets('should call provider method on valid form submission', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const AddCustomExerciseScreen(),
          provider: provider,
        ),
      );

      // Act - Fill in valid form
      await tester.enterText(find.byType(TextFormField), 'Cable Lateral Raise');
      await tester.pump();

      // Select a muscle group
      await tester.ensureVisible(find.text('Shoulders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shoulders'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Assert - Storage should have been called
      expect(mockStorage.saveCustomExerciseCalled, isTrue);
      expect(
        mockStorage.lastSavedExercise?.name,
        equals('Cable Lateral Raise'),
      );
      // Verify screen popped (AddCustomExerciseScreen no longer in tree)
      expect(find.byType(AddCustomExerciseScreen), findsNothing);
    });

    testWidgets('should show compound/isolation toggle buttons', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const AddCustomExerciseScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Compound'), findsOneWidget);
      expect(find.text('Isolation'), findsOneWidget);
    });

    testWidgets('should display all muscle group options', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const AddCustomExerciseScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Check for some muscle groups
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Shoulders'), findsOneWidget);
      expect(find.text('Biceps'), findsOneWidget);
    });

    testWidgets('should update category when toggle is tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const AddCustomExerciseScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Tap Isolation
      await tester.tap(find.text('Isolation'));
      await tester.pumpAndSettle();

      // Assert - Description should change
      expect(
        find.text('Targets a single muscle group (e.g., bicep curls)'),
        findsOneWidget,
      );
    });
  });
}
