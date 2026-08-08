import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/data/exercise_database.dart';

void main() {
  late SqliteStorageService storage;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    storage = SqliteStorageService(databasePathOverride: inMemoryDatabasePath);
    await storage.init();
  });

  group('SqliteStorageService — init', () {
    test('seeds default muscle groups', () async {
      final groups = await storage.getAllMuscleGroups();
      expect(groups, isNotEmpty);
      expect(groups.any((g) => g.name == 'Chest'), isTrue);
    });
  });

  group('SqliteStorageService — workout sessions', () {
    test('saveWorkoutSession + getWorkoutSession round-trips nested sets', () async {
      final session = WorkoutSession(
        id: 's1',
        date: DateTime(2026, 7, 10),
        duration: 45,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [
              WorkoutSet(weight: 60, reps: 8),
              WorkoutSet(weight: 65, reps: 6, isDropset: true, drops: [
                DropsetEntry(weight: 50, reps: 10),
              ]),
            ],
          ),
        ],
      );

      await storage.saveWorkoutSession(session);
      final fetched = await storage.getWorkoutSession('s1');

      expect(fetched, isNotNull);
      expect(fetched!.duration, 45);
      expect(fetched.exercises.single.sets.length, 2);
      expect(fetched.exercises.single.sets.first.weight, 60);
      expect(fetched.exercises.single.sets[1].isDropset, isTrue);
      expect(fetched.exercises.single.sets[1].drops!.single.weight, 50);
    });

    test('saveWorkoutSession overwrites previous sets on re-save', () async {
      final session = WorkoutSession(
        id: 's2',
        date: DateTime(2026, 7, 1),
        duration: 30,
        exercises: [
          ExerciseLog(exerciseId: 'squat', sets: [WorkoutSet(weight: 100, reps: 5)]),
        ],
      );
      await storage.saveWorkoutSession(session);

      final updated = session.copyWith(
        exercises: [
          ExerciseLog(exerciseId: 'squat', sets: [WorkoutSet(weight: 110, reps: 3)]),
        ],
      );
      await storage.saveWorkoutSession(updated);

      final fetched = await storage.getWorkoutSession('s2');
      expect(fetched!.exercises.single.sets.length, 1);
      expect(fetched.exercises.single.sets.first.weight, 110);
    });

    test('deleteWorkoutSession removes the session', () async {
      final session = WorkoutSession(
        id: 's3',
        date: DateTime.now(),
        duration: 20,
        exercises: [ExerciseLog(exerciseId: 'row', sets: [WorkoutSet(weight: 40, reps: 10)])],
      );
      await storage.saveWorkoutSession(session);
      await storage.deleteWorkoutSession('s3');
      expect(await storage.getWorkoutSession('s3'), isNull);
    });

    test('getAllWorkoutSessions returns most-recent first', () async {
      await storage.saveWorkoutSession(
        WorkoutSession(id: 'old', date: DateTime(2026, 1, 1), duration: 10, exercises: []),
      );
      await storage.saveWorkoutSession(
        WorkoutSession(id: 'new', date: DateTime(2026, 6, 1), duration: 10, exercises: []),
      );
      final all = await storage.getAllWorkoutSessions();
      expect(all.first.id, 'new');
    });

    test('getSessionsInDateRange filters by date', () async {
      await storage.saveWorkoutSession(
        WorkoutSession(id: 'a', date: DateTime(2026, 1, 1), duration: 10, exercises: []),
      );
      await storage.saveWorkoutSession(
        WorkoutSession(id: 'b', date: DateTime(2026, 6, 1), duration: 10, exercises: []),
      );
      final result = await storage.getSessionsInDateRange(DateTime(2026, 5, 1), DateTime(2026, 7, 1));
      expect(result.map((s) => s.id), ['b']);
    });

    test('getSessionsForExercise filters by exercise id', () async {
      await storage.saveWorkoutSession(WorkoutSession(
        id: 'c1', date: DateTime.now(), duration: 10,
        exercises: [ExerciseLog(exerciseId: 'deadlift', sets: [WorkoutSet(weight: 120, reps: 5)])],
      ));
      await storage.saveWorkoutSession(WorkoutSession(
        id: 'c2', date: DateTime.now(), duration: 10,
        exercises: [ExerciseLog(exerciseId: 'squat', sets: [WorkoutSet(weight: 100, reps: 5)])],
      ));
      final result = await storage.getSessionsForExercise('deadlift');
      expect(result.map((s) => s.id), ['c1']);
    });

    test('saveWorkoutSession + getWorkoutSession round-trips bodyWeightAtLog', () async {
      final session = WorkoutSession(
        id: 's4',
        date: DateTime(2026, 7, 5),
        duration: 25,
        exercises: [
          ExerciseLog(
            exerciseId: 'assisted_pullup',
            sets: [WorkoutSet(weight: 20, reps: 8, bodyWeightAtLog: 75.5)],
          ),
        ],
      );
      await storage.saveWorkoutSession(session);
      final fetched = await storage.getWorkoutSession('s4');
      expect(fetched!.exercises.single.sets.single.bodyWeightAtLog, 75.5);
    });
  });

  group('SqliteStorageService — routines', () {
    test('saveRoutine + getRoutine round-trips ordered exercise ids', () async {
      await storage.saveRoutine(Routine(
        id: 'r1',
        name: 'Push Day',
        exerciseIds: ['bench_press', 'shoulder_press', 'triceps_pushdown'],
      ));
      final fetched = await storage.getRoutine('r1');
      expect(fetched!.name, 'Push Day');
      expect(fetched.exerciseIds, ['bench_press', 'shoulder_press', 'triceps_pushdown']);
    });

    test('saveRoutine overwrites exercise order on re-save', () async {
      await storage.saveRoutine(Routine(id: 'r2', name: 'Pull Day', exerciseIds: ['a', 'b']));
      await storage.saveRoutine(Routine(id: 'r2', name: 'Pull Day', exerciseIds: ['b', 'a', 'c']));
      final fetched = await storage.getRoutine('r2');
      expect(fetched!.exerciseIds, ['b', 'a', 'c']);
    });

    test('deleteRoutine removes it', () async {
      await storage.saveRoutine(Routine(id: 'r3', name: 'Legs', exerciseIds: ['squat']));
      await storage.deleteRoutine('r3');
      expect(await storage.getRoutine('r3'), isNull);
    });

    test('getAllRoutines returns all saved routines', () async {
      await storage.saveRoutine(Routine(id: 'r4', name: 'A', exerciseIds: []));
      await storage.saveRoutine(Routine(id: 'r5', name: 'B', exerciseIds: []));
      final all = await storage.getAllRoutines();
      expect(all.map((r) => r.id), containsAll(['r4', 'r5']));
    });
  });

  group('SqliteStorageService — targets', () {
    test('saveTarget + getTarget round-trips', () async {
      await storage.saveTarget(Target(
        id: 't1',
        exerciseId: 'bench_press',
        targetType: 'weight',
        targetValue: 100,
        currentValue: 70,
      ));
      final fetched = await storage.getTarget('t1');
      expect(fetched!.targetValue, 100);
      expect(fetched.currentValue, 70);
    });

    test('deleteTarget removes it', () async {
      await storage.saveTarget(Target(id: 't2', exerciseId: 'squat', targetType: 'weight', targetValue: 150));
      await storage.deleteTarget('t2');
      expect(await storage.getTarget('t2'), isNull);
    });

    test('getTargetsForExercise filters by exercise id', () async {
      await storage.saveTarget(Target(id: 't3', exerciseId: 'squat', targetType: 'weight', targetValue: 150));
      await storage.saveTarget(Target(id: 't4', exerciseId: 'deadlift', targetType: 'weight', targetValue: 180));
      final result = await storage.getTargetsForExercise('squat');
      expect(result.map((t) => t.id), ['t3']);
    });
  });

  group('SqliteStorageService — muscle groups', () {
    test('updateMuscleGroupGrowthRate updates an existing group', () async {
      final groups = await storage.getAllMuscleGroups();
      final chest = groups.firstWhere((g) => g.name == 'Chest');
      await storage.updateMuscleGroupGrowthRate(chest.id, 2.5);
      final updated = await storage.getMuscleGroup(chest.id);
      expect(updated!.growthRate, 2.5);
    });
  });

  group('SqliteStorageService — custom exercises', () {
    test('saveCustomExercise + getExercise round-trips muscle activations', () async {
      final exercise = Exercise(
        id: 'custom1',
        name: 'Cable Crossover',
        category: 'isolation',
        isCustom: true,
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'chest', activationPercentage: 80),
          MuscleActivation(muscleGroupId: 'triceps', activationPercentage: 20),
        ],
      );
      await storage.saveCustomExercise(exercise);

      final fetched = await storage.getExercise('custom1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Cable Crossover');
      expect(fetched.muscleActivations.length, 2);
      expect(fetched.primaryMuscle, 'chest');
    });

    test('getExercise falls back to built-in exercises', () async {
      final builtIns = ExerciseDatabase.getAll();
      final known = builtIns.first;
      final fetched = await storage.getExercise(known.id);
      expect(fetched!.name, known.name);
    });

    test('getAllExercises merges built-in and custom', () async {
      await storage.saveCustomExercise(Exercise(
        id: 'custom2',
        name: 'My Exercise',
        category: 'compound',
        isCustom: true,
        muscleActivations: [MuscleActivation(muscleGroupId: 'back', activationPercentage: 100)],
      ));
      final all = await storage.getAllExercises();
      expect(all.any((e) => e.id == 'custom2'), isTrue);
      expect(all.length, greaterThan(1));
    });

    test('deleteCustomExercise removes it and its activations', () async {
      await storage.saveCustomExercise(Exercise(
        id: 'custom3',
        name: 'Temp',
        category: 'isolation',
        isCustom: true,
        muscleActivations: [MuscleActivation(muscleGroupId: 'biceps', activationPercentage: 100)],
      ));
      await storage.deleteCustomExercise('custom3');
      expect(await storage.getExercise('custom3'), isNull);
      final custom = await storage.getCustomExercises();
      expect(custom.any((e) => e.id == 'custom3'), isFalse);
    });
  });
}
