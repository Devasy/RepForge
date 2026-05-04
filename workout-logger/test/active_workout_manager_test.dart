import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/active_workout_manager.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  late MockStorageService mockStorage;
  late ActiveWorkoutManager manager;

  setUp(() {
    mockStorage = MockStorageService();
    manager = ActiveWorkoutManager(mockStorage);
  });

  group('ActiveWorkoutManager - startWorkout', () {
    test('starts with exerciseIds and sets initial state', () {
      manager.startWorkout(exerciseIds: ['ex1', 'ex2', 'ex3']);

      expect(manager.hasActiveWorkout, isTrue);
      expect(manager.totalExercises, 3);
      expect(manager.currentExerciseIndex, 0);
      expect(manager.currentExerciseId, 'ex1');
      expect(manager.isFirstExercise, isTrue);
      expect(manager.isLastExercise, isFalse);
      expect(manager.workoutStartTime, isNotNull);
    });

    test('starts with a routine and uses its exerciseIds', () {
      final routine = Routine(
        id: 'r1',
        name: 'Push Day',
        exerciseIds: ['ex1', 'ex2'],
      );

      manager.startWorkout(routine: routine);

      expect(manager.hasActiveWorkout, isTrue);
      expect(manager.activeRoutine, same(routine));
      expect(manager.totalExercises, 2);
      expect(manager.currentExerciseId, 'ex1');
    });

    test('throws StateError if workout already in progress', () {
      manager.startWorkout(exerciseIds: ['ex1']);
      expect(
        () => manager.startWorkout(exerciseIds: ['ex2']),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError with no exercises', () {
      expect(
        () => manager.startWorkout(exerciseIds: []),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ActiveWorkoutManager - addSet / removeLastSet', () {
    setUp(() => manager.startWorkout(exerciseIds: ['ex1']));

    test('addSet appends to current exercise log', () {
      final set = WorkoutSet(weight: 100, reps: 8);
      manager.addSet(set);

      expect(manager.currentExerciseLog!.sets.length, 1);
      expect(manager.currentExerciseLog!.sets.first.weight, 100);
      expect(manager.currentExerciseLog!.sets.first.reps, 8);
    });

    test('addSet accumulates multiple sets', () {
      manager.addSet(WorkoutSet(weight: 80, reps: 12));
      manager.addSet(WorkoutSet(weight: 85, reps: 10));
      manager.addSet(WorkoutSet(weight: 90, reps: 8));

      expect(manager.currentExerciseLog!.sets.length, 3);
    });

    test('removeLastSet removes the last added set', () {
      manager.addSet(WorkoutSet(weight: 80, reps: 12));
      manager.addSet(WorkoutSet(weight: 85, reps: 10));
      manager.removeLastSet();

      expect(manager.currentExerciseLog!.sets.length, 1);
      expect(manager.currentExerciseLog!.sets.first.weight, 80);
    });

    test('removeLastSet is a no-op when no sets logged', () {
      manager.removeLastSet();
      expect(manager.currentExerciseLog!.sets, isEmpty);
    });
  });

  group('ActiveWorkoutManager - updateCurrentExerciseNotes', () {
    setUp(() => manager.startWorkout(exerciseIds: ['ex1']));

    test('sets notes on current exercise', () {
      manager.updateCurrentExerciseNotes('Focus on form');
      expect(manager.currentExerciseLog!.notes, 'Focus on form');
    });

    test('clears notes when null is passed', () {
      manager.updateCurrentExerciseNotes('Some note');
      manager.updateCurrentExerciseNotes(null);
      expect(manager.currentExerciseLog!.notes, isNull);
    });
  });

  group('ActiveWorkoutManager - exercise navigation', () {
    setUp(() => manager.startWorkout(exerciseIds: ['ex1', 'ex2', 'ex3']));

    test('nextExercise advances index and returns true', () {
      final moved = manager.nextExercise();

      expect(moved, isTrue);
      expect(manager.currentExerciseIndex, 1);
      expect(manager.currentExerciseId, 'ex2');
      expect(manager.isFirstExercise, isFalse);
    });

    test('nextExercise returns false at last exercise', () {
      manager.nextExercise();
      manager.nextExercise();
      final moved = manager.nextExercise();

      expect(moved, isFalse);
      expect(manager.currentExerciseIndex, 2);
      expect(manager.isLastExercise, isTrue);
    });

    test('previousExercise returns false at first exercise', () {
      final moved = manager.previousExercise();
      expect(moved, isFalse);
      expect(manager.currentExerciseIndex, 0);
    });

    test('previousExercise moves back and returns true', () {
      manager.nextExercise();
      final moved = manager.previousExercise();

      expect(moved, isTrue);
      expect(manager.currentExerciseIndex, 0);
      expect(manager.isFirstExercise, isTrue);
    });

    test('goToExercise jumps to specified index', () {
      manager.goToExercise(2);
      expect(manager.currentExerciseIndex, 2);
      expect(manager.currentExerciseId, 'ex3');
      expect(manager.isLastExercise, isTrue);
    });

    test('single-exercise workout: isFirst and isLast both true', () {
      final mgr = ActiveWorkoutManager(mockStorage);
      mgr.startWorkout(exerciseIds: ['solo']);

      expect(mgr.isFirstExercise, isTrue);
      expect(mgr.isLastExercise, isTrue);
    });
  });

  group('ActiveWorkoutManager - finishWorkout', () {
    test('saves session to storage and clears state', () async {
      manager.startWorkout(exerciseIds: ['ex1', 'ex2']);
      manager.addSet(WorkoutSet(weight: 100, reps: 5));
      manager.nextExercise();
      manager.addSet(WorkoutSet(weight: 60, reps: 12));

      final session = await manager.finishWorkout(notes: 'Good session');

      expect(manager.hasActiveWorkout, isFalse);
      expect(manager.currentExerciseLogs, isEmpty);
      expect(session.exercises.length, 2);
      expect(session.notes, 'Good session');
      expect(mockStorage.sessions, isNotEmpty);
      expect(mockStorage.sessions.first.id, session.id);
    });

    test('filters out exercises with no sets', () async {
      manager.startWorkout(exerciseIds: ['ex1', 'ex2']);
      // Only log sets on ex1; ex2 has none
      manager.addSet(WorkoutSet(weight: 80, reps: 10));

      final session = await manager.finishWorkout();

      expect(session.exercises.length, 1);
      expect(session.exercises.first.exerciseId, 'ex1');
    });

    test('calls onWorkoutSaved callback with the session', () async {
      WorkoutSession? received;
      final mgr = ActiveWorkoutManager(
        mockStorage,
        onWorkoutSaved: (s) => received = s,
      );
      mgr.startWorkout(exerciseIds: ['ex1']);
      mgr.addSet(WorkoutSet(weight: 50, reps: 10));
      final session = await mgr.finishWorkout();

      expect(received, isNotNull);
      expect(received!.id, session.id);
    });

    test('records routine id when started with a routine', () async {
      final routine = Routine(
        id: 'r42',
        name: 'Leg Day',
        exerciseIds: ['ex1'],
      );
      manager.startWorkout(routine: routine);
      manager.addSet(WorkoutSet(weight: 120, reps: 6));
      final session = await manager.finishWorkout();

      expect(session.routineId, 'r42');
    });
  });

  group('ActiveWorkoutManager - cancelWorkout', () {
    test('clears state without saving', () {
      manager.startWorkout(exerciseIds: ['ex1']);
      manager.addSet(WorkoutSet(weight: 80, reps: 10));
      manager.cancelWorkout();

      expect(manager.hasActiveWorkout, isFalse);
      expect(manager.currentExerciseLogs, isEmpty);
      expect(mockStorage.sessions, isEmpty);
    });
  });
}
