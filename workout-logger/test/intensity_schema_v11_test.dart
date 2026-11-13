import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/health_workout_import.dart';
import 'fitify_workout_import_test.dart' show sourceWorkout;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'v10 upgrade preserves fractional resistance and stretch without join table',
    () async {
      final dir = await Directory.systemTemp.createTemp('repforge-v10-');
      final path = '${dir.path}/legacy.db';
      final old = await openDatabase(
        path,
        version: 10,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE muscle_groups (id TEXT PRIMARY KEY, name TEXT, growth_rate REAL, last_updated TEXT)',
          );
          await db.execute(
            'CREATE TABLE exercises (id TEXT PRIMARY KEY, name TEXT, category TEXT, is_custom INTEGER, available_handles TEXT, exercise_type TEXT, stretch_intensities TEXT, resistance_intensity_override INTEGER)',
          );
          await db.execute(
            'CREATE TABLE exercise_muscle_activations (exercise_id TEXT, muscle_group_id TEXT, activation_percentage INTEGER)',
          );
          await db.insert('exercises', {
            'id': 'custom_a',
            'name': 'Example',
            'category': 'other',
            'is_custom': 1,
            'exercise_type': 'weightAndReps',
            'stretch_intensities': '{"chest":3}',
            'resistance_intensity_override': 1,
          });
          await db.insert('exercise_muscle_activations', {
            'exercise_id': 'custom_a',
            'muscle_group_id': 'chest',
            'activation_percentage': 95,
          });
          await db.insert('exercise_muscle_activations', {
            'exercise_id': 'custom_a',
            'muscle_group_id': 'triceps',
            'activation_percentage': 50,
          });
        },
      );
      await old.close();
      final storage = SqliteStorageService(databasePathOverride: path);
      try {
        await storage.init();
        final exercise = (await storage.getCustomExercises()).single;
        expect(exercise.toJson()['resistanceIntensities'], {
          'chest': 9.5,
          'triceps': 5.0,
        });
        expect(exercise.stretchIntensities, {'chest': 3});
        final db = await openReadOnlyDatabase(path, singleInstance: false);
        expect(
          await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE name='exercise_muscle_activations'",
          ),
          isEmpty,
        );
        expect(
          jsonDecode(
            (await db.query('exercises')).single['resistance_intensities']
                as String,
          ),
          {'chest': 9.5, 'triceps': 5.0},
        );
        await db.close();
        await storage.saveCustomExercise(exercise.copyWith(name: 'Renamed'));
        expect(
          (await storage.getCustomExercises())
              .single
              .muscleActivations
              .first
              .activationPercentage,
          95,
        );
      } finally {
        await storage.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'old activation backups become canonical intensity maps without rounding',
    () {
      final exercise = Exercise.fromJson({
        'id': 'a',
        'name': 'A',
        'category': 'other',
        'muscleActivations': [
          {'muscleGroupId': 'chest', 'activationPercentage': 95},
        ],
      });
      expect(exercise.toJson()['resistanceIntensities'], {'chest': 9.5});
      expect(exercise.toJson().containsKey('muscleActivations'), isFalse);
      expect(
        Exercise.fromJson(
          exercise.toJson(),
        ).muscleActivations.single.activationPercentage,
        95,
      );
    },
  );
  test(
    'import provenance and unknown loads survive SQLite and backup roundtrip',
    () async {
      final storage = SqliteStorageService(
        databasePathOverride: inMemoryDatabasePath,
      );
      await storage.init();
      try {
        final session = HealthWorkoutImport.convert(
          sourceWorkout(),
          exercises: await storage.getAllExercises(),
        );
        await storage.saveWorkoutSession(session);
        final stored = (await storage.database.query('sessions')).single;
        final utc =
            jsonDecode(stored['import_source'] as String)['_storageUtc'] as Map;
        expect(utc['date'], session.date.toUtc().toIso8601String());
        expect(stored['date'], session.date.toIso8601String());
        expect(
          (session.toJson()['exercises'] as List).first['sets'][0]['timestamp'],
          endsWith('Z'),
        );
        await storage.database.update(
          'sessions',
          {'date': '2026-11-12T03:00:00.000'},
          where: 'id = ?',
          whereArgs: [session.id],
        );
        final restored = (await storage.getAllWorkoutSessions()).single;
        expect(restored.date.toUtc(), session.date.toUtc());
        expect(restored.importSource, session.importSource);
        expect(
          restored.exercises.single.sets.first.loadMode,
          WorkoutLoadMode.unknown,
        );
        expect(
          HealthWorkoutImport.contentSnapshot(restored),
          restored.importSource!['contentSnapshot'],
        );
        final backup = jsonDecode(await storage.exportAllData()) as Map;
        expect(
          (backup['sessions'] as List).single['importSource'],
          session.importSource,
        );
      } finally {
        await storage.close();
      }
    },
  );
}
