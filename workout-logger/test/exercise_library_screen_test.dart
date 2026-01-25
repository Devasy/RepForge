// Widget Tests for ExerciseLibraryScreen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/exercise_library_screen.dart';
import 'package:repforge/services/storage_service.dart';
import 'package:repforge/services/workout_provider.dart';

// Mock StorageService for testing - all methods return Future
class MockStorageService implements StorageService {
  final List<Exercise> _customExercises = [];

  void addMockCustomExercise(Exercise exercise) {
    _customExercises.add(exercise);
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<Exercise>> getAllExercises() async => _customExercises;

  @override
  Future<List<Exercise>> getCustomExercises() async => _customExercises;

  @override
  Future<void> saveCustomExercise(Exercise exercise) async {
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
  group('ExerciseLibraryScreen Widget Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage);
      await provider.init();
    });

    testWidgets('should display search bar', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Search exercises...'), findsOneWidget);
    });

    testWidgets('should display FAB to add custom exercise', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Add Exercise'), findsOneWidget);
    });

    testWidgets('should display custom exercises in the list', (tester) async {
      // Arrange - Add a custom exercise
      await provider.addCustomExercise(
        name: 'My Custom Curl',
        category: 'isolation',
        primaryMuscleGroupId: 'biceps',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should find the custom exercise
      expect(find.text('My Custom Curl'), findsOneWidget);
    });

    testWidgets('should display CUSTOM tag for custom exercises', (
      tester,
    ) async {
      // Arrange - Add a custom exercise
      await provider.addCustomExercise(
        name: 'Tagged Custom Exercise',
        category: 'compound',
        primaryMuscleGroupId: 'chest',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should find the CUSTOM tag
      expect(find.text('CUSTOM'), findsOneWidget);
    });

    testWidgets('should display custom exercise count in header when present', (
      tester,
    ) async {
      // Arrange - Add a custom exercise
      await provider.addCustomExercise(
        name: 'Count Test Exercise',
        category: 'isolation',
        primaryMuscleGroupId: 'shoulders',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should show custom count
      expect(find.text('1 custom'), findsOneWidget);
    });

    testWidgets('should filter exercises by search query', (tester) async {
      // Arrange - Add custom exercises
      await provider.addCustomExercise(
        name: 'Bicep Curl',
        category: 'isolation',
        primaryMuscleGroupId: 'biceps',
      );
      await provider.addCustomExercise(
        name: 'Tricep Pushdown',
        category: 'isolation',
        primaryMuscleGroupId: 'triceps',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Enter search query
      await tester.enterText(find.byType(TextField), 'Bicep');
      await tester.pumpAndSettle();

      // Assert - Should only show matching exercise
      expect(find.text('Bicep Curl'), findsOneWidget);
      expect(find.text('Tricep Pushdown'), findsNothing);
    });

    testWidgets('should show muscle group filter chips', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Assert - Should show All filter and some muscle groups
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('should navigate to add screen when FAB is tapped', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Tap the FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Assert - Should navigate to AddCustomExerciseScreen
      expect(find.text('Add Custom Exercise'), findsOneWidget);
    });
  });

  group('ExerciseLibraryScreen - Delete Functionality', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage);
      await provider.init();

      // Add a custom exercise for delete tests
      await provider.addCustomExercise(
        name: 'Exercise To Delete',
        category: 'compound',
        primaryMuscleGroupId: 'back',
      );
    });

    testWidgets('should show exercise details when tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Tap on the custom exercise
      await tester.tap(find.text('Exercise To Delete'));
      await tester.pumpAndSettle();

      // Assert - Should show details sheet with delete option
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('should show confirmation dialog when delete is tapped', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Tap on the custom exercise to open details
      await tester.tap(find.text('Exercise To Delete'));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Assert - Should show confirmation dialog
      expect(find.text('Delete Custom Exercise?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsWidgets);
    });

    testWidgets('should cancel delete when Cancel is tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          child: const ExerciseLibraryScreen(),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Act - Open details and tap delete
      await tester.tap(find.text('Exercise To Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - Exercise should still exist
      expect(
        provider.allExercises.any((e) => e.name == 'Exercise To Delete'),
        isTrue,
      );
    });
  });
}
