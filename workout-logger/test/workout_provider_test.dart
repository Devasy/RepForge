// Unit Tests for WorkoutProvider - Custom Exercise functionality

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  group('WorkoutProvider Tests', () {
    late MockStorageService mockStorage;
    late WorkoutProvider provider;
    const draftKey = 'active_workout_draft';

    setUp(() async {
      mockStorage = MockStorageService();
      provider = WorkoutProvider(
        mockStorage,
        programManager: ProgramManager(mockStorage),
      );
      await provider.init();
    });

    Future<void> flushAsync() async {
      await Future<void>.delayed(Duration.zero);
    }

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

    group('getRecommendations / getLastSessionForExercise', () {
      WorkoutSession session(
        String id,
        DateTime date,
        List<ExerciseLog> logs,
      ) => WorkoutSession(id: id, date: date, exercises: logs, duration: 30);

      ExerciseLog log(String exerciseId, {List<WorkoutSet>? sets}) =>
          ExerciseLog(
            exerciseId: exerciseId,
            sets: sets ?? [WorkoutSet(weight: 50, reps: 8)],
          );

      test('getLastSessionForExercise returns the most-recently-dated log '
          'regardless of session insert order', () async {
        final markerSets = [WorkoutSet(weight: 100, reps: 5)];
        // Seed storage with sessions in non-chronological order so the
        // provider's internal _sessions list does not happen to be sorted.
        mockStorage.addMockSession(
          session('old', DateTime(2025, 1, 1), [log('bench')]),
        );
        mockStorage.addMockSession(
          session('newest', DateTime(2025, 6, 1), [
            log('bench', sets: markerSets),
          ]),
        );
        mockStorage.addMockSession(
          session('mid', DateTime(2025, 3, 1), [log('bench')]),
        );

        // Re-init so the provider reloads sessions from the mock.
        await provider.init();

        final last = provider.getLastSessionForExercise('bench');

        expect(last, isNotNull);
        expect(last!.sets.first.weight, 100);
        expect(last.sets.first.reps, 5);
      });

      test('getLastSessionForExercise returns null when never logged', () {
        expect(provider.getLastSessionForExercise('never_done'), isNull);
      });

      test('getRecommendations bases output on the most-recent log', () async {
        final marker = [WorkoutSet(weight: 120, reps: 6)];
        mockStorage.addMockSession(
          session('old', DateTime(2025, 1, 1), [log('bench')]),
        );
        mockStorage.addMockSession(
          session('newest', DateTime(2025, 8, 1), [log('bench', sets: marker)]),
        );

        await provider.init();

        final recs = provider.getRecommendations('bench');
        // Default fallback is 3 generic sets at low weight; a real
        // recommendation derived from the marker should be non-empty and
        // weighted near 120kg, not the default.
        expect(recs, isNotEmpty);
        expect(recs.first.weight, greaterThanOrEqualTo(120));
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

    group('active workout draft persistence', () {
      test('persists draft when adding a set', () async {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        provider.addSet(WorkoutSet(weight: 100, reps: 5));

        await flushAsync();

        final rawDraft = mockStorage.settings[draftKey];
        expect(rawDraft, isNotNull);
        expect(rawDraft, isNotEmpty);

        final draft = Map<String, dynamic>.from(jsonDecode(rawDraft!) as Map);
        final logs = List<Map<String, dynamic>>.from(
          (draft['currentExerciseLogs'] as List).map(
            (log) => Map<String, dynamic>.from(log as Map),
          ),
        );
        final sets = List<Map<String, dynamic>>.from(
          (logs.first['sets'] as List).map(
            (set) => Map<String, dynamic>.from(set as Map),
          ),
        );

        expect(draft['schemaVersion'], equals(1));
        expect(sets.length, equals(1));
      });

      test('persists program context in draft payload', () async {
        final day = ProgramDay(
          id: 'day_push',
          name: 'Push',
          exercises: [
            ProgramExerciseSlot(
              exerciseId: 'bench_press',
              sets: 4,
              minReps: 6,
              maxReps: 10,
              restSeconds: 120,
            ),
          ],
        );
        final week = ProgramWeek(
          weekNumber: 3,
          isDeload: true,
          deloadIntensityFactor: 0.9,
          deloadSetReduction: 1,
          days: [day],
        );

        provider.startWorkout(
          exerciseIds: const ['bench_press'],
          programDay: day,
          programWeek: week,
        );
        provider.addSet(WorkoutSet(weight: 100, reps: 5));

        await flushAsync();

        final rawDraft = mockStorage.settings[draftKey];
        expect(rawDraft, isNotNull);
        final draft = Map<String, dynamic>.from(jsonDecode(rawDraft!) as Map);

        final draftProgramDay = Map<String, dynamic>.from(
          draft['programDay'] as Map,
        );
        final draftProgramWeek = Map<String, dynamic>.from(
          draft['programWeek'] as Map,
        );

        expect(draftProgramDay['id'], equals(day.id));
        expect(draftProgramWeek['weekNumber'], equals(week.weekNumber));
      });

      test('persists currentExerciseIndex when navigating', () async {
        provider.startWorkout(exerciseIds: const ['bench_press', 'squat']);

        final moved = provider.nextExercise();
        await flushAsync();

        expect(moved, isTrue);

        final rawDraft = mockStorage.settings[draftKey];
        expect(rawDraft, isNotNull);
        final draft = Map<String, dynamic>.from(jsonDecode(rawDraft!) as Map);

        expect(draft['currentExerciseIndex'], equals(1));
      });

      test('clears draft after finishing workout', () async {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        provider.addSet(WorkoutSet(weight: 80, reps: 8));
        await flushAsync();

        await provider.finishWorkout();

        expect(mockStorage.settings[draftKey], equals(''));
      });

      test('clears draft after canceling workout', () async {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        provider.addSet(WorkoutSet(weight: 80, reps: 8));
        await flushAsync();

        await provider.cancelWorkout();

        expect(mockStorage.settings[draftKey], equals(''));
      });

      test(
        'clear waits for pending draft writes to avoid stale payload',
        () async {
          mockStorage.saveSettingDelayResolver = (_, value) {
            return value.isEmpty
                ? const Duration(milliseconds: 1)
                : const Duration(milliseconds: 30);
          };

          provider.startWorkout(exerciseIds: const ['bench_press']);
          provider.addSet(WorkoutSet(weight: 80, reps: 8));

          await provider.cancelWorkout();
          await Future<void>.delayed(const Duration(milliseconds: 80));

          expect(mockStorage.settings[draftKey], equals(''));
        },
      );

      test('restores draft during init without extra writes', () async {
        final routine = Routine(
          id: 'routine_1',
          name: 'Push Day',
          exerciseIds: const ['bench_press'],
        );
        final day = ProgramDay(
          id: 'day_1',
          name: 'Push',
          exercises: [
            ProgramExerciseSlot(
              exerciseId: 'bench_press',
              sets: 4,
              minReps: 6,
              maxReps: 10,
              restSeconds: 90,
            ),
          ],
        );
        final week = ProgramWeek(weekNumber: 1, days: [day]);
        await mockStorage.saveRoutine(routine);

        final draft = jsonEncode({
          'schemaVersion': 1,
          'startTime': DateTime(2026, 4, 26, 18, 43, 11).toIso8601String(),
          'routineId': routine.id,
          'programDay': day.toJson(),
          'programWeek': week.toJson(),
          'currentExerciseIndex': 0,
          'currentExerciseLogs': [
            ExerciseLog(
              exerciseId: 'bench_press',
              sets: [WorkoutSet(weight: 75, reps: 10)],
            ).toJson(),
          ],
        });
        await mockStorage.saveSetting(draftKey, draft);

        final restoringProvider = WorkoutProvider(
          mockStorage,
          programManager: ProgramManager(mockStorage),
        );
        await restoringProvider.init();

        expect(restoringProvider.hasActiveWorkout, isTrue);
        expect(restoringProvider.activeRoutine?.id, equals(routine.id));
        expect(restoringProvider.activeProgramDay?.id, equals(day.id));
        expect(
          restoringProvider.activeProgramWeek?.weekNumber,
          equals(week.weekNumber),
        );
        expect(restoringProvider.currentExerciseLogs.length, equals(1));
        expect(
          restoringProvider.currentExerciseLogs.first.sets.length,
          equals(1),
        );
        expect(mockStorage.saveSettingCallCount, equals(1));
      });

      test('restores draft even when routine was deleted', () async {
        final draft = jsonEncode({
          'schemaVersion': 1,
          'startTime': DateTime(2026, 4, 26, 18, 43, 11).toIso8601String(),
          'routineId': 'missing_routine',
          'currentExerciseIndex': 0,
          'currentExerciseLogs': [
            ExerciseLog(
              exerciseId: 'bench_press',
              sets: [WorkoutSet(weight: 90, reps: 6)],
            ).toJson(),
          ],
        });
        await mockStorage.saveSetting(draftKey, draft);

        final restoringProvider = WorkoutProvider(
          mockStorage,
          programManager: ProgramManager(mockStorage),
        );
        await restoringProvider.init();

        expect(restoringProvider.hasActiveWorkout, isTrue);
        expect(restoringProvider.activeRoutine, isNull);
        expect(restoringProvider.currentExerciseLogs.length, equals(1));
      });

      test('malformed draft is cleared and does not crash init', () async {
        await mockStorage.saveSetting(draftKey, '{not valid json');

        final restoringProvider = WorkoutProvider(
          mockStorage,
          programManager: ProgramManager(mockStorage),
        );
        await restoringProvider.init();

        expect(restoringProvider.hasActiveWorkout, isFalse);
        expect(mockStorage.settings[draftKey], equals(''));
      });

      test('throws when startWorkout is called with active workout', () {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        provider.addSet(WorkoutSet(weight: 100, reps: 5));

        expect(
          () => provider.startWorkout(exerciseIds: const ['squat']),
          throwsA(isA<WorkoutInProgressError>()),
        );
        expect(
          provider.currentExerciseLogs.first.exerciseId,
          equals('bench_press'),
        );
        expect(provider.currentExerciseLogs.first.sets.length, equals(1));
      });

      test('does not throw on first startWorkout call', () {
        expect(provider.hasActiveWorkout, isFalse);

        expect(
          () => provider.startWorkout(exerciseIds: const ['bench_press']),
          returnsNormally,
        );

        expect(provider.hasActiveWorkout, isTrue);
      });
    });
  });
}
