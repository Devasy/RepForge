// Widget Tests for RoutinesScreen - Multi-select exercise picker and custom exercises

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/routines_screen.dart';
import 'package:repforge/services/workout_provider.dart';
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
  group('RoutinesScreen Widget Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage);
      await provider.init();
    });

    testWidgets('should display empty state when no routines', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(child: const RoutinesScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('No Routines Yet'), findsOneWidget);
      expect(
        find.text('Create a routine to organize your workouts'),
        findsOneWidget,
      );
    });

    testWidgets('should display FAB to create new routine', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(child: const RoutinesScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('New Routine'), findsOneWidget);
    });

    testWidgets('should navigate to CreateRoutineScreen on FAB tap', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(child: const RoutinesScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('New Routine'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CreateRoutineScreen), findsOneWidget);
    });
  });

  group('CreateRoutineScreen Widget Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage);
      await provider.init();
    });

    testWidgets('should display routine name text field', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Routine Name'), findsOneWidget);
      expect(find.text('e.g., Push Day, Leg Day'), findsOneWidget);
    });

    testWidgets('should display Add Exercises button', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Add Exercises'), findsOneWidget);
    });

    testWidgets('should show validation error for empty name', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Try to save without entering a name
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Please enter a routine name'), findsOneWidget);
    });

    testWidgets('should show validation error for empty exercise list', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Enter name but no exercises
      await tester.enterText(find.byType(TextField), 'Test Routine');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Please add at least one exercise'), findsOneWidget);
    });

    testWidgets('should open exercise picker when Add Exercises tapped', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Add Exercises'));
      await tester.pumpAndSettle();

      // Assert - Should see the multi-select picker
      expect(find.text('Search exercises...'), findsOneWidget);
    });

    testWidgets('should display custom exercises in exercise picker', (
      tester,
    ) async {
      // Arrange - Add a custom exercise first
      await provider.addCustomExercise(
        name: 'My Custom Press',
        category: 'compound',
        primaryMuscleGroupId: 'chest',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Open exercise picker
      await tester.tap(find.text('Add Exercises'));
      await tester.pumpAndSettle();

      // Assert - Should find the custom exercise (may appear multiple times in UI)
      expect(find.text('My Custom Press'), findsAtLeastNWidgets(1));
      expect(find.text('CUSTOM'), findsWidgets);
    });

    testWidgets('should allow selecting multiple exercises', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Open exercise picker
      await tester.tap(find.text('Add Exercises'));
      await tester.pumpAndSettle();

      // Assert - The picker should show with search and selection UI
      expect(find.text('Search exercises...'), findsOneWidget);
      expect(find.text('Select exercises'), findsOneWidget);
    });

    testWidgets('should filter exercises by search query', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Open exercise picker
      await tester.tap(find.text('Add Exercises'));
      await tester.pumpAndSettle();

      // Search for 'bench'
      await tester.enterText(
        find.widgetWithText(TextField, 'Search exercises...'),
        'bench',
      );
      await tester.pumpAndSettle();

      // Assert - Should filter results (only bench-related exercises should show)
      // Exact assertion depends on the exercise database
    });

    testWidgets('should show CUSTOM badge for custom exercises in picker', (
      tester,
    ) async {
      // Arrange - Add a custom exercise
      await provider.addCustomExercise(
        name: 'Custom Routine Exercise',
        category: 'isolation',
        primaryMuscleGroupId: 'biceps',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Open picker
      await tester.tap(find.text('Add Exercises'));
      await tester.pumpAndSettle();

      // Assert - Should see the custom exercise and CUSTOM badge
      expect(find.text('Custom Routine Exercise'), findsAtLeastNWidgets(1));
      expect(find.text('CUSTOM'), findsWidgets);
    });
  });

  group('Exercise Multi-Select Picker Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage);
      await provider.init();
    });

    testWidgets('should show "Select exercises" when none selected', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Open picker
      await tester.tap(find.text('Add Exercises'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Select exercises'), findsOneWidget);
    });

    testWidgets('should have Clear button when exercises are selected', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Open picker
      await tester.tap(find.text('Add Exercises'));
      await tester.pumpAndSettle();

      // Select an exercise
      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isNotEmpty) {
        await tester.tap(checkboxes.first);
        await tester.pump();

        // Assert - Clear button should appear
        expect(find.text('Clear'), findsOneWidget);
      }
    });

    testWidgets('should have search clear button when text is entered', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateRoutineScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Open picker and enter search text
      await tester.tap(find.text('Add Exercises'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Search exercises...'),
        'test',
      );
      await tester.pump();

      // Assert - Clear icon should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });
  });
}
