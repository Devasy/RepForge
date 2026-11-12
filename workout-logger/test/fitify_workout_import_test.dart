import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/models/health_connect_workout.dart';
import 'package:repforge/services/fitify_workout_import.dart';

HealthConnectWorkout sourceWorkout({
  String origin = 'com.fitifysync.app',
  int version = 1,
  String code = 'bo233_push_ups',
  String? notes,
}) {
  final start = DateTime.utc(2026, 11, 12, 10);
  return HealthConnectWorkout(
    recordId: 'hc-a',
    clientRecordId: 'fitify_a',
    version: version,
    origin: origin,
    start: start,
    end: start.add(const Duration(minutes: 2)),
    title: 'Fitify workout',
    notes:
        notes ??
        'Fitify workout\n\n${jsonEncode({
          'schema': 'fitifysync.exercise_segments',
          'version': 1,
          'exercises': [
            {'segment_index': 1, 'code': code, 'name': 'Push-Ups', 'timing_kind': 'reconstructed'},
            {'segment_index': 3, 'code': code, 'name': 'Push-Ups', 'timing_kind': 'reconstructed'},
          ],
        })}',
    segments: [
      for (var i = 0; i < 4; i++)
        HealthConnectWorkoutSegment(
          start: start.add(Duration(seconds: i * 20)),
          end: start.add(Duration(seconds: (i + 1) * 20)),
          isRest: i.isEven,
          repetitions: i.isEven ? 0 : 8,
        ),
    ],
  );
}

void main() {
  test(
    'maps exact Fitify codes and retains repeated sets at rest-relative indices',
    () {
      final session = FitifyWorkoutImport.convert(
        sourceWorkout(),
        exercises: ExerciseDatabase.getAll(),
      );
      expect(session.exercises.map((e) => e.exerciseId), ['push_ups']);
      expect(session.exercises.single.sets.map((s) => s.reps), [8, 8]);
      expect(
        session.exercises.single.sets.first.loadMode,
        WorkoutLoadMode.unknown,
      );
      expect(session.totalVolume, 0);
      expect(session.importSource!['rawRecord'], sourceWorkout().toJson());
      expect(session.exercises.single.notes, contains('reconstructed'));
    },
  );
  test(
    'rejects another origin, unknown code and malformed or newer payloads',
    () {
      for (final source in [
        sourceWorkout(origin: 'com.other'),
        sourceWorkout(code: 'unverified'),
        sourceWorkout(
          notes:
              '{"schema":"fitifysync.exercise_segments","version":2,"exercises":[]}',
        ),
        sourceWorkout(notes: 'bad'),
      ]) {
        expect(
          () => FitifyWorkoutImport.convert(
            source,
            exercises: ExerciseDatabase.getAll(),
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'rejects duplicate/rest/out of range indices and incomplete identities',
    () {
      for (final indices in [
        [1, 1],
        [0, 3],
        [1, 40],
        [1],
      ]) {
        final notes = jsonEncode({
          'schema': 'fitifysync.exercise_segments',
          'version': 1,
          'exercises': [
            for (final index in indices)
              {
                'segment_index': index,
                'code': 'bo233_push_ups',
                'name': 'Push-Ups',
                'timing_kind': 'reconstructed',
              },
          ],
        });
        expect(
          () => FitifyWorkoutImport.convert(
            sourceWorkout(notes: notes),
            exercises: ExerciseDatabase.getAll(),
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'unknown load survives backup and cannot be compared with recorded loads',
    () {
      final imported = FitifyWorkoutImport.convert(
        sourceWorkout(),
        exercises: ExerciseDatabase.getAll(),
      );
      final restored = WorkoutSession.fromJson(
        jsonDecode(jsonEncode(imported.toJson())),
      );
      final set = restored.exercises.single.sets.first;
      expect(set.loadMode, WorkoutLoadMode.unknown);
      expect(set.hasComparableLoad(WorkoutSet(weight: 0, reps: 8)), isFalse);
      expect(restored.importSource, imported.importSource);
    },
  );
  test('blank notes are unresolved instead of aborting a batch', () {
    expect(
      FitifyWorkoutImport.inspect(
        sourceWorkout(notes: '   '),
        exercises: ExerciseDatabase.getAll(),
      ).action,
      FitifyImportAction.unresolved,
    );
  });
  test('unknown-load holds retain duration without inventing load volume', () {
    final set = WorkoutSet(
      weight: 0,
      reps: 0,
      timeTaken: 30,
      loadMode: WorkoutLoadMode.unknown,
    );
    expect(set.volume, 0);
    expect(set.timeTaken, 30);
  });
}
