import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/routine_manager.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  late MockStorageService mockStorage;
  late RoutineManager manager;

  setUp(() {
    mockStorage = MockStorageService();
    manager = RoutineManager(mockStorage);
  });

  group('RoutineManager - loadRoutines', () {
    test('populates routines from storage', () async {
      mockStorage.addMockRoutine(
        Routine(id: 'r1', name: 'Push', exerciseIds: ['ex1']),
      );
      mockStorage.addMockRoutine(
        Routine(id: 'r2', name: 'Pull', exerciseIds: ['ex2']),
      );

      await manager.loadRoutines();

      expect(manager.routines.length, 2);
      expect(manager.totalRoutines, 2);
      expect(manager.routines.map((r) => r.id), containsAll(['r1', 'r2']));
    });

    test('starts empty when storage has no routines', () async {
      await manager.loadRoutines();
      expect(manager.routines, isEmpty);
    });
  });

  group('RoutineManager - createRoutine', () {
    test('creates routine with unique id and persists it', () async {
      final routine = await manager.createRoutine(
        'Push Day',
        ['bench_press', 'overhead_press'],
      );

      expect(routine.name, 'Push Day');
      expect(routine.exerciseIds, ['bench_press', 'overhead_press']);
      expect(routine.id, isNotEmpty);
      expect(manager.routines.length, 1);
      expect(manager.routines.first, same(routine));
      expect(mockStorage.routines.any((r) => r.id == routine.id), isTrue);
    });

    test('creates multiple routines with distinct ids', () async {
      final r1 = await manager.createRoutine('Push', ['ex1']);
      final r2 = await manager.createRoutine('Pull', ['ex2']);

      expect(r1.id, isNot(equals(r2.id)));
      expect(manager.totalRoutines, 2);
    });
  });

  group('RoutineManager - getRoutine', () {
    test('returns routine by id', () async {
      final created = await manager.createRoutine('Legs', ['squat']);
      final found = manager.getRoutine(created.id);

      expect(found, isNotNull);
      expect(found!.name, 'Legs');
    });

    test('returns null for unknown id', () {
      expect(manager.getRoutine('nonexistent'), isNull);
    });
  });

  group('RoutineManager - updateRoutine', () {
    test('replaces existing routine in memory and storage', () async {
      final original = await manager.createRoutine('Push', ['ex1']);
      final updated = Routine(
        id: original.id,
        name: 'Push Day V2',
        exerciseIds: ['ex1', 'ex2'],
      );

      await manager.updateRoutine(updated);

      expect(manager.routines.length, 1);
      expect(manager.routines.first.name, 'Push Day V2');
      expect(manager.routines.first.exerciseIds, ['ex1', 'ex2']);
      final stored = mockStorage.routines.firstWhere((r) => r.id == original.id);
      expect(stored.name, 'Push Day V2');
    });

    test('adds routine if id not found in memory', () async {
      final orphan = Routine(id: 'orphan', name: 'New', exerciseIds: []);
      await manager.updateRoutine(orphan);

      expect(manager.routines.length, 1);
      expect(manager.routines.first.id, 'orphan');
    });
  });

  group('RoutineManager - deleteRoutine', () {
    test('removes routine from memory and storage', () async {
      final r = await manager.createRoutine('Push', ['ex1']);
      await manager.deleteRoutine(r.id);

      expect(manager.routines, isEmpty);
      expect(mockStorage.routines.any((x) => x.id == r.id), isFalse);
    });
  });

  group('RoutineManager - exercise membership queries', () {
    test('isExerciseUsedInRoutines returns true when exercise is in a routine',
        () async {
      await manager.createRoutine('Push', ['bench', 'ohp']);
      expect(manager.isExerciseUsedInRoutines('bench'), isTrue);
    });

    test('isExerciseUsedInRoutines returns false when not used', () async {
      await manager.createRoutine('Push', ['bench']);
      expect(manager.isExerciseUsedInRoutines('squat'), isFalse);
    });

    test('getRoutinesWithExercise returns matching routines', () async {
      await manager.createRoutine('Push', ['bench', 'ohp']);
      await manager.createRoutine('Full Body', ['bench', 'squat']);
      await manager.createRoutine('Legs', ['squat', 'rdl']);

      final result = manager.getRoutinesWithExercise('bench');
      expect(result.length, 2);
      expect(result.map((r) => r.name), containsAll(['Push', 'Full Body']));
    });

    test('getRoutinesWithExercise returns empty when none match', () async {
      await manager.createRoutine('Push', ['bench']);
      expect(manager.getRoutinesWithExercise('squat'), isEmpty);
    });
  });
}
