import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/services/extended_exercise_library.dart';

void main() {
  test('aggregate muscle filters retain directly scored aggregate IDs', () {
    final profile = MuscleIntensityProfile.parse({
      'code': 'aggregate',
      'name': 'Aggregate',
      'exerciseType': 'weightAndReps',
      'resistance': {'shoulders': 8},
      'stretch': {'core': 5},
    }, 'test');
    expect(profile.matchesMuscle('shoulders'), isTrue);
    expect(profile.matchesMuscle('core'), isTrue);
  });
  Map<String, dynamic> catalogue() => {
    'schema': 'repforge.exercise_library',
    'version': 1,
    'source': {'name': 'Fitify', 'appVersion': '1.136.0'},
    'exercises': [
      {
        'code': 'bb008_bench_press',
        'name': 'Bench Press',
        'exerciseType': 'weightAndReps',
        'resistance': {'chest': 8, 'triceps': 5},
        'stretch': {'chest': 2},
      },
      {
        'code': 'yo003_boat',
        'name': 'Boat',
        'exerciseType': 'timeBased',
        'resistance': {'abs': 8, 'quads': 6},
        'stretch': {'hamstrings': 4},
      },
    ],
  };

  test('enriches built-ins without changing identity or analysis weights', () {
    final original = ExerciseDatabase.getById('bench_press')!;
    final library = ExtendedExerciseLibrary.fromJson(jsonEncode(catalogue()));
    final merged = library.mergeExercises([original]);
    expect(merged.where((e) => e.id == 'bench_press'), hasLength(1));
    expect(merged.first, same(original));
    expect(library.profileFor('bench_press')!.resistance['chest'], 8);
    expect(library.profileFor('bench_press')!.stretch['chest'], 2);
    expect(merged.last.id, 'fitify:yo003_boat');
    expect(merged.last.exerciseType.name, 'timeBased');
    expect(
      merged.last.muscleActivations
          .singleWhere((a) => a.muscleGroupId == 'abs')
          .activationPercentage,
      80,
    );
    expect(library.mergeExercises(merged), hasLength(2));
  });

  test('rejects unsupported versions, duplicate codes and invalid scores', () {
    final badVersion = catalogue()..['version'] = 2;
    expect(
      () => ExtendedExerciseLibrary.fromJson(jsonEncode(badVersion)),
      throwsFormatException,
    );
    final duplicate = catalogue();
    (duplicate['exercises'] as List).add(
      (duplicate['exercises'] as List).first,
    );
    expect(
      () => ExtendedExerciseLibrary.fromJson(jsonEncode(duplicate)),
      throwsFormatException,
    );
    for (final value in [0, 11, 1.5, '8']) {
      final bad = catalogue();
      bad['exercises'][0]['resistance'] = {'chest': value};
      expect(
        () => ExtendedExerciseLibrary.fromJson(jsonEncode(bad)),
        throwsFormatException,
      );
    }
    final unknown = catalogue();
    unknown['exercises'][0]['stretch'] = {'mystery': 4};
    expect(
      () => ExtendedExerciseLibrary.fromJson(jsonEncode(unknown)),
      throwsFormatException,
    );
  });

  test('keeps empty, stretch-only and tied source scores intact', () {
    final data = catalogue();
    data['exercises'][0]['resistance'] = <String, int>{};
    data['exercises'][1]['resistance'] = {'abs': 8, 'quads': 8};
    final library = ExtendedExerciseLibrary.fromJson(jsonEncode(data));
    expect(library.profileFor('bench_press')!.resistance, isEmpty);
    expect(library.profileFor('bench_press')!.stretch, {'chest': 2});
    expect(library.profileFor('fitify:yo003_boat')!.resistance, {
      'abs': 8,
      'quads': 8,
    });
  });

  test(
    'full downloadable catalogue has 937 distinct exercises and 22 muscles',
    () {
      final library = ExtendedExerciseLibrary.fromJson(
        File('../catalogues/fitify-v1.json').readAsStringSync(),
      );
      expect(library.length, 937);
      final profiles = library.profiles.values;
      expect(profiles.where((p) => p.resistance.isNotEmpty), hasLength(761));
      expect(profiles.where((p) => p.stretch.isNotEmpty), hasLength(211));
      expect(
        profiles
            .expand((p) => [...p.resistance.keys, ...p.stretch.keys])
            .toSet(),
        hasLength(22),
      );
      var references = 0;
      for (final exercise in ExerciseDatabase.getAll()) {
        final local = ExtendedExerciseLibrary.builtInProfileFor(exercise.id);
        if (local == null) continue;
        references++;
        final remote = library.profileFor(exercise.id)!;
        expect(local.code, remote.code);
        expect(local.resistance, remote.resistance);
        expect(local.stretch, remote.stretch);
      }
      expect(references, 32);
    },
  );
}
