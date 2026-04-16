// Unit Tests for WorkoutProvider - Custom Exercise functionality

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  group('WorkoutProvider - Custom Exercise Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(mockStorage, programManager: ProgramManager(mockStorage));
      await provider.init();
    });

    group('addCustomExercise', () {
      test('should add exercise to the list', () async {
        // Arrange
        const name = 'Cable Lateral Raise';
        const category = 'isolation';
        const muscleGroup = 'shoulders';

        // Act
        await provider.addCustomExercise(
          name: name,
          category: category,
          primaryMuscleGroupId: muscleGroup,
        );

        // Assert
        expect(provider.allExercises.length, greaterThan(0));
        // firstWhere throws if not found, so finding it implies it exists/is not null
        final addedExercise = provider.allExercises.firstWhere(
          (e) => e.name == name,
        );
        expect(addedExercise.name, equals(name));
      });

      test('should set isCustom flag to true', () async {
        // Arrange
        const name = 'My Custom Exercise';
        const category = 'compound';
        const muscleGroup = 'chest';

        // Act
        await provider.addCustomExercise(
          name: name,
          category: category,
          primaryMuscleGroupId: muscleGroup,
        );

        // Assert
        final addedExercise = provider.allExercises.firstWhere(
          (e) => e.name == name,
        );
        expect(addedExercise.isCustom, isTrue);
      });

      test('should call saveCustomExercise on storage', () async {
        // Arrange
        const name = 'Test Exercise';
        const category = 'isolation';
        const muscleGroup = 'biceps';

        // Act
        await provider.addCustomExercise(
          name: name,
          category: category,
          primaryMuscleGroupId: muscleGroup,
        );

        // Assert - Check the mock storage was called
        expect(mockStorage.customExercises.length, equals(1));
        expect(mockStorage.customExercises.first.name, equals(name));
      });

      test('should generate unique ID prefixed with custom_', () async {
        // Arrange
        const name = 'Unique ID Test';
        const category = 'compound';
        const muscleGroup = 'back';

        // Act
        await provider.addCustomExercise(
          name: name,
          category: category,
          primaryMuscleGroupId: muscleGroup,
        );

        // Assert
        final addedExercise = provider.allExercises.firstWhere(
          (e) => e.name == name,
        );
        expect(addedExercise.id, startsWith('custom_'));
      });

      test('should normalize category to lowercase', () async {
        // Arrange
        const name = 'Category Test';
        const category = 'COMPOUND'; // Uppercase
        const muscleGroup = 'legs';

        // Act
        await provider.addCustomExercise(
          name: name,
          category: category,
          primaryMuscleGroupId: muscleGroup,
        );

        // Assert
        final addedExercise = provider.allExercises.firstWhere(
          (e) => e.name == name,
        );
        expect(addedExercise.category, equals('compound'));
      });

      test('should trim and normalize whitespace in name', () async {
        // Arrange
        const name = '  Whitespace   Test  '; // Extra spaces
        const category = 'isolation';
        const muscleGroup = 'triceps';

        // Act
        await provider.addCustomExercise(
          name: name,
          category: category,
          primaryMuscleGroupId: muscleGroup,
        );

        // Assert
        final addedExercise = provider.allExercises.firstWhere(
          (e) => e.name == 'Whitespace Test',
        );
        expect(addedExercise.name, equals('Whitespace Test'));
      });

      test('should throw ArgumentError for empty name', () async {
        // Arrange & Act & Assert
        expect(
          () => provider.addCustomExercise(
            name: '',
            category: 'compound',
            primaryMuscleGroupId: 'chest',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for empty muscle group', () async {
        // Arrange & Act & Assert
        expect(
          () => provider.addCustomExercise(
            name: 'Valid Name',
            category: 'compound',
            primaryMuscleGroupId: '',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for invalid category', () async {
        // Arrange & Act & Assert
        expect(
          () => provider.addCustomExercise(
            name: 'Valid Name',
            category: 'invalid_category',
            primaryMuscleGroupId: 'chest',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('deleteCustomExercise', () {
      test('should remove custom exercise from list', () async {
        // Arrange - Add an exercise first
        await provider.addCustomExercise(
          name: 'To Delete',
          category: 'compound',
          primaryMuscleGroupId: 'chest',
        );
        final exercise = provider.allExercises.firstWhere(
          (e) => e.name == 'To Delete',
        );
        final initialCount = provider.allExercises.length;

        // Act
        final result = await provider.deleteCustomExercise(exercise.id);

        // Assert
        expect(result, isTrue);
        expect(provider.allExercises.length, lessThan(initialCount));
        expect(
          provider.allExercises.where((e) => e.name == 'To Delete'),
          isEmpty,
        );
      });

      test(
        'should return false when trying to delete non-custom exercise',
        () async {
          // Arrange - Try to delete a built-in exercise ID
          const builtInId = 'bench_press';

          // Act
          final result = await provider.deleteCustomExercise(builtInId);

          // Assert
          expect(result, isFalse);
        },
      );

      test('should return false when exercise not found', () async {
        // Arrange
        const nonExistentId = 'custom_nonexistent';

        // Act
        final result = await provider.deleteCustomExercise(nonExistentId);

        // Assert
        expect(result, isFalse);
      });

      test('should call deleteCustomExercise on storage', () async {
        // Arrange - Add an exercise first
        await provider.addCustomExercise(
          name: 'Storage Delete Test',
          category: 'isolation',
          primaryMuscleGroupId: 'biceps',
        );
        final exercise = provider.allExercises.firstWhere(
          (e) => e.name == 'Storage Delete Test',
        );

        // Act
        await provider.deleteCustomExercise(exercise.id);

        // Assert - Check the mock storage was updated
        expect(
          mockStorage.customExercises.where((e) => e.id == exercise.id),
          isEmpty,
        );
      });
    });
  });
}
