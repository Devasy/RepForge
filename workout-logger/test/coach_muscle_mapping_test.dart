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
