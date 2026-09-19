import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/exercise_manager.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  late MockStorageService mockStorage;
  late ExerciseManager manager;

  setUp(() {
    mockStorage = MockStorageService();
    manager = ExerciseManager(mockStorage);
  });

  group('ExerciseManager - loadExercises', () {
    test('loads built-in exercises and reflects correct counts', () async {
      await manager.loadExercises();

      final builtInCount = ExerciseDatabase.getAll().length;
      expect(manager.allExercises.length, builtInCount);
      expect(manager.builtInExercises.length, builtInCount);
      expect(manager.customExercises, isEmpty);
    });

    test('merges built-in and custom exercises', () async {
      mockStorage.addMockCustomExercise(
        Exercise(
          id: 'custom_001',
          name: 'Cable Lateral Raise',
          muscleActivations: [
            MuscleActivation(muscleGroupId: 'shoulders', activationPercentage: 100),
          ],
          category: 'isolation',
          isCustom: true,
        ),
      );

      await manager.loadExercises();

      expect(manager.customExercises.length, 1);
      expect(manager.allExercises.length, ExerciseDatabase.getAll().length + 1);
    });
  });

  group('ExerciseManager - getExercise / getExerciseName', () {
    setUp(() async => await manager.loadExercises());

    test('getExercise returns exercise by id via O(1) index', () {
      final first = ExerciseDatabase.getAll().first;
      final found = manager.getExercise(first.id);
      expect(found, isNotNull);
      expect(found!.id, first.id);
    });

    test('getExercise returns null for unknown id', () {
      expect(manager.getExercise('does_not_exist'), isNull);
    });

    test('getExerciseName returns name for known id', () {
      final first = ExerciseDatabase.getAll().first;
      expect(manager.getExerciseName(first.id), first.name);
    });

    test('getExerciseName returns fallback for unknown id', () {
      expect(manager.getExerciseName('nope'), 'Unknown Exercise');
    });
  });

  group('ExerciseManager - addCustomExercise', () {
    setUp(() async => await manager.loadExercises());

    test('adds custom exercise with correct fields', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Dragon Flag',
        category: 'compound',
        primaryMuscleGroupId: 'core',
      );

      expect(exercise.name, 'Dragon Flag');
      expect(exercise.category, 'compound');
      expect(exercise.isCustom, isTrue);
      expect(exercise.id, startsWith('custom_'));
      expect(exercise.muscleActivations.first.muscleGroupId, 'core');
      expect(exercise.muscleActivations.first.activationPercentage, 100);
    });

    test('normalizes category to lowercase', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Lat Pulldown',
        category: 'Isolation',
        primaryMuscleGroupId: 'back',
      );
      expect(exercise.category, 'isolation');
    });

    test('trims whitespace from name', () async {
      final exercise = await manager.addCustomExercise(
        name: '  Cable Row  ',
        category: 'compound',
        primaryMuscleGroupId: 'back',
      );
      expect(exercise.name, 'Cable Row');
    });

    test('appears in allExercises and customExercises after add', () async {
      final before = manager.allExercises.length;
      await manager.addCustomExercise(
        name: 'Face Pull',
        category: 'isolation',
        primaryMuscleGroupId: 'shoulders',
      );
      expect(manager.allExercises.length, before + 1);
      expect(manager.customExercises.length, 1);
      expect(manager.customExercises.first.name, 'Face Pull');
    });

    test('is findable via getExercise immediately after add', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Neck Curl',
        category: 'isolation',
        primaryMuscleGroupId: 'neck',
      );
      expect(manager.getExercise(exercise.id), isNotNull);
    });

    test('throws ArgumentError for empty name', () async {
      await expectLater(
        manager.addCustomExercise(
          name: '',
          category: 'compound',
          primaryMuscleGroupId: 'chest',
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid category', () async {
      await expectLater(
        manager.addCustomExercise(
          name: 'Test',
          category: 'cardio',
          primaryMuscleGroupId: 'legs',
        ),
        throwsArgumentError,
      );
    });
  });

  group('ExerciseManager - deleteCustomExercise', () {
    setUp(() async => await manager.loadExercises());

    test('removes custom exercise from memory and storage', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Cable Crunch',
        category: 'isolation',
        primaryMuscleGroupId: 'core',
      );

      final deleted = await manager.deleteCustomExercise(exercise.id);

      expect(deleted, isTrue);
      expect(manager.getExercise(exercise.id), isNull);
      expect(manager.customExercises.any((e) => e.id == exercise.id), isFalse);
    });

    test('returns false for built-in exercise', () async {
      final builtIn = ExerciseDatabase.getAll().first;
      final deleted = await manager.deleteCustomExercise(builtIn.id);
      expect(deleted, isFalse);
    });

    test('returns false when canDelete callback returns false', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Blocked Exercise',
        category: 'isolation',
        primaryMuscleGroupId: 'chest',
      );

      final deleted = await manager.deleteCustomExercise(
        exercise.id,
        canDelete: (_) => false,
      );

      expect(deleted, isFalse);
      expect(manager.getExercise(exercise.id), isNotNull);
    });

    test('returns false for unknown exercise id', () async {
      final deleted = await manager.deleteCustomExercise('does_not_exist');
      expect(deleted, isFalse);
    });
  });

  group('ExerciseManager - updateExercise', () {
    setUp(() async => await manager.loadExercises());

    test('updates name, category, and muscle group for a custom exercise', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Old Name',
        category: 'isolation',
        primaryMuscleGroupId: 'chest',
      );

      final updated = await manager.updateExercise(
        id: exercise.id,
        name: 'New Name',
        category: 'compound',
        primaryMuscleGroupId: 'back',
      );

      expect(updated.name, 'New Name');
      expect(updated.category, 'compound');
      expect(updated.muscleActivations.first.muscleGroupId, 'back');
      expect(manager.getExercise(exercise.id)!.name, 'New Name');
    });

    test('updates exerciseType to timeBased', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Dead Hang',
        category: 'compound',
        primaryMuscleGroupId: 'back',
        exerciseType: ExerciseType.weightAndReps,
      );

      final updated = await manager.updateExercise(
        id: exercise.id,
        exerciseType: ExerciseType.timeBased,
      );

      expect(updated.exerciseType, ExerciseType.timeBased);
      expect(manager.getExercise(exercise.id)!.exerciseType, ExerciseType.timeBased);
    });

    test('updates availableHandles when provided', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Cable Row',
        category: 'compound',
        primaryMuscleGroupId: 'back',
      );

      final updated = await manager.updateExercise(
        id: exercise.id,
        availableHandles: ['Bar', 'Rope'],
      );

      expect(updated.availableHandles, containsAll(['Bar', 'Rope']));
    });

    test('clears availableHandles when empty list is provided', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Pull-up',
        category: 'compound',
        primaryMuscleGroupId: 'back',
        availableHandles: ['Wide', 'Neutral'],
      );

      final updated = await manager.updateExercise(
        id: exercise.id,
        availableHandles: [],
      );

      expect(updated.availableHandles, isEmpty);
    });

    test('throws ArgumentError when exercise id not found', () async {
      await expectLater(
        manager.updateExercise(id: 'nonexistent_id'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when updated name is empty', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Valid Name',
        category: 'isolation',
        primaryMuscleGroupId: 'shoulders',
      );

      await expectLater(
        manager.updateExercise(id: exercise.id, name: '   '),
        throwsArgumentError,
      );
    });

    test('add with time-based exerciseType and handles stores both fields', () async {
      final exercise = await manager.addCustomExercise(
        name: 'Ring Rows',
        category: 'compound',
        primaryMuscleGroupId: 'back',
        exerciseType: ExerciseType.timeBased,
        availableHandles: ['Rings'],
      );

      expect(exercise.exerciseType, ExerciseType.timeBased);
      expect(exercise.availableHandles, contains('Rings'));
      expect(manager.getExercise(exercise.id)!.exerciseType, ExerciseType.timeBased);
    });
  });

  group('ExerciseManager - filtering and search', () {
    setUp(() async => await manager.loadExercises());

    test('getExercisesByMuscleGroup returns matching exercises', () {
      final chestExercises = manager.getExercisesByMuscleGroup('chest');
      expect(chestExercises, isNotEmpty);
      for (final e in chestExercises) {
        expect(
          e.muscleActivations.any((m) => m.muscleGroupId == 'chest'),
          isTrue,
        );
      }
    });

    test('getExercisesByCategory returns matching exercises (case-insensitive)',
        () {
      final compound = manager.getExercisesByCategory('Compound');
      expect(compound, isNotEmpty);
      for (final e in compound) {
        expect(e.category.toLowerCase(), 'compound');
      }
    });

    test('searchExercises returns matches by name substring', () {
      final results = manager.searchExercises('press');
      expect(results, isNotEmpty);
      for (final e in results) {
        expect(e.name.toLowerCase(), contains('press'));
      }
    });

    test('searchExercises is case-insensitive', () {
      final lower = manager.searchExercises('bench');
      final upper = manager.searchExercises('BENCH');
      expect(lower.map((e) => e.id).toSet(),
          equals(upper.map((e) => e.id).toSet()));
    });

    test('searchExercises returns empty list for no matches', () {
      expect(manager.searchExercises('xyznonexistent'), isEmpty);
    });
  });
}
