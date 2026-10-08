import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/ml_service.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import 'test_utils/mock_storage_service.dart';

WorkoutSet bodySet(WorkoutLoadMode mode, {double weight = 20, int reps = 12}) =>
    WorkoutSet(
      weight: weight,
      reps: reps,
      loadMode: mode,
      bodyWeightAtLog: 70,
      assistWeight: mode == WorkoutLoadMode.assisted ? weight : null,
    );
WorkoutSession session(
  String id,
  int day,
  WorkoutSet set, {
  String exercise = 'pull_ups',
  String? handle,
}) => WorkoutSession(
  id: id,
  date: DateTime(2026, 10, day),
  duration: 30,
  exercises: [
    ExerciseLog(exerciseId: exercise, handle: handle, sets: [set]),
  ],
);

void main() {
  test(
    'explicit assisted mode with a snapshot defaults to modern encoding',
    () {
      final set = WorkoutSet(
        weight: 10,
        reps: 5,
        loadMode: WorkoutLoadMode.assisted,
        bodyWeightAtLog: 70,
      );
      expect(set.loadEncodingVersion, 1);
      expect(set.effectiveWeight, 60);
      expect(
        WorkoutSet(
          weight: 10,
          reps: 5,
          loadMode: WorkoutLoadMode.external,
          assistWeight: 10,
          bodyWeightAtLog: 70,
        ).loadEncodingVersion,
        0,
      );
    },
  );
  test('missing version-1 bodyweight returns safe default recommendations', () {
    for (final mode in [WorkoutLoadMode.assisted, WorkoutLoadMode.weighted]) {
      final recommendations = MLService().recommendSets(
        lastSession: [
          WorkoutSet(
            weight: 10,
            reps: 12,
            loadMode: mode,
            loadEncodingVersion: 1,
          ),
        ],
      );
      expect(recommendations.single.weight, 0);
      expect(recommendations.single.confidence, 'low');
    }
  });
  test(
    'progress charts normalize drop loads and clear bodyweight-only fields',
    () async {
      final raw = bodySet(WorkoutLoadMode.assisted, weight: 10, reps: 5)
          .copyWith(
            extraWeight: 5.0,
            isDropset: true,
            drops: [DropsetEntry(id: 'd', weight: 5, reps: 4)],
          );
      final storage = MockStorageService();
      await storage.saveWorkoutSession(session('drops', 8, raw));
      final provider = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await provider.init();
      final normalized = provider
          .getSetProgression('pull_ups')
          .single
          .sets
          .single;
      expect(normalized.weight, 65);
      expect(normalized.drops!.single.weight, 70);
      expect(normalized.assistWeight, isNull);
      expect(normalized.extraWeight, isNull);
      expect(normalized.bodyWeightAtLog, isNull);
      expect(normalized.volume, raw.volume);
      expect(
        (await storage.getWorkoutSession(
          'drops',
        ))!.exercises.single.sets.single.drops!.single.weight,
        5,
      );
    },
  );
  test('push-ups use added load and assistance decreases effective load', () {
    expect(isAssistedBodyweightExercise('push_ups'), isFalse);
    expect(isBodyweightExercise('push_ups'), isTrue);
    final weighted = bodySet(WorkoutLoadMode.weighted, weight: 10, reps: 5);
    final assisted = bodySet(WorkoutLoadMode.assisted, weight: 10, reps: 5);
    expect(weighted.effectiveWeight, 80);
    expect(weighted.volume, 400);
    expect(assisted.effectiveWeight, 60);
    expect(assisted.volume, 300);
    expect(WorkoutSet.fromJson(weighted.toJson()).toJson(), weighted.toJson());
  });
  test('drops follow the explicit load direction and frozen bodyweight', () {
    final weighted = bodySet(WorkoutLoadMode.weighted, weight: 10, reps: 5)
        .copyWith(
          isDropset: true,
          drops: [DropsetEntry(id: 'd', weight: 5, reps: 4)],
        );
    expect(weighted.volume, 700);
    expect(weighted.calculateVolume(userBodyWeight: 100), 700);
    final assisted = bodySet(WorkoutLoadMode.assisted, weight: 10, reps: 5)
        .copyWith(
          isDropset: true,
          drops: [DropsetEntry(id: 'd', weight: 5, reps: 4)],
        );
    expect(assisted.volume, 560);
  });
  test('legacy raw sets keep their values without fabricated BW snapshots', () {
    final old = WorkoutSet.fromJson({
      'weight': 20,
      'reps': 10,
      'timestamp': '2026-01-01',
    });
    expect(old.volume, 200);
    expect(old.bodyWeightAtLog, isNull);
    expect(old.loadEncodingVersion, 0);
    expect(old.hasComparableLoad(bodySet(WorkoutLoadMode.assisted)), isFalse);
  });
  test(
    'assisted progression reduces assistance; weighted progression adds load',
    () {
      final ml = MLService();
      expect(
        ml
            .recommendSets(lastSession: [bodySet(WorkoutLoadMode.assisted)])
            .first
            .weight,
        15,
      );
      expect(
        ml
            .recommendSets(lastSession: [bodySet(WorkoutLoadMode.weighted)])
            .first
            .weight,
        25,
      );
    },
  );
  test('mixed encodings cannot trigger false deload recovery', () {
    final ml = MLService();
    final current = [bodySet(WorkoutLoadMode.weighted, weight: 10, reps: 8)];
    final legacy = [WorkoutSet(weight: 300, reps: 10)];
    final control = ml.recommendSets(
      lastSession: current,
      asOf: DateTime(2026, 10, 8),
    );
    final mixed = ml.recommendSets(
      lastSession: current,
      pastSessions: [current, legacy],
      asOf: DateTime(2026, 10, 8),
    );
    expect(mixed.first.weight, control.first.weight);
    expect(mixed.first.reasoning, control.first.reasoning);
  });
  test(
    'growth and exercise charts use one encoding and preserve old history',
    () async {
      final old = session('old', 1, WorkoutSet(weight: 20, reps: 10));
      final modern = session(
        'new',
        8,
        bodySet(WorkoutLoadMode.assisted, weight: 10, reps: 10),
      );
      final storage = MockStorageService();
      await storage.saveWorkoutSession(old);
      await storage.saveWorkoutSession(modern);
      final provider = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await provider.init();
      expect(provider.getVolumeProgression('pull_ups').map((r) => r.volume), [
        600,
      ]);
      expect(provider.getSetProgression('pull_ups'), hasLength(1));
      expect(provider.hasMixedLoadConventions('pull_ups'), isTrue);
      expect(provider.getBestOneRM('pull_ups'), closeTo(80, 0.001));
      expect(
        provider.getSetProgression('pull_ups').single.sets.single.weight,
        60,
      );
      expect(
        MLService().extractExerciseDataPoints('pull_ups', [old, modern]),
        hasLength(1),
      );
      expect(
        (await storage.getWorkoutSession(
          'old',
        ))!.exercises.single.sets.single.volume,
        200,
      );
    },
  );
  test(
    'PRs keep canonical IDs, distinct handles and exercise-wide best lookup',
    () async {
      final storage = MockStorageService();
      final prs = PRManager(storage);
      await prs.checkAndUpdatePRs(
        session(
          'rope',
          1,
          WorkoutSet(weight: 50, reps: 8),
          exercise: 'cable_curl',
          handle: 'Rope',
        ),
      );
      await prs.checkAndUpdatePRs(
        session(
          'bar',
          2,
          WorkoutSet(weight: 60, reps: 6),
          exercise: 'cable_curl',
          handle: 'Bar',
        ),
      );
      expect(prs.allRecords.map((r) => r.exerciseId).toSet(), {'cable_curl'});
      expect(prs.getRecord('cable_curl', handle: 'Rope')!.bestWeight, 50);
      expect(prs.getRecord('cable_curl', handle: 'Bar')!.bestWeight, 60);
      expect(prs.getRecord('cable_curl')!.bestWeight, 60);
      expect(prs.getRecord('cable_curl', handle: 'Unknown'), isNull);
      final restored = PRManager(storage);
      await restored.load();
      expect(restored.allRecords, hasLength(2));
    },
  );
  test('legacy composite PRs migrate without losing handle or metrics', () {
    final record = PersonalRecord.fromJson({
      'exerciseId': 'cable_curl:Rope:wide',
      'bestWeight': 50,
      'bestReps': 8,
      'bestVolume': 400,
      'achievedAt': '2026-01-01',
    });
    expect(record.exerciseId, 'cable_curl');
    expect(record.handle, 'Rope:wide');
    expect(PersonalRecord.fromJson(record.toJson()).toJson(), record.toJson());
  });
  test('effective-bodyweight PRs do not compete with legacy raw PRs', () async {
    final storage = MockStorageService();
    await storage.savePersonalRecord(
      PersonalRecord(
        exerciseId: 'pull_ups',
        bestWeight: 300,
        bestReps: 8,
        bestVolume: 2400,
        achievedAt: DateTime(2026, 1, 1),
      ),
    );
    final prs = PRManager(storage);
    await prs.load();
    await prs.checkAndUpdatePRs(
      session(
        'new',
        8,
        bodySet(WorkoutLoadMode.assisted, weight: 10, reps: 10),
      ),
    );
    expect(prs.getRecord('pull_ups')!.bestWeight, 60);
    expect(prs.getRecord('pull_ups')!.loadEncodingVersion, 1);
    expect(await storage.getAllPersonalRecords(), hasLength(2));
  });
}
