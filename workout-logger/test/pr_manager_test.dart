import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'test_utils/mock_storage_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

WorkoutSession _session({
  String id = 's1',
  DateTime? date,
  List<ExerciseLog> exercises = const [],
}) => WorkoutSession(
      id: id,
      date: date ?? DateTime(2026, 1, 1),
      exercises: exercises,
      duration: 30,
    );

ExerciseLog _log(String exerciseId, {List<WorkoutSet> sets = const []}) =>
    ExerciseLog(exerciseId: exerciseId, sets: sets);

WorkoutSet _set({double weight = 60.0, int reps = 10}) =>
    WorkoutSet(weight: weight, reps: reps);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockStorageService storage;
  late PRManager manager;

  setUp(() {
    storage = MockStorageService();
    manager = PRManager(storage);
  });

  group('PRManager - load', () {
    test('starts empty when storage has no records', () async {
      await manager.load();
      expect(manager.allRecords, isEmpty);
    });

    test('populates allRecords from storage on load', () async {
      await storage.savePersonalRecord(PersonalRecord(
        exerciseId: 'bench',
        bestWeight: 100.0,
        bestReps: 5,
        bestVolume: 500.0,
        achievedAt: DateTime(2026, 1, 1),
      ));
      await manager.load();
      expect(manager.allRecords, hasLength(1));
      expect(manager.allRecords.first.exerciseId, 'bench');
      expect(manager.allRecords.first.bestWeight, 100.0);
    });
  });

  group('PRManager - backfillFromSessions', () {
    test('creates record for exercise with no prior PR', () async {
      await manager.backfillFromSessions([
        _session(exercises: [_log('bench', sets: [_set(weight: 80, reps: 5)])]),
      ]);
      final rec = manager.getRecord('bench');
      expect(rec, isNotNull);
      expect(rec!.bestWeight, 80.0);
      expect(rec.bestReps, 5);
    });

    test('updates record when later session contains new best weight', () async {
      await manager.backfillFromSessions([
        _session(
          id: 's1',
          date: DateTime(2026, 1, 1),
          exercises: [_log('bench', sets: [_set(weight: 80, reps: 5)])],
        ),
        _session(
          id: 's2',
          date: DateTime(2026, 1, 8),
          exercises: [_log('bench', sets: [_set(weight: 100, reps: 5)])],
        ),
      ]);
      expect(manager.getRecord('bench')!.bestWeight, 100.0);
    });

    test('updates record when later session contains new best reps', () async {
      await manager.backfillFromSessions([
        _session(
          id: 's1',
          date: DateTime(2026, 1, 1),
          exercises: [_log('bench', sets: [_set(weight: 60, reps: 8)])],
        ),
        _session(
          id: 's2',
          date: DateTime(2026, 1, 8),
          exercises: [_log('bench', sets: [_set(weight: 60, reps: 12)])],
        ),
      ]);
      expect(manager.getRecord('bench')!.bestReps, 12);
    });

    test('updates record when later session contains new best volume', () async {
      await manager.backfillFromSessions([
        _session(
          id: 's1',
          date: DateTime(2026, 1, 1),
          exercises: [_log('bench', sets: [_set(weight: 60, reps: 10)])], // 600
        ),
        _session(
          id: 's2',
          date: DateTime(2026, 1, 8),
          exercises: [_log('bench', sets: [_set(weight: 70, reps: 10)])], // 700
        ),
      ]);
      expect(manager.getRecord('bench')!.bestVolume, 700.0);
    });

    test('does not lower a PR when a weaker session is processed later', () async {
      await manager.backfillFromSessions([
        _session(
          id: 's1',
          date: DateTime(2026, 1, 1),
          exercises: [_log('bench', sets: [_set(weight: 100, reps: 10)])],
        ),
        _session(
          id: 's2',
          date: DateTime(2026, 1, 8),
          exercises: [_log('bench', sets: [_set(weight: 60, reps: 5)])],
        ),
      ]);
      expect(manager.getRecord('bench')!.bestWeight, 100.0);
    });

    test('handles multiple exercises in one session', () async {
      await manager.backfillFromSessions([
        _session(exercises: [
          _log('bench', sets: [_set(weight: 80, reps: 8)]),
          _log('squat', sets: [_set(weight: 120, reps: 5)]),
        ]),
      ]);
      expect(manager.getRecord('bench'), isNotNull);
      expect(manager.getRecord('squat'), isNotNull);
    });
  });

  group('PRManager - checkAndUpdatePRs', () {
    test('first session for exercise always creates a PR with all three types',
        () async {
      final results = await manager.checkAndUpdatePRs(
        _session(exercises: [_log('bench', sets: [_set(weight: 60, reps: 10)])]),
      );
      expect(results, hasLength(1));
      expect(results.first.exerciseId, 'bench');
      expect(results.first.types, containsAll(['weight', 'reps', 'volume']));
    });

    test('returns empty list when no PR is broken', () async {
      await manager.checkAndUpdatePRs(
        _session(exercises: [_log('bench', sets: [_set(weight: 100, reps: 10)])]),
      );
      final results = await manager.checkAndUpdatePRs(
        _session(
          id: 's2',
          exercises: [_log('bench', sets: [_set(weight: 60, reps: 5)])],
        ),
      );
      expect(results, isEmpty);
    });

    test('returns NewPRResult when weight PR is broken', () async {
      await manager.checkAndUpdatePRs(
        _session(exercises: [_log('bench', sets: [_set(weight: 80, reps: 5)])]),
      );
      final results = await manager.checkAndUpdatePRs(
        _session(
          id: 's2',
          exercises: [_log('bench', sets: [_set(weight: 100, reps: 5)])],
        ),
      );
      expect(results, hasLength(1));
      expect(results.first.types, contains('weight'));
    });

    test('returns NewPRResult when reps PR is broken', () async {
      await manager.checkAndUpdatePRs(
        _session(exercises: [_log('bench', sets: [_set(weight: 60, reps: 8)])]),
      );
      final results = await manager.checkAndUpdatePRs(
        _session(
          id: 's2',
          exercises: [_log('bench', sets: [_set(weight: 60, reps: 12)])],
        ),
      );
      expect(results.first.types, contains('reps'));
    });

    test('returns NewPRResult when both weight and reps are broken simultaneously',
        () async {
      await manager.checkAndUpdatePRs(
        _session(exercises: [_log('bench', sets: [_set(weight: 60, reps: 8)])]),
      );
      final results = await manager.checkAndUpdatePRs(
        _session(
          id: 's2',
          exercises: [_log('bench', sets: [_set(weight: 80, reps: 10)])],
        ),
      );
      expect(results.first.types, containsAll(['weight', 'reps']));
    });

    test('persists updated record to storage', () async {
      await manager.checkAndUpdatePRs(
        _session(exercises: [_log('bench', sets: [_set(weight: 100, reps: 5)])]),
      );
      final stored = await storage.getPersonalRecord('bench');
      expect(stored, isNotNull);
      expect(stored!.bestWeight, 100.0);
    });

    test('skips exercise log with no sets', () async {
      final results = await manager.checkAndUpdatePRs(
        _session(exercises: [_log('bench', sets: [])]),
      );
      expect(results, isEmpty);
      expect(manager.getRecord('bench'), isNull);
    });
  });

  group('PRManager - getRecord', () {
    test('returns record for known exercise', () async {
      await manager.checkAndUpdatePRs(
        _session(exercises: [_log('bench', sets: [_set(weight: 80, reps: 8)])]),
      );
      expect(manager.getRecord('bench'), isNotNull);
    });

    test('returns null for unknown exercise', () {
      expect(manager.getRecord('unknown_exercise'), isNull);
    });
  });
}
