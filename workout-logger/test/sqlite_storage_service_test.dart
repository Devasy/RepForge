import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/sqlite_storage_service.dart';

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
}
