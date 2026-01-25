// Widget Tests for AddCustomExerciseScreen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/add_custom_exercise_screen.dart';
import 'package:repforge/services/storage_service.dart';
import 'package:repforge/services/workout_provider.dart';

// Mock StorageService for testing - all methods return Future
class MockStorageService implements StorageService {
  final List<Exercise> _customExercises = [];
  bool saveCustomExerciseCalled = false;
  Exercise? lastSavedExercise;

  @override
  Future<void> init() async {}

  @override
  Future<List<Exercise>> getAllExercises() async => _customExercises;

  @override
  Future<List<Exercise>> getCustomExercises() async => _customExercises;

  @override
  Future<void> saveCustomExercise(Exercise exercise) async {
    saveCustomExerciseCalled = true;
    lastSavedExercise = exercise;
    _customExercises.add(exercise);
  }

  @override
  Future<void> deleteCustomExercise(String id) async {
    _customExercises.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<WorkoutSession>> getAllWorkoutSessions() async => [];

  @override
  Future<List<Routine>> getAllRoutines() async => [];

  @override
  Future<List<MuscleGroup>> getAllMuscleGroups() async => [];

  @override
  Future<List<Target>> getAllTargets() async => [];

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {}
  @override
  Future<WorkoutSession?> getWorkoutSession(String id) async => null;
  @override
  Future<void> deleteWorkoutSession(String id) async {}
  @override
  Future<List<WorkoutSession>> getSessionsForExercise(
    String exerciseId,
  ) async => [];
  @override
  Future<List<WorkoutSession>> getSessionsInDateRange(
    DateTime start,
    DateTime end,
  ) async => [];
  @override
  Future<void> saveRoutine(Routine routine) async {}
  @override
  Future<Routine?> getRoutine(String id) async => null;
  @override
  Future<void> deleteRoutine(String id) async {}
  @override
  Future<void> saveTarget(Target target) async {}
  @override
  Future<Target?> getTarget(String id) async => null;
  @override
  Future<void> deleteTarget(String id) async {}
  @override
  Future<List<Target>> getTargetsForExercise(String exerciseId) async => [];
  @override
  Future<void> updateMuscleGroupGrowthRate(
    String muscleGroupId,
    double rate,
  ) async {}
  @override
  Future<MuscleGroup?> getMuscleGroup(String id) async => null;
  @override
  Future<Exercise?> getExercise(String id) async => null;
  @override
  Future<void> saveSetting(String key, String value) async {}
  @override
  Future<String?> getSetting(String key) async => null;
  @override
  Future<String> exportAllData() async => '{}';
  @override
  Future<void> importData(String jsonData) async {}
  @override
  Future<Map<String, dynamic>> getQuickStats() async => {};
}

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
      provider = WorkoutProvider(mockStorage);
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
      await tester.tap(find.text('Shoulders'));
      await tester.pump();

      // Submit
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Assert - Storage should have been called
      expect(mockStorage.saveCustomExerciseCalled, isTrue);
      expect(
        mockStorage.lastSavedExercise?.name,
        equals('Cable Lateral Raise'),
      );
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
