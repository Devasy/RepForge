// Tests for AgentDataService — the read façade exposed to the OS AI agent.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/agent_data_service.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';

import 'test_utils/mock_storage_service.dart';

void main() {
  late MockStorageService storage;
  late WorkoutProvider provider;
  late AgentDataService agent;

  // Stable test exercises (custom, with distinctive names so resolution does
  // not collide with the built-in exercise database).
  final benchEx = Exercise(
    id: 'ex_bench',
    name: 'Zforge Bench Lift',
    category: 'compound',
    isCustom: true,
    muscleActivations: [
      MuscleActivation(muscleGroupId: 'chest', activationPercentage: 70),
      MuscleActivation(muscleGroupId: 'triceps', activationPercentage: 30),
    ],
  );
  final squatEx = Exercise(
    id: 'ex_squat',
    name: 'Zforge Squat Lift',
    category: 'compound',
    isCustom: true,
    muscleActivations: [
      MuscleActivation(muscleGroupId: 'quads', activationPercentage: 80),
      MuscleActivation(muscleGroupId: 'glutes', activationPercentage: 20),
    ],
  );
  final curlEx = Exercise(
    id: 'ex_curl',
    name: 'Zforge Arm Curl',
    category: 'isolation',
    isCustom: true,
    muscleActivations: [
      MuscleActivation(muscleGroupId: 'biceps', activationPercentage: 100),
    ],
  );

  WorkoutSet wset(double weight, int reps) =>
      WorkoutSet(weight: weight, reps: reps);

  WorkoutSession session(
    String id,
    DateTime date,
    List<ExerciseLog> exercises,
  ) =>
      WorkoutSession(id: id, date: date, exercises: exercises, duration: 60);

  final now = DateTime.now();

  setUp(() async {
    storage = MockStorageService();
    storage.addMockCustomExercise(benchEx);
    storage.addMockCustomExercise(squatEx);
    storage.addMockCustomExercise(curlEx);

    // Newest → oldest.
    storage.addMockSession(session('s1', now, [
      ExerciseLog(exerciseId: 'ex_bench', sets: [wset(60, 10), wset(60, 8)]),
    ]));
    storage.addMockSession(
      session('s2', now.subtract(const Duration(days: 3)), [
        ExerciseLog(exerciseId: 'ex_bench', sets: [wset(55, 10)]),
      ]),
    );
    storage.addMockSession(
      session('s3', now.subtract(const Duration(days: 10)), [
        ExerciseLog(exerciseId: 'ex_bench', sets: [wset(50, 10)]),
        ExerciseLog(exerciseId: 'ex_squat', sets: [wset(100, 5)]),
      ]),
    );
    storage.addMockSession(
      session('s4', now.subtract(const Duration(days: 20)), [
        ExerciseLog(exerciseId: 'ex_squat', sets: [wset(90, 5)]),
      ]),
    );

    provider = WorkoutProvider(
      storage,
      programManager: ProgramManager(storage),
    );
    await provider.init();
    agent = AgentDataService(provider);
  });

  group('name resolution', () {
    test('resolves an exercise by partial, case-insensitive name', () {
      expect(agent.resolveExercise('zforge bench')?.id, 'ex_bench');
      expect(agent.resolveExercise('ZFORGE SQUAT')?.id, 'ex_squat');
      expect(agent.resolveExercise('ex_curl')?.id, 'ex_curl');
    });

    test('returns null for an unknown exercise', () {
      expect(agent.resolveExercise('flux capacitor raise'), isNull);
    });

    test('resolves a muscle group by name or id', () {
      expect(agent.resolveMuscleGroup('Chest'), 'chest');
      expect(agent.resolveMuscleGroup('quads'), 'quads');
      expect(agent.resolveMuscleGroup('not-a-muscle'), isNull);
    });
  });

  group('getExerciseHistory', () {
    test('returns matching sessions newest-first', () {
      final result = agent.getExerciseHistory('zforge bench');
      expect(result['exerciseId'], 'ex_bench');
      expect(result['sessionCount'], 3);
      final sessions = result['sessions'] as List;
      expect(sessions.first['id'], 's1');
      expect(sessions.last['id'], 's3');
    });

    test('respects the limit', () {
      final result = agent.getExerciseHistory('zforge bench', limit: 2);
      expect((result['sessions'] as List).length, 2);
    });

    test('reports an error for an unknown exercise', () {
      expect(agent.getExerciseHistory('nonexistent'), contains('error'));
    });
  });

  group('getMuscleGroupSessions', () {
    test('returns sessions that train the muscle', () {
      final chest = agent.getMuscleGroupSessions('chest');
      expect(chest['sessionCount'], 3);

      final quads = agent.getMuscleGroupSessions('quads');
      expect(quads['sessionCount'], 2);
    });

    test('reports an error for an unknown muscle', () {
      expect(agent.getMuscleGroupSessions('elbow'), contains('error'));
    });
  });

  group('getMuscleRecovery', () {
    test('returns a recovery entry for every trained muscle', () {
      final all = agent.getMuscleRecovery();
      final muscles = all['muscles'] as List;
      final ids = muscles.map((m) => m['muscleGroupId']).toSet();
      expect(ids, containsAll(<String>['chest', 'triceps', 'quads']));
    });

    test('scopes to a single muscle when asked', () {
      final chest = agent.getMuscleRecovery(muscleQuery: 'chest');
      expect(chest['muscleGroupId'], 'chest');
      expect(chest['recoveryPercent'], isA<int>());
    });
  });

  group('getSessionsThisWeek', () {
    test('includes a session logged today', () {
      final result = agent.getSessionsThisWeek();
      final ids =
          (result['sessions'] as List).map((s) => s['id']).toList();
      expect(ids, contains('s1'));
      expect(result['sessionCount'], greaterThanOrEqualTo(1));
    });
  });

  group('getMuscleGroupProgress', () {
    test('returns an oldest-first volume series with a trend', () {
      final result = agent.getMuscleGroupProgress('chest');
      expect(result['dataPointCount'], 3);
      final points = result['volumeBySession'] as List;
      final dates =
          points.map((p) => DateTime.parse(p['date'] as String)).toList();
      expect(dates.first.isBefore(dates.last), isTrue);
      expect(result['trend'], isNotNull);
      expect(result['trend']['direction'], 'increasing');
    });
  });

  group('listExercises', () {
    test('lists all exercises including the custom ones', () {
      final result = agent.listExercises();
      expect(result['count'], greaterThanOrEqualTo(3));
    });

    test('filters by muscle group', () {
      final result = agent.listExercises(muscleQuery: 'biceps');
      final names =
          (result['exercises'] as List).map((e) => e['name']).toList();
      expect(names, contains('Zforge Arm Curl'));
    });

    test('filters by category', () {
      final result = agent.listExercises(category: 'isolation');
      final ids =
          (result['exercises'] as List).map((e) => e['id']).toList();
      expect(ids, contains('ex_curl'));
      expect(ids, isNot(contains('ex_bench')));
    });
  });

  group('querySessions', () {
    test('filters by exercise', () {
      final result = agent.querySessions(exerciseQuery: 'zforge squat');
      expect(result['sessionCount'], 2);
    });

    test('filters by date range', () {
      final result = agent.querySessions(
        dateFrom: now.subtract(const Duration(days: 5)),
      );
      final ids =
          (result['sessions'] as List).map((s) => s['id']).toSet();
      expect(ids, <String>{'s1', 's2'});
    });

    test('filters by minimum volume and limit', () {
      final result = agent.querySessions(minVolume: 100000, limit: 5);
      expect(result['sessionCount'], 0);
    });

    test('combines muscle and date filters', () {
      final result = agent.querySessions(
        muscleQuery: 'quads',
        dateFrom: now.subtract(const Duration(days: 14)),
      );
      final ids =
          (result['sessions'] as List).map((s) => s['id']).toSet();
      expect(ids, <String>{'s3'});
    });
  });

  group('buildSnapshot', () {
    test('produces a JSON-encodable snapshot with the expected shape', () {
      final snapshot = agent.buildSnapshot();
      // Must round-trip through JSON without throwing.
      final encoded = jsonEncode(snapshot);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['schemaVersion'], 1);
      expect(decoded['exercises'], isA<List>());
      expect((decoded['sessions'] as List).length, 4);
      expect(decoded['recovery'], isA<List>());
      expect(decoded['muscleGroups'], isA<List>());

      // Sessions in the snapshot carry per-set detail.
      final firstSession = (decoded['sessions'] as List).first
          as Map<String, dynamic>;
      final firstLog =
          (firstSession['exercises'] as List).first as Map<String, dynamic>;
      expect(firstLog['sets'], isA<List>());
    });

    test('recovery entries expose the decay inputs', () {
      final snapshot = agent.buildSnapshot();
      final recovery = snapshot['recovery'] as List;
      expect(recovery, isNotEmpty);
      final entry = recovery.first as Map<String, dynamic>;
      expect(entry['lastTrainedAt'], isA<String>());
      expect(entry['tauHours'], isA<num>());
    });
  });
}
