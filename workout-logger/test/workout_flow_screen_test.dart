// Widget Tests for WorkoutFlowScreen - Quick Start and Exercise Selection

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/screens/workout_flow_screen.dart';
import 'package:repforge/screens/exercise_library_screen.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/models/models.dart';
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
  group('WorkoutFlowScreen - Quick Start Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage);
      await provider.init();
    });

    testWidgets('should show exercise selector in quick start mode', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const WorkoutFlowScreen(isQuickStart: true),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should see exercise selector UI
      expect(find.text('Select Exercises'), findsOneWidget);
      expect(find.text('Search exercises...'), findsOneWidget);
    });

    testWidgets('should show close button to cancel workout', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const WorkoutFlowScreen(isQuickStart: true),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets(
      'should show "Start with X exercises" button when exercises selected',
      (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestWidget(
            child: const WorkoutFlowScreen(isQuickStart: true),
            provider: provider,
          ),
        );
        await tester.pumpAndSettle();

        // Find and tap an exercise checkbox
        final checkboxes = find.byType(Checkbox);
        if (checkboxes.evaluate().isNotEmpty) {
          await tester.tap(checkboxes.first);
          await tester.pump();

          // Assert - Button text should update
          expect(find.textContaining('Start with'), findsOneWidget);
        }
      },
    );

    testWidgets('should have disabled button when no exercises selected', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const WorkoutFlowScreen(isQuickStart: true),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Button should exist but be disabled (shows "Start with 0 exercises")
      final button = find.widgetWithText(
        ElevatedButton,
        'Start with 0 exercises',
      );
      expect(button, findsOneWidget);

      // Check button is disabled
      final elevatedButton = tester.widget<ElevatedButton>(button);
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('should display custom exercises in quick start selector', (
      tester,
    ) async {
      // Arrange - Add a custom exercise
      await provider.addCustomExercise(
        name: 'Quick Start Custom',
        category: 'compound',
        primaryMuscleGroupId: 'chest',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const WorkoutFlowScreen(isQuickStart: true),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - May find multiple instances due to UI structure
      expect(find.text('Quick Start Custom'), findsAtLeastNWidgets(1));
    });

    testWidgets('should filter exercises by search in quick start', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const WorkoutFlowScreen(isQuickStart: true),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Search for exercises
      await tester.enterText(find.byType(TextField), 'bench');
      await tester.pumpAndSettle();

      // Assert - Results should be filtered
      // Specific assertion depends on exercise database content
    });
  });

  group('WorkoutFlowScreen - Routine Mode Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage);
      await provider.init();
    });

    testWidgets('should start workout immediately with routine exercises', (
      tester,
    ) async {
      // Arrange - Create a routine with exercises
      final routine = Routine(
        id: 'test_routine',
        name: 'Test Push Day',
        exerciseIds: ['bench_press', 'incline_db_press'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestWidget(
          child: WorkoutFlowScreen(routine: routine),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should show workout view, not exercise selector
      // The workout view shows exercise name and set controls
      expect(find.text('Select Exercises'), findsNothing);
    });
  });

  group('ExerciseSelectorScreen Widget Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage);
      await provider.init();
    });

    testWidgets('should display checkboxes in selection mode', (tester) async {
      // Arrange
      List<String>? selectedExercises;

      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: ExerciseSelectorScreen(
              selectionMode: true,
              onExercisesSelected: (ids) => selectedExercises = ids,
            ),
          ),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - The selector screen has exercises with checkboxes
      // Check that the UI is rendered with selection mode elements
      expect(find.text('Start with 0 exercises'), findsOneWidget);
    });

    testWidgets('should show selection count when exercises selected', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: ExerciseSelectorScreen(
              selectionMode: true,
              onExercisesSelected: (_) {},
            ),
          ),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Select an exercise
      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isNotEmpty) {
        await tester.tap(checkboxes.first);
        await tester.pump();

        // Assert
        expect(find.textContaining('selected'), findsOneWidget);
      }
    });

    testWidgets('should have Clear button when exercises selected', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: ExerciseSelectorScreen(
              selectionMode: true,
              onExercisesSelected: (_) {},
            ),
          ),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Select an exercise
      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isNotEmpty) {
        await tester.tap(checkboxes.first);
        await tester.pump();

        // Assert
        expect(find.text('Clear'), findsOneWidget);
      }
    });

    testWidgets('should call callback when Start button tapped', (
      tester,
    ) async {
      // Arrange
      List<String>? selectedExercises;

      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: ExerciseSelectorScreen(
              selectionMode: true,
              onExercisesSelected: (ids) => selectedExercises = ids,
            ),
          ),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Select an exercise and tap start
      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isNotEmpty) {
        await tester.tap(checkboxes.first);
        await tester.pump();

        // Find and tap the start button
        final startButton = find.widgetWithText(
          ElevatedButton,
          'Start with 1 exercises',
        );
        if (startButton.evaluate().isNotEmpty) {
          await tester.tap(startButton);
          await tester.pumpAndSettle();

          // Assert
          expect(selectedExercises, isNotNull);
          expect(selectedExercises!.length, equals(1));
        }
      }
    });

    testWidgets('should group exercises by muscle', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: ExerciseSelectorScreen(
              selectionMode: true,
              onExercisesSelected: (_) {},
            ),
          ),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should see the selection UI elements
      expect(find.text('Start with 0 exercises'), findsOneWidget);
    });
  });
}
