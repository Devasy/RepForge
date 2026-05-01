import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/target_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

WorkoutSession _session(
  String id,
  String exerciseId, {
  double weight = 100,
  int reps = 10,
  int sets = 3,
  DateTime? date,
}) {
  return WorkoutSession(
    id: id,
    date: date ?? DateTime(2024, 1, 1),
    duration: 30,
    exercises: [
      ExerciseLog(
        exerciseId: exerciseId,
        sets: List.generate(
          sets,
          (_) => WorkoutSet(weight: weight, reps: reps),
        ),
      ),
    ],
  );
}

void main() {
  late MockStorageService mockStorage;
  late MockMLService mockML;
  late TargetManager manager;

  setUp(() {
    mockStorage = MockStorageService();
    mockML = MockMLService();
    manager = TargetManager(mockStorage, mockML);
  });

  group('TargetManager - loadTargets', () {
    test('populates targets from storage', () async {
      mockStorage.addMockTarget(
        Target(
          id: 't1',
          exerciseId: 'ex1',
          targetType: 'weight',
          targetValue: 100,
          currentValue: 80,
        ),
      );

      await manager.loadTargets();

      expect(manager.targets.length, 1);
      expect(manager.totalTargets, 1);
      expect(manager.targets.first.id, 't1');
    });
  });

  group('TargetManager - growth models', () {
    test('updateGrowthModel stores and getGrowthModel retrieves it', () {
      final model = GrowthModel(
        slope: 2.5,
        intercept: 50,
        r2: 0.9,
        lastTrained: DateTime(2024),
      );

      manager.updateGrowthModel('ex1', model);

      expect(manager.getGrowthModel('ex1'), same(model));
    });

    test('getGrowthModel returns null for unknown exercise', () {
      expect(manager.getGrowthModel('unknown'), isNull);
    });
  });

  group('TargetManager - createTarget', () {
    final sessions = [_session('s1', 'ex1', weight: 80, reps: 10, sets: 3)];

    test('creates weight target with correct current value', () async {
      final target = await manager.createTarget(
        exerciseId: 'ex1',
        type: 'weight',
        targetValue: 120,
        sessions: sessions,
      );

      expect(target.exerciseId, 'ex1');
      expect(target.targetType, 'weight');
      expect(target.targetValue, 120);
      expect(target.currentValue, 80); // max weight logged
      expect(target.isCompleted, isFalse);
      expect(target.id, isNotEmpty);
    });

    test('creates reps target with correct current value', () async {
      final target = await manager.createTarget(
        exerciseId: 'ex1',
        type: 'reps',
        targetValue: 15,
        sessions: sessions,
      );

      expect(target.currentValue, 10); // max reps logged
      expect(target.isCompleted, isFalse);
    });

    test('creates volume target with correct current value', () async {
      // volume = weight * reps per set; best session log volume = 80*10*3 = 2400
      final target = await manager.createTarget(
        exerciseId: 'ex1',
        type: 'volume',
        targetValue: 5000,
        sessions: sessions,
      );

      expect(target.currentValue, 2400);
      expect(target.isCompleted, isFalse);
    });

    test('marks target as completed when current value meets target', () async {
      final target = await manager.createTarget(
        exerciseId: 'ex1',
        type: 'weight',
        targetValue: 70, // already exceeded by 80kg
        sessions: sessions,
      );

      expect(target.isCompleted, isTrue);
    });

    test('uses growth model for estimated completion date', () async {
      final model = GrowthModel(
        slope: 2,
        intercept: 60,
        r2: 0.85,
        lastTrained: DateTime(2024),
      );
      manager.updateGrowthModel('ex1', model);
      mockML.mockPrediction = DateTime(2024, 6, 1);

      final target = await manager.createTarget(
        exerciseId: 'ex1',
        type: 'weight',
        targetValue: 120,
        sessions: sessions,
      );

      expect(target.estimatedCompletionDate, DateTime(2024, 6, 1));
      expect(mockML.predictTargetCompletionCallCount, 1);
    });

    test('persists target to storage', () async {
      final target = await manager.createTarget(
        exerciseId: 'ex1',
        type: 'weight',
        targetValue: 100,
        sessions: sessions,
      );

      expect(mockStorage.targets.any((t) => t.id == target.id), isTrue);
    });

    test('target appears in manager.targets after creation', () async {
      await manager.createTarget(
        exerciseId: 'ex1',
        type: 'reps',
        targetValue: 20,
        sessions: sessions,
      );

      expect(manager.targets.length, 1);
    });

    test('throws ArgumentError for unsupported type', () async {
      await expectLater(
        manager.createTarget(
          exerciseId: 'ex1',
          type: 'duration',
          targetValue: 60,
          sessions: sessions,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TargetManager - activeTargets / completedTargets', () {
    test('separates active and completed targets correctly', () async {
      final sessions = [_session('s1', 'ex1', weight: 80, reps: 10)];
      await manager.createTarget(
        exerciseId: 'ex1',
        type: 'weight',
        targetValue: 120, // not yet completed
        sessions: sessions,
      );
      await manager.createTarget(
        exerciseId: 'ex1',
        type: 'weight',
        targetValue: 50, // already completed
        sessions: sessions,
      );

      expect(manager.activeTargets.length, 1);
      expect(manager.completedTargets.length, 1);
    });
  });

  group('TargetManager - recalculateTargets', () {
    test('updates currentValue and isCompleted based on new sessions', () async {
      final initialSessions = [
        _session('s1', 'ex1', weight: 80, reps: 10),
      ];
      await manager.createTarget(
        exerciseId: 'ex1',
        type: 'weight',
        targetValue: 100,
        sessions: initialSessions,
      );

      expect(manager.targets.first.currentValue, 80);
      expect(manager.targets.first.isCompleted, isFalse);

      // Simulate a stronger session
      final newSessions = [
        _session('s1', 'ex1', weight: 80, reps: 10),
        _session('s2', 'ex1', weight: 105, reps: 5),
      ];

      await manager.recalculateTargets({'ex1'}, newSessions);

      expect(manager.targets.first.currentValue, 105);
      expect(manager.targets.first.isCompleted, isTrue);
    });
  });

  group('TargetManager - deleteTarget', () {
    test('removes target from memory and storage', () async {
      final sessions = [_session('s1', 'ex1', weight: 80, reps: 10)];
      final target = await manager.createTarget(
        exerciseId: 'ex1',
        type: 'reps',
        targetValue: 15,
        sessions: sessions,
      );

      await manager.deleteTarget(target.id);

      expect(manager.targets, isEmpty);
      expect(mockStorage.targets.any((t) => t.id == target.id), isFalse);
    });
  });

  group('TargetManager - isExerciseUsedInTargets', () {
    test('returns true when exercise has a target', () async {
      final sessions = [_session('s1', 'ex1', weight: 80, reps: 10)];
      await manager.createTarget(
        exerciseId: 'ex1',
        type: 'weight',
        targetValue: 100,
        sessions: sessions,
      );

      expect(manager.isExerciseUsedInTargets('ex1'), isTrue);
    });

    test('returns false when exercise has no target', () {
      expect(manager.isExerciseUsedInTargets('ex_unused'), isFalse);
    });
  });

  group('TargetManager - getTargetsForExercise', () {
    test('returns all targets for a specific exercise', () async {
      final sessions = [_session('s1', 'ex1', weight: 80, reps: 10)];
      await manager.createTarget(
        exerciseId: 'ex1',
        type: 'weight',
        targetValue: 100,
        sessions: sessions,
      );
      await manager.createTarget(
        exerciseId: 'ex1',
        type: 'reps',
        targetValue: 15,
        sessions: sessions,
      );
      await manager.createTarget(
        exerciseId: 'ex2',
        type: 'weight',
        targetValue: 60,
        sessions: [_session('s2', 'ex2', weight: 50, reps: 8)],
      );

      final ex1Targets = manager.getTargetsForExercise('ex1');
      expect(ex1Targets.length, 2);
      expect(ex1Targets.every((t) => t.exerciseId == 'ex1'), isTrue);
    });
  });
}
