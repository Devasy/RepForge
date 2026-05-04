import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/analytics_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

WorkoutSession _session({
  required String id,
  required String exerciseId,
  double weight = 100,
  int reps = 10,
  int sets = 3,
  required DateTime date,
}) {
  return WorkoutSession(
    id: id,
    date: date,
    duration: 45,
    exercises: [
      ExerciseLog(
        exerciseId: exerciseId,
        sets: List.generate(sets, (_) => WorkoutSet(weight: weight, reps: reps)),
      ),
    ],
  );
}

Exercise _exercise({
  required String id,
  required String muscleGroupId,
  String category = 'compound',
}) {
  return Exercise(
    id: id,
    name: id,
    category: category,
    muscleActivations: [
      MuscleActivation(muscleGroupId: muscleGroupId, activationPercentage: 100),
    ],
  );
}

void main() {
  late MockStorageService mockStorage;
  late MockMLService mockML;
  late AnalyticsManager manager;

  setUp(() {
    mockStorage = MockStorageService();
    mockML = MockMLService();
    manager = AnalyticsManager(mockStorage, mockML);
  });

  group('AnalyticsManager - buildSessionIndex', () {
    test('indexes logs by exerciseId newest-first', () {
      final sessions = [
        _session(id: 's1', exerciseId: 'ex1', weight: 80, date: DateTime(2024, 1, 1)),
        _session(id: 's2', exerciseId: 'ex1', weight: 100, date: DateTime(2024, 1, 10)),
      ];

      manager.buildSessionIndex(sessions);

      // getVolumeProgression uses the index (oldest-first for progression)
      final progression = manager.getVolumeProgression('ex1', sessions);
      expect(progression.length, 2);
      expect(progression.first.date, DateTime(2024, 1, 1));
      expect(progression.last.date, DateTime(2024, 1, 10));
    });

    test('excludes logs with no sets from index', () {
      final emptyLog = WorkoutSession(
        id: 's_empty',
        date: DateTime(2024, 1, 5),
        duration: 10,
        exercises: [ExerciseLog(exerciseId: 'ex1', sets: [])],
      );
      final sessions = [
        _session(id: 's1', exerciseId: 'ex1', weight: 80, date: DateTime(2024, 1, 1)),
        emptyLog,
      ];

      manager.buildSessionIndex(sessions);
      final progression = manager.getVolumeProgression('ex1', sessions);

      expect(progression.length, 1);
    });
  });

  group('AnalyticsManager - updateGrowthModel', () {
    test('trains model when two or more data points exist', () async {
      final sessions = [
        _session(id: 's1', exerciseId: 'ex1', weight: 80, date: DateTime(2024, 1, 1)),
        _session(id: 's2', exerciseId: 'ex1', weight: 90, date: DateTime(2024, 1, 8)),
      ];

      await manager.updateGrowthModel('ex1', sessions);

      expect(manager.getGrowthModel('ex1'), isNotNull);
      expect(mockML.trainGrowthModelCallCount, 1);
      expect(mockML.extractDataPointsCallCount, 1);
    });

    test('removes stale model when fewer than two data points', () async {
      // Seed a model first
      final twoSessions = [
        _session(id: 's1', exerciseId: 'ex1', weight: 80, date: DateTime(2024, 1, 1)),
        _session(id: 's2', exerciseId: 'ex1', weight: 90, date: DateTime(2024, 1, 8)),
      ];
      await manager.updateGrowthModel('ex1', twoSessions);
      expect(manager.getGrowthModel('ex1'), isNotNull);

      // Now only one session — should clear the model
      final oneSession = [
        _session(id: 's1', exerciseId: 'ex1', weight: 80, date: DateTime(2024, 1, 1)),
      ];
      await manager.updateGrowthModel('ex1', oneSession);

      expect(manager.getGrowthModel('ex1'), isNull);
    });

    test('fires onGrowthModelUpdated callback', () async {
      String? updatedId;
      GrowthModel? updatedModel;
      final mgr = AnalyticsManager(
        mockStorage,
        mockML,
        onGrowthModelUpdated: (id, model) {
          updatedId = id;
          updatedModel = model;
        },
      );

      final sessions = [
        _session(id: 's1', exerciseId: 'ex1', weight: 80, date: DateTime(2024, 1, 1)),
        _session(id: 's2', exerciseId: 'ex1', weight: 90, date: DateTime(2024, 1, 8)),
      ];
      await mgr.updateGrowthModel('ex1', sessions);

      expect(updatedId, 'ex1');
      expect(updatedModel, isNotNull);
    });
  });

  group('AnalyticsManager - trainAllGrowthModels', () {
    test('trains a model for every exercise present in sessions', () async {
      final sessions = [
        _session(id: 's1', exerciseId: 'ex1', weight: 80, date: DateTime(2024, 1, 1)),
        _session(id: 's2', exerciseId: 'ex1', weight: 90, date: DateTime(2024, 1, 8)),
        WorkoutSession(
          id: 's3',
          date: DateTime(2024, 1, 5),
          duration: 30,
          exercises: [
            ExerciseLog(
              exerciseId: 'ex2',
              sets: [WorkoutSet(weight: 60, reps: 12)],
            ),
            ExerciseLog(
              exerciseId: 'ex2',
              sets: [WorkoutSet(weight: 65, reps: 10)],
            ),
          ],
        ),
        WorkoutSession(
          id: 's4',
          date: DateTime(2024, 1, 12),
          duration: 30,
          exercises: [
            ExerciseLog(
              exerciseId: 'ex2',
              sets: [WorkoutSet(weight: 70, reps: 8)],
            ),
          ],
        ),
      ];

      await manager.trainAllGrowthModels(sessions);

      // ex1 has 2 sessions → model trained
      expect(manager.getGrowthModel('ex1'), isNotNull);
      // ex2 has 2 sessions → model trained
      expect(manager.getGrowthModel('ex2'), isNotNull);
    });
  });

  group('AnalyticsManager - getRecommendations', () {
    test('returns mock recommendations for exercise with history', () {
      final sessions = [
        _session(id: 's1', exerciseId: 'ex1', weight: 80, date: DateTime(2024, 1, 1)),
      ];
      manager.buildSessionIndex(sessions);

      final recs = manager.getRecommendations('ex1', sessions);

      expect(recs, isNotEmpty);
      expect(mockML.recommendSetsCallCount, 1);
    });

    test('returns default recommendations when no history exists', () {
      final sessions = <WorkoutSession>[];
      manager.buildSessionIndex(sessions);

      final recs = manager.getRecommendations('ex1', sessions);

      expect(recs.length, 3);
      expect(recs.every((r) => r.confidence == 'low'), isTrue);
    });

    test('falls back to scan when index is stale', () {
      final sessions = [
        _session(id: 's1', exerciseId: 'ex1', weight: 80, date: DateTime(2024, 1, 1)),
      ];
      // Build index on a different list instance (stale)
      manager.buildSessionIndex([...sessions]);

      // Pass a new list — forces fallback scan
      final freshSessions = List<WorkoutSession>.from(sessions);
      final recs = manager.getRecommendations('ex1', freshSessions);

      expect(recs, isNotEmpty);
    });
  });

  group('AnalyticsManager - getVolumeProgression', () {
    test('returns progression oldest-first via index', () {
      final sessions = [
        _session(id: 's1', exerciseId: 'ex1', weight: 50, sets: 3, date: DateTime(2024, 1, 1)),
        _session(id: 's2', exerciseId: 'ex1', weight: 60, sets: 3, date: DateTime(2024, 1, 8)),
        _session(id: 's3', exerciseId: 'ex1', weight: 70, sets: 3, date: DateTime(2024, 1, 15)),
      ];
      manager.buildSessionIndex(sessions);

      final progression = manager.getVolumeProgression('ex1', sessions);

      expect(progression.length, 3);
      expect(progression[0].date, DateTime(2024, 1, 1));
      expect(progression[1].date, DateTime(2024, 1, 8));
      expect(progression[2].date, DateTime(2024, 1, 15));
    });

    test('volume values match session totals', () {
      final sessions = [
        _session(
          id: 's1',
          exerciseId: 'ex1',
          weight: 100,
          reps: 10,
          sets: 3,
          date: DateTime(2024, 1, 1),
        ),
      ];
      manager.buildSessionIndex(sessions);

      final progression = manager.getVolumeProgression('ex1', sessions);

      expect(progression.first.volume, 3000.0); // 100 * 10 * 3
    });

    test('returns empty list when exercise has no sessions', () {
      final sessions = [
        _session(id: 's1', exerciseId: 'ex2', weight: 80, date: DateTime(2024, 1, 1)),
      ];
      manager.buildSessionIndex(sessions);

      expect(manager.getVolumeProgression('ex1', sessions), isEmpty);
    });
  });

  group('AnalyticsManager - getWeeklyVolumeByMuscle', () {
    test('sums volume for sessions within last 7 days', () {
      final now = DateTime(2024, 2, 10);
      final sessions = [
        _session(
          id: 's1',
          exerciseId: 'ex1',
          weight: 100,
          reps: 10,
          sets: 1,
          date: DateTime(2024, 2, 8),
        ), // within 7 days
        _session(
          id: 's2',
          exerciseId: 'ex1',
          weight: 100,
          reps: 10,
          sets: 1,
          date: DateTime(2024, 2, 1),
        ), // older than 7 days
      ];
      final exercises = [_exercise(id: 'ex1', muscleGroupId: 'chest')];

      final result = manager.getWeeklyVolumeByMuscle(
        sessions,
        exercises,
        now: now,
      );

      expect(result['chest'], 1000.0); // only s1: 100*10*1=1000
    });

    test('distributes volume by muscle activation percentage', () {
      final now = DateTime(2024, 2, 10);
      final session = WorkoutSession(
        id: 's1',
        date: DateTime(2024, 2, 9),
        duration: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench',
            sets: [WorkoutSet(weight: 100, reps: 10)],
          ),
        ],
      );
      final exercise = Exercise(
        id: 'bench',
        name: 'Bench Press',
        category: 'compound',
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'chest', activationPercentage: 70),
          MuscleActivation(muscleGroupId: 'triceps', activationPercentage: 30),
        ],
      );

      final result = manager.getWeeklyVolumeByMuscle(
        [session],
        [exercise],
        now: now,
      );

      expect(result['chest'], closeTo(700.0, 0.01));
      expect(result['triceps'], closeTo(300.0, 0.01));
    });

    test('returns empty map when no sessions in window', () {
      final now = DateTime(2024, 2, 10);
      final sessions = [
        _session(
          id: 's1',
          exerciseId: 'ex1',
          weight: 100,
          reps: 10,
          sets: 1,
          date: DateTime(2024, 1, 1),
        ),
      ];
      final exercises = [_exercise(id: 'ex1', muscleGroupId: 'chest')];

      final result = manager.getWeeklyVolumeByMuscle(
        sessions,
        exercises,
        now: now,
      );

      expect(result, isEmpty);
    });

    test('uses provided exerciseMap for O(1) lookup', () {
      final now = DateTime(2024, 2, 10);
      final sessions = [
        _session(
          id: 's1',
          exerciseId: 'ex1',
          weight: 50,
          reps: 5,
          sets: 2,
          date: DateTime(2024, 2, 9),
        ),
      ];
      final exercises = [_exercise(id: 'ex1', muscleGroupId: 'back')];
      final exerciseMap = {for (final e in exercises) e.id: e};

      final result = manager.getWeeklyVolumeByMuscle(
        sessions,
        exercises,
        now: now,
        exerciseMap: exerciseMap,
      );

      expect(result['back'], 500.0); // 50*5*2=500
    });
  });

  group('AnalyticsManager - getQuickStats', () {
    test('returns stats map from storage', () async {
      mockStorage.addMockSession(
        _session(id: 's1', exerciseId: 'ex1', date: DateTime(2024, 1, 15)),
      );

      final stats = await manager.getQuickStats();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats['totalWorkouts'], 1);
    });
  });
}
