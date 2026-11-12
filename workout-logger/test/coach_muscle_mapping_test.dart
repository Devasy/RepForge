import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/workout_provider.dart';

void main() {
  late SqliteStorageService storage;
  late WorkoutProvider provider;
  late CoachToolService coach;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    storage = SqliteStorageService(databasePathOverride: inMemoryDatabasePath);
    await storage.init();
    provider = WorkoutProvider(
      storage,
      programManager: ProgramManager(storage),
    );
    await provider.init();
    coach = CoachToolService(
      workoutProvider: provider,
      prManager: PRManager(storage),
    );
  });

  tearDown(() async {
    final path = storage.databasePath;
    provider.dispose();
    await storage.close();
    final file = File(path);
    if (await file.exists()) await file.delete();
  });

  Map<String, Object?> activation(String muscle, Object weight) => {
    'muscle': muscle,
    'activation_percentage': weight,
  };

  Future<Map<String, Object?>> create([Object? activations]) =>
      coach.handleCall(
        FunctionCall('add_custom_exercise', {
          'name': 'Variant Push Up',
          'category': 'compound',
          'primary_muscle': 'chest',
          'muscle_activations': ?activations,
        }),
      );

  List<Map<String, Object?>> pushMuscles() => [
    activation('Triceps', 70),
    activation('Chest', 90),
    activation('Core', 30),
  ];

  test(
    'duplicate extended names require an exact source ID before editing',
    () async {
      await provider.loadExtendedLibrary(
        File('../catalogues/fitify-v1.json').readAsStringSync(),
      );
      final ambiguous = await coach.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'Face Pulls',
          'new_name': 'Wrong variant',
        }),
      );
      expect(ambiguous, contains('ambiguous_matches'));
      final resolved = await coach.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'fitify:gm255_cable_face_pull',
          'new_name': 'My cable face pull',
          'stretch_intensities': [
            {'muscle': 'rear_delts', 'intensity': 3},
          ],
        }),
      );
      expect(resolved['updated'], true);
      expect(
        provider.getExercise('fitify:gm255_cable_face_pull')!.name,
        'My cable face pull',
      );
      expect(
        provider.getExercise('fitify:gm033_cable_rope_rear_delt_rows')!.name,
        'Face Pulls',
      );
    },
  );

  test(
    'legacy built-in resistance edits remain visible without the new flag',
    () async {
      final original = provider.getExercise('bench_press')!;
      await storage.saveCustomExercise(
        original.copyWith(name: 'Renamed bench'),
      );
      await provider.loadAllData();
      expect(provider.muscleProfileFor('bench_press')!.resistance['chest'], 9);
      final legacy = Exercise.fromJson({
        ...original.toJson(),
        'muscleActivations': [
          {'muscleGroupId': 'chest', 'activationPercentage': 40},
          {'muscleGroupId': 'triceps', 'activationPercentage': 20},
        ],
      });
      await storage.saveCustomExercise(legacy);
      await provider.loadAllData();
      expect(provider.muscleProfileFor('bench_press')!.resistance, {
        'chest': 4,
        'triceps': 2,
      });
      expect(
        provider.muscleProfileFor('bench_press')!.resistanceAttribution,
        'User/coach estimate',
      );
    },
  );

  test(
    'coach creates separate resistance and stretch scores, allowing tied resistance',
    () async {
      final result = await coach.handleCall(
        FunctionCall('add_custom_exercise', {
          'name': 'Scored push up',
          'category': 'compound',
          'primary_muscle': 'chest',
          'resistance_intensities': [
            {'muscle': 'chest', 'intensity': 8},
            {'muscle': 'triceps', 'intensity': 8},
          ],
          'stretch_intensities': [
            {'muscle': 'front_delts', 'intensity': 3},
          ],
        }),
      );
      expect(result['created'], true);
      final id = result['exercise_id'] as String;
      final exercise = provider.getExercise(id)!;
      expect(exercise.muscleActivations.map((a) => a.activationPercentage), [
        80,
        80,
      ]);
      expect(exercise.toJson()['stretchIntensities'], {'front_delts': 3});
      expect(provider.muscleProfileFor(id)!.resistance, {
        'chest': 8,
        'triceps': 8,
      });
      expect(provider.muscleProfileFor(id)!.stretch, {'front_delts': 3});
      expect(result['stretch_intensities'], [
        {'muscle': 'front_delts', 'intensity': 3},
      ]);
      final backup = await storage.exportAllData();
      final restored = SqliteStorageService(
        databasePathOverride: inMemoryDatabasePath,
      );
      await restored.init();
      try {
        await restored.importData(backup);
        expect(
          (await restored.getExercise(id))!.toJson()['stretchIntensities'],
          {'front_delts': 3},
        );
      } finally {
        final path = restored.databasePath;
        await restored.close();
        await File(path).delete();
      }
      final path = storage.databasePath;
      await storage.close();
      storage = SqliteStorageService(databasePathOverride: path);
      await storage.init();
      expect((await storage.getExercise(id))!.toJson()['stretchIntensities'], {
        'front_delts': 3,
      });
    },
  );

  test(
    'omitted scores survive rename, stretch-only updates leave resistance unchanged, empty clears',
    () async {
      final created = await create(pushMuscles());
      final id = created['exercise_id'] as String;
      final changed = await coach.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'Variant Push Up',
          'stretch_intensities': [
            {'muscle': 'chest', 'intensity': 4},
          ],
        }),
      );
      expect(changed['updated'], true);
      final before = provider
          .getExercise(id)!
          .muscleActivations
          .map((a) => a.toJson())
          .toList();
      await coach.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'Variant Push Up',
          'new_name': 'Renamed push up',
        }),
      );
      expect(provider.getExercise(id)!.toJson()['stretchIntensities'], {
        'chest': 4,
      });
      await coach.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'Renamed push up',
          'stretch_intensities': <Object>[],
        }),
      );
      expect(provider.getExercise(id)!.toJson()['stretchIntensities'], isEmpty);
      expect(
        provider
            .getExercise(id)!
            .muscleActivations
            .map((a) => a.toJson())
            .toList(),
        before,
      );
    },
  );

  test('explicit stretch-only creation does not invent resistance', () async {
    final result = await coach.handleCall(
      FunctionCall('add_custom_exercise', {
        'name': 'Gentle chest stretch',
        'category': 'isolation',
        'primary_muscle': 'chest',
        'resistance_intensities': <Object>[],
        'stretch_intensities': [
          {'muscle': 'chest', 'intensity': 7},
        ],
        'exercise_type': 'timeBased',
      }),
    );
    expect(result['created'], true);
    final exercise = provider.getExercise(result['exercise_id'] as String)!;
    expect(exercise.muscleActivations, isEmpty);
    expect(provider.muscleProfileFor(exercise.id)!.stretch, {'chest': 7});
  });

  test(
    'invalid or conflicting intensity proposals cannot create exercises',
    () async {
      for (final input in [
        [
          {'muscle': 'chest', 'intensity': 11},
        ],
        [
          {'muscle': 'chest', 'intensity': 0},
        ],
        [
          {'muscle': 'chest', 'intensity': 2.5},
        ],
        [
          {'muscle': 'unknown', 'intensity': 3},
        ],
        [
          {'muscle': 'chest', 'intensity': 3},
          {'muscle': 'Chest', 'intensity': 5},
        ],
      ]) {
        final result = await coach.handleCall(
          FunctionCall('add_custom_exercise', {
            'name': 'Invalid score',
            'category': 'compound',
            'primary_muscle': 'chest',
            'stretch_intensities': input,
          }),
        );
        expect(result, contains('error'));
      }
      final result = await coach.handleCall(
        FunctionCall('add_custom_exercise', {
          'name': 'Conflicting score',
          'category': 'compound',
          'primary_muscle': 'chest',
          'muscle_activations': pushMuscles(),
          'resistance_intensities': [
            {'muscle': 'chest', 'intensity': 8},
          ],
        }),
      );
      expect(result, contains('error'));
      expect(await storage.getCustomExercises(), isEmpty);
    },
  );

  test(
    'coach stores primary and secondary weights across a database reopen',
    () async {
      final result = await create(pushMuscles());
      expect(result['created'], true);
      expect(result['exercise_id'], startsWith('custom_'));
      final summary = result['muscle_activations'] as List;
      expect((summary.first as Map)['role'], 'primary');
      expect((summary[1] as Map)['role'], 'secondary');
      // Independent involvement weights are intentionally not normalized to 100.
      expect(summary.map((v) => (v as Map)['activation_percentage']), [
        90,
        70,
        30,
      ]);
      final id = result['exercise_id'] as String;
      final path = storage.databasePath;
      await storage.close();
      storage = SqliteStorageService(databasePathOverride: path);
      await storage.init();
      final exercise = (await storage.getCustomExercises()).single;
      expect(exercise.id, id);
      expect(exercise.primaryMuscle, 'chest');
      expect(exercise.muscleActivations.map((a) => a.muscleGroupId).toSet(), {
        'chest',
        'triceps',
        'core',
      });
      final jsonRoundTrip = Exercise.fromJson(exercise.toJson());
      expect(
        jsonRoundTrip.muscleActivations
            .map((a) => a.activationPercentage)
            .toSet(),
        {90, 70, 30},
      );
    },
  );

  test('legacy creation defaults to the single primary muscle', () async {
    final result = await create();
    expect(result['created'], true);
    final exercise = provider.getExercise(result['exercise_id'] as String)!;
    expect(exercise.muscleActivations.single.activationPercentage, 100);
  });

  test(
    'unrelated edits and reselecting the primary keep secondary assignments',
    () async {
      final created = await create(pushMuscles());
      final result = await coach.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'Variant Push Up',
          'new_name': 'Variant Push Up Revised',
          'primary_muscle': 'chest',
          'available_handles': ['Floor'],
        }),
      );
      expect(result['updated'], true);
      final exercise = provider.getExercise(created['exercise_id'] as String)!;
      expect(exercise.muscleActivations.map((a) => a.activationPercentage), [
        90,
        70,
        30,
      ]);
      expect(
        (await storage.getCustomExercises()).single.muscleActivations,
        hasLength(3),
      );
    },
  );

  test(
    'changing primary requires an explicit full replacement and preserves ID',
    () async {
      final created = await create(pushMuscles());
      final rejected = await coach.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'Variant Push Up',
          'primary_muscle': 'triceps',
        }),
      );
      expect(rejected['error'], contains('full muscle activation list'));
      expect(
        provider.getExercise(created['exercise_id'] as String)!.primaryMuscle,
        'chest',
      );
      final updated = await coach.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'Variant Push Up',
          'primary_muscle': 'triceps',
          'muscle_activations': [
            activation('triceps', 90),
            activation('chest', 60),
          ],
        }),
      );
      expect(updated['updated'], true);
      expect(updated['exercise_id'], created['exercise_id']);
      final exercise = (await storage.getCustomExercises()).single;
      expect(exercise.primaryMuscle, 'triceps');
      expect(exercise.muscleActivations, hasLength(2));
    },
  );

  final invalidMappings = <String, Object>{
    'empty mapping': <Object>[],
    'unknown muscle': [
      {'muscle': 'imaginary muscle', 'activation_percentage': 90},
    ],
    'ambiguous muscle': [
      {'muscle': 'delts', 'activation_percentage': 90},
    ],
    'fractional weight': [
      {'muscle': 'chest', 'activation_percentage': 90.5},
    ],
    'zero weight': [
      {'muscle': 'chest', 'activation_percentage': 0},
    ],
    'excessive weight': [
      {'muscle': 'chest', 'activation_percentage': 101},
    ],
    'duplicate alias': [
      {'muscle': 'Chest', 'activation_percentage': 90},
      {'muscle': 'chest', 'activation_percentage': 50},
    ],
    'missing primary': [
      {'muscle': 'triceps', 'activation_percentage': 70},
    ],
    'secondary outranks primary': [
      {'muscle': 'chest', 'activation_percentage': 60},
      {'muscle': 'triceps', 'activation_percentage': 90},
    ],
    'tied primary': [
      {'muscle': 'chest', 'activation_percentage': 90},
      {'muscle': 'triceps', 'activation_percentage': 90},
    ],
  };
  for (final entry in invalidMappings.entries) {
    test('rejects ${entry.key} without creating an exercise', () async {
      final before = provider.allExercises.length;
      final result = await create(entry.value);
      expect(result['error'], isNotNull);
      expect(provider.allExercises, hasLength(before));
      expect(await storage.getCustomExercises(), isEmpty);
    });
  }

  test('provider validation also protects non-coach callers', () async {
    await expectLater(
      provider.addCustomExercise(
        name: 'Invalid Mapping',
        category: 'compound',
        primaryMuscleGroupId: 'chest',
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'unknown', activationPercentage: 90),
        ],
      ),
      throwsArgumentError,
    );
    expect(await storage.getCustomExercises(), isEmpty);
  });

  test(
    'name normalization prevents duplicate custom exercise creation',
    () async {
      await create(pushMuscles());
      final result = await coach.handleCall(
        FunctionCall('add_custom_exercise', {
          'name': '  VARIANT   PUSH UP ',
          'category': 'compound',
          'primary_muscle': 'chest',
        }),
      );
      expect(result['error'], contains('already exists'));
      expect(await storage.getCustomExercises(), hasLength(1));
    },
  );
}
