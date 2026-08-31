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

      test('getRecommendations holds load when the primary muscle is still '
          'under-recovered from a session a couple hours ago', () async {
        // bench_press's primary muscle is chest (tau=48h); a session this
        // recent leaves chest well under the 70% recovery threshold.
        final recentTimestamp = DateTime.now().subtract(const Duration(hours: 2));
        mockStorage.addMockSession(
          session('recent', recentTimestamp, [
            log('bench_press', sets: [WorkoutSet(weight: 80, reps: 8)]),
          ]),
        );

        await provider.init();

        final recs = provider.getRecommendations('bench_press');

        expect(recs, isNotEmpty);
        expect(recs.first.confidence, 'low');
        expect(recs.first.reasoning, contains('recovered'));
        expect(recs.first.weight, 80);
        expect(recs.first.reps, 8);
      });

      test('getRecommendations holds load when readinessBand is low, even '
          'when reps are otherwise ready to progress', () async {
        mockStorage.addMockSession(
          session('old', DateTime(2025, 1, 1), [
            log('bench_press', sets: [WorkoutSet(weight: 60, reps: 12)]),
          ]),
        );
        await provider.init();

        final normal = provider.getRecommendations('bench_press');
        // Baseline: with reps at the ceiling and no readiness signal, this
        // progresses (weight bump), confirming the low-readiness case below
        // is actually suppressing something.
        expect(normal.first.weight, greaterThan(60));

        final lowReadiness = provider.getRecommendations(
          'bench_press',
          readinessBand: ReadinessBand.low,
        );
        expect(lowReadiness.first.weight, 60);
        expect(lowReadiness.first.reps, 12);
        expect(lowReadiness.first.confidence, 'low');
        expect(lowReadiness.first.reasoning, contains('readiness'));
      });

      test('getRecommendations ignores a moderate/high readinessBand', () async {
        mockStorage.addMockSession(
          session('old', DateTime(2025, 1, 1), [
            log('bench_press', sets: [WorkoutSet(weight: 60, reps: 12)]),
          ]),
        );
        await provider.init();

        final recs = provider.getRecommendations(
          'bench_press',
          readinessBand: ReadinessBand.moderate,
        );
        expect(recs.first.weight, greaterThan(60));
      });

      test('getRecommendations is unaffected by a realistic amount of prior '
          'same-session training — the fatigue calibration is deliberately '
          'inert at real-world session sizes (see session_fatigue.dart)',
          () async {
        await provider.addCustomExercise(
          name: 'Ex One',
          category: 'compound',
          primaryMuscleGroupId: 'chest',
        );
        await provider.addCustomExercise(
          name: 'Ex Two',
          category: 'compound',
          primaryMuscleGroupId: 'chest',
        );
        final ex1 = provider.allExercises.firstWhere((e) => e.name == 'Ex One');
        final ex2 = provider.allExercises.firstWhere((e) => e.name == 'Ex Two');

        // History for ex2 so its recommendation is a real weight-bump
        // scenario (reps at the ceiling), not the no-history default.
        mockStorage.addMockSession(
          session('old', DateTime(2025, 1, 1), [
            log(ex2.id, sets: [WorkoutSet(weight: 60, reps: 12)]),
          ]),
        );
        await provider.init();

        // Start a live session covering both exercises; log a realistic
        // number of sets of ex1 first (12 — more than a real working
        // exercise would have), then ask for ex2's recommendation.
        provider.startWorkout(exerciseIds: [ex1.id, ex2.id]);
        for (var i = 0; i < 12; i++) {
          provider.addSet(WorkoutSet(weight: 100, reps: 8));
        }
        provider.nextExercise();

        final withPriorSets = provider.getRecommendations(ex2.id);

        // Compare against a fresh provider with no in-progress session at
        // all (only ex2's history) to isolate the same-session effect.
        final freshMock = MockStorageService();
        freshMock.addMockSession(
          session('old', DateTime(2025, 1, 1), [
            log(ex2.id, sets: [WorkoutSet(weight: 60, reps: 12)]),
          ]),
        );
        final freshProvider = WorkoutProvider(
          freshMock,
          programManager: ProgramManager(freshMock),
        );
        freshMock.addMockCustomExercise(ex1);
        freshMock.addMockCustomExercise(ex2);
        await freshProvider.init();
        final withoutPriorSets = freshProvider.getRecommendations(ex2.id);

        expect(withoutPriorSets.first.weight, greaterThan(60)); // baseline progresses
        expect(withPriorSets.first.weight, withoutPriorSets.first.weight);
      });

      test('getRecommendations dampens after an extreme, unrealistic amount '
          'of same-session prior training — proves the fatigue mechanism is '
          'wired end-to-end even though realistic sessions never reach it',
          () async {
        await provider.addCustomExercise(
          name: 'Warmup Ex',
          category: 'isolation',
          primaryMuscleGroupId: 'chest',
        );
        await provider.addCustomExercise(
          name: 'Target Ex',
          category: 'compound',
          primaryMuscleGroupId: 'chest',
        );
        final warmupEx =
            provider.allExercises.firstWhere((e) => e.name == 'Warmup Ex');
        final targetEx =
            provider.allExercises.firstWhere((e) => e.name == 'Target Ex');

        mockStorage.addMockSession(
          session('old', DateTime(2025, 1, 1), [
            log(targetEx.id, sets: [WorkoutSet(weight: 60, reps: 12)]),
          ]),
        );
        await provider.init();

        provider.startWorkout(exerciseIds: [warmupEx.id, targetEx.id]);
        // Far beyond any real single-exercise set count — well past the
        // point (raw total > softCap = 16.0) where the factor engages.
        for (var i = 0; i < 40; i++) {
          provider.addSet(WorkoutSet(
            weight: 100,
            reps: 8,
            timestamp: DateTime(2026, 1, 1, 10, i * 3),
          ));
        }
        provider.nextExercise();

        final recs = provider.getRecommendations(targetEx.id);
        // 40 hard sets push the raw accumulation to ~26.7, past _hardCap, so
        // the factor clamps to 1.0 and SessionFatigueRule hard-holds. Naming
        // the exact weight and reasoning distinguishes that from
        // DoubleProgressionRule's partial-increment scaling — `lessThan(65)`
        // alone was true of both outcomes.
        expect(recs.first.weight, 60.0);
        expect(recs.first.reasoning, contains('earlier in today'));
      });

      group('recordSessionEffort / effortCalibrationOffset', () {
        test('effortCalibrationOffset defaults to 0.0 when never answered', () {
          expect(provider.effortCalibrationOffset, 0.0);
        });

        test(
            'records sessionEffort on the session and updates the rolling offset',
            () async {
          mockStorage.addMockSession(
            session('s1', DateTime(2025, 1, 1), [log('bench_press')]),
          );
          await provider.init();
          final sessionId =
              provider.sessions.firstWhere((s) => s.id == 's1').id;

          await provider.recordSessionEffort(sessionId, 3); // Brutal

          final updated = provider.sessions.firstWhere((s) => s.id == sessionId);
          expect(updated.sessionEffort, 3);
          expect(provider.effortCalibrationOffset, greaterThan(0.0));
        });

        test('persists the offset across a reload', () async {
          mockStorage.addMockSession(
            session('s1', DateTime(2025, 1, 1), [log('bench_press')]),
          );
          await provider.init();
          await provider.recordSessionEffort('s1', 1); // Easy
          final offsetAfterRecording = provider.effortCalibrationOffset;
          expect(offsetAfterRecording, lessThan(0.0));

          // A second init() on the same instance would pass even if the
          // offset were only ever held in memory. Build a fresh provider over
          // the same storage, as the draft-restore test does, so this can
          // only pass if the value actually round-tripped through storage.
          final reloaded = WorkoutProvider(
            mockStorage,
            programManager: ProgramManager(mockStorage),
          );
          await reloaded.init();

          expect(reloaded.effortCalibrationOffset,
              closeTo(offsetAfterRecording, 0.0001));
        });

        test('does nothing for an unknown session id', () async {
          await provider.recordSessionEffort('does-not-exist', 3);
          expect(provider.effortCalibrationOffset, 0.0);
        });

        test('re-answering the chip replaces the previous answer rather than '
            'folding both in', () async {
          mockStorage.addMockSession(
            session('s1', DateTime(2025, 1, 1), [log('bench_press')]),
          );
          await provider.init();

          // The summary screen leaves the chip tappable, so changing your
          // mind must land on the same offset as answering Easy once.
          await provider.recordSessionEffort('s1', 3); // Brutal
          await provider.recordSessionEffort('s1', 1); // ...actually, Easy
          final afterChange = provider.effortCalibrationOffset;

          final fresh = WorkoutProvider(
            mockStorage,
            programManager: ProgramManager(mockStorage),
          );
          mockStorage.settings.remove('effort.calibrationOffset');
          await fresh.init();
          await fresh.recordSessionEffort('s1', 1); // Easy, first time

          expect(afterChange, closeTo(fresh.effortCalibrationOffset, 0.0001));
        });

        test('overlapping taps do not let a failed write clobber a later one',
            () async {
          mockStorage.addMockSession(
            session('s1', DateTime(2025, 1, 1), [log('bench_press')]),
          );
          await provider.init();

          // The chips stay tappable while a write is in flight. Delay the
          // offset write so a second tap can be issued mid-flight, and fail
          // the first one so it takes its rollback path.
          mockStorage.saveSettingDelayResolver = (key, value) =>
              key == 'effort.calibrationOffset'
                  ? const Duration(milliseconds: 20)
                  : Duration.zero;
          var offsetWrites = 0;
          mockStorage.saveSettingErrorResolver = (key, value) {
            if (key != 'effort.calibrationOffset') return null;
            offsetWrites++;
            return offsetWrites == 1 ? Exception('disk full') : null;
          };

          final first = provider.recordSessionEffort('s1', 3); // Brutal
          final second = provider.recordSessionEffort('s1', 1); // Easy

          await expectLater(first, throwsA(isA<Exception>()));
          await second;

          mockStorage.saveSettingErrorResolver = null;
          mockStorage.saveSettingDelayResolver = null;

          // Serialised, the second call runs after the first has rolled back
          // and re-reads state, so provider and storage agree on Easy.
          expect(provider.sessions.firstWhere((s) => s.id == 's1').sessionEffort,
              1);
          expect(
            mockStorage.sessions.firstWhere((s) => s.id == 's1').sessionEffort,
            1,
            reason: 'the failed first write must not roll back over the second',
          );
        });
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

    group('init / loadAllData', () {
      test('allExercises contains built-in exercises after init', () {
        expect(provider.allExercises, isNotEmpty);
      });

      test('sessions loaded from storage after init', () async {
        mockStorage.addMockSession(WorkoutSession(
          id: 's1',
          date: DateTime(2026, 1, 1),
          exercises: [],
          duration: 30,
        ));
        final p2 = WorkoutProvider(
          mockStorage,
          programManager: ProgramManager(mockStorage),
        );
        await p2.init();
        expect(p2.sessions, hasLength(1));
      });

      test('routines loaded from storage after init', () async {
        mockStorage.addMockRoutine(
          Routine(id: 'r1', name: 'Push Day', exerciseIds: []),
        );
        final p2 = WorkoutProvider(
          mockStorage,
          programManager: ProgramManager(mockStorage),
        );
        await p2.init();
        expect(p2.routines, hasLength(1));
      });
    });

    group('active workout flow', () {
      test('hasActiveWorkout is false before startWorkout', () {
        expect(provider.hasActiveWorkout, isFalse);
      });

      test('hasActiveWorkout is true after startWorkout', () {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        expect(provider.hasActiveWorkout, isTrue);
      });

      test('addSet increases currentExerciseLog sets count', () {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        provider.addSet(WorkoutSet(weight: 60, reps: 10));
        expect(provider.currentExerciseLog!.sets, hasLength(1));
      });

      test('removeLastSet decreases sets count', () {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        provider.addSet(WorkoutSet(weight: 60, reps: 10));
        provider.addSet(WorkoutSet(weight: 60, reps: 10));
        provider.removeLastSet();
        expect(provider.currentExerciseLog!.sets, hasLength(1));
      });

      test('nextExercise advances currentExerciseIndex', () {
        provider.startWorkout(exerciseIds: const ['bench_press', 'squat']);
        final moved = provider.nextExercise();
        expect(moved, isTrue);
        expect(provider.currentExerciseIndex, 1);
      });

      test('finishWorkout saves session and clears active state', () async {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        provider.addSet(WorkoutSet(weight: 60, reps: 10));
        await provider.finishWorkout();
        expect(provider.hasActiveWorkout, isFalse);
        expect(provider.sessions, hasLength(1));
      });

      test('cancelWorkout clears state without saving a session', () async {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        provider.addSet(WorkoutSet(weight: 60, reps: 10));
        await provider.cancelWorkout();
        expect(provider.hasActiveWorkout, isFalse);
        expect(provider.sessions, isEmpty);
      });
    });

    group('startWorkoutSafely', () {
      test('starts workout and returns true when no conflict', () async {
        final started = await provider.startWorkoutSafely(
          exerciseIds: const ['bench_press'],
          onConflict: () async => StartWorkoutConflictAction.cancel,
        );
        expect(started, isTrue);
        expect(provider.hasActiveWorkout, isTrue);
      });

      test('calls onConflict callback when a workout is already active',
          () async {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        var conflictCalled = false;
        await provider.startWorkoutSafely(
          exerciseIds: const ['squat'],
          onConflict: () async {
            conflictCalled = true;
            return StartWorkoutConflictAction.cancel;
          },
        );
        expect(conflictCalled, isTrue);
      });

      test('cancels existing and starts new when discardAndStart chosen',
          () async {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        final started = await provider.startWorkoutSafely(
          exerciseIds: const ['squat'],
          onConflict: () async => StartWorkoutConflictAction.discardAndStart,
        );
        expect(started, isTrue);
        expect(
          provider.currentExerciseLogs.first.exerciseId,
          'squat',
        );
      });

      test('returns false when conflict resolved with cancel', () async {
        provider.startWorkout(exerciseIds: const ['bench_press']);
        final started = await provider.startWorkoutSafely(
          exerciseIds: const ['squat'],
          onConflict: () async => StartWorkoutConflictAction.cancel,
        );
        expect(started, isFalse);
      });
    });

    group('getExerciseName', () {
      test('returns name for a known built-in exercise id', () {
        final name = provider.getExerciseName('bench_press');
        expect(name, isNot('Unknown Exercise'));
        expect(name, isNotEmpty);
      });

      test('returns fallback for unknown exercise id', () {
        expect(provider.getExerciseName('no_such_exercise'), 'Unknown Exercise');
      });
    });

    group('deleteCustomExercise - routine guard', () {
      test('returns false when exercise is referenced in a routine', () async {
        await provider.addCustomExercise(
          name: 'Cable Fly',
          category: 'isolation',
          primaryMuscleGroupId: 'chest',
        );
        final exerciseId =
            provider.allExercises.firstWhere((e) => e.isCustom).id;
        await provider.createRoutine('Test Routine', [exerciseId]);
        final deleted = await provider.deleteCustomExercise(exerciseId);
        expect(deleted, isFalse);
        expect(
          provider.allExercises.any((e) => e.id == exerciseId),
          isTrue,
        );
      });
    });
  });
}
