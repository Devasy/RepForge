import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/models/health_connect_workout.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/health_workout_import.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

class LabelPersistenceStorage extends MockStorageService {
  int exerciseWrites = 0;
  @override
  Future<void> saveCustomExercise(Exercise exercise) async {
    exerciseWrites++;
    await super.saveCustomExercise(exercise);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
    'v12 repairs split library PRs without losing handles or best values',
    () async {
      final dir = await Directory.systemTemp.createTemp('pr-repair-');
      final path = '${dir.path}/test.db';
      final storage = SqliteStorageService(databasePathOverride: path);
      await storage.init();
      await storage.saveWorkoutSession(
        WorkoutSession(
          id: 'imported',
          date: DateTime(2026),
          duration: 1,
          exercises: [
            ExerciseLog(
              exerciseId: 'fitify:bo999_example',
              sets: [WorkoutSet(weight: 0, reps: 0, timeTaken: 60)],
            ),
          ],
        ),
      );
      await storage.close();
      final db = await openDatabase(path);
      await db.insert('personal_records', {
        'exercise_id': 'fitify',
        'handle': 'bo999_example',
        'load_encoding_version': 0,
        'best_weight': 0,
        'best_reps': 0,
        'best_volume': 0,
        'best_duration': 60,
        'achieved_at': '2026-01-02',
      });
      await db.insert('personal_records', {
        'exercise_id': 'fitify:bo999_example',
        'handle': '',
        'load_encoding_version': 0,
        'best_weight': 0,
        'best_reps': 0,
        'best_volume': 0,
        'best_duration': 30,
        'achieved_at': '2026-01-01',
      });
      await db.insert('personal_records', {
        'exercise_id': 'bench_press',
        'handle': 'Wide',
        'load_encoding_version': 0,
        'best_weight': 50,
        'best_reps': 8,
        'best_volume': 400,
        'achieved_at': '2026-01-01',
      });
      await db.setVersion(11);
      await db.close();
      final migrated = SqliteStorageService(databasePathOverride: path);
      try {
        await migrated.init();
        final records = await migrated.getAllPersonalRecords();
        expect(records, hasLength(2));
        final repaired = (await migrated.getPersonalRecord(
          'fitify:bo999_example',
        ))!;
        expect(repaired.exerciseId, 'fitify:bo999_example');
        expect(repaired.handle, isNull);
        expect(repaired.bestDuration, 60);
        expect(
          records.singleWhere((r) => r.exerciseId == 'bench_press').handle,
          'Wide',
        );
      } finally {
        await migrated.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'library exercises retain labels and profiles without downloaded cache',
    () async {
      final storage = LabelPersistenceStorage();
      final history = HistoryManager(storage);
      final provider = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        historyManager: history,
        programManager: ProgramManager(storage),
      );
      await provider.init();
      final actual =
          jsonDecode(File('../catalogues/fitify-v1.json').readAsStringSync())
              as Map<String, dynamic>;
      actual['exercises'] = [
        {
          'code': 'bo999_example',
          'name': 'Example Hold',
          'exerciseType': 'timeBased',
          'resistance': {'abs': 8},
          'stretch': {'hamstrings': 3},
        },
      ];
      await provider.loadExtendedLibrary(jsonEncode(actual));
      await storage.saveWorkoutSession(
        WorkoutSession(
          id: 'imported',
          date: DateTime(2026),
          duration: 1,
          importSource: {'origin': 'source.app'},
          exercises: [
            ExerciseLog(
              exerciseId: 'fitify:bo999_example',
              sets: [WorkoutSet(weight: 0, reps: 0, timeTaken: 30)],
            ),
          ],
        ),
      );
      final first = (await storage.getAllWorkoutSessions()).single;
      await storage.saveWorkoutSession(
        WorkoutSession(
          id: 'second-import',
          date: first.date,
          duration: first.duration,
          importSource: first.importSource,
          exercises: first.exercises,
        ),
      );
      storage.exerciseWrites = 0;
      await provider.loadAllData();
      expect(storage.exerciseWrites, 1);
      await storage.saveSetting('exerciseLibrary.fitify.v1', 'invalid cache');
      await provider.loadAllData();
      expect(provider.getExerciseName('fitify:bo999_example'), 'Example Hold');
      expect(
        provider.getExercise('fitify:bo999_example')!.exerciseType,
        ExerciseType.timeBased,
      );
      expect(provider.getExercise('fitify:bo999_example')!.stretchIntensities, {
        'hamstrings': 3,
      });
      provider.dispose();
    },
  );

  test('summary-only imports refresh visible history', () async {
    final storage = MockStorageService();
    final history = HistoryManager(storage);
    final provider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      historyManager: history,
      programManager: ProgramManager(storage),
    );
    await provider.init();
    final start = DateTime.utc(2026, 11, 13);
    final result = await provider.importHealthWorkouts([
      HealthConnectWorkout(
        recordId: 'summary',
        origin: 'other.app',
        start: start,
        end: start.add(const Duration(minutes: 10)),
        segments: [],
      ),
    ]);
    expect(result.added, 1);
    expect(history.sessions, hasLength(1));
    provider.dispose();
  });
  test('canonical PR IDs are opaque and do not become handles', () {
    final record = PersonalRecord(
      exerciseId: 'fitify:bo999_example',
      bestWeight: 0,
      bestReps: 0,
      bestVolume: 0,
      bestDuration: 30,
      achievedAt: DateTime(2026),
    );
    expect(record.exerciseId, 'fitify:bo999_example');
    expect(record.handle, isNull);
    expect(
      PersonalRecord.fromJson(record.toJson()).exerciseId,
      record.exerciseId,
    );
    expect(PersonalRecord.aggregate([record])!.exerciseId, record.exerciseId);
  });

  test(
    'native segments preserve sets and update versionless source records',
    () {
      final start = DateTime.utc(2026, 11, 13, 10);
      HealthConnectWorkout source(int seconds) => HealthConnectWorkout(
        recordId: 'native',
        origin: 'training.app',
        start: start,
        end: start.add(Duration(seconds: seconds)),
        segments: [
          HealthConnectWorkoutSegment(
            start: start,
            end: start.add(Duration(seconds: seconds)),
            isRest: false,
            exerciseId: 'plank',
            segmentType: 'plank',
          ),
        ],
      );
      final session = HealthWorkoutImport.convert(
        source(30),
        exercises: ExerciseDatabase.getAll(),
      );
      expect(session.exercises.single.exerciseId, 'plank');
      expect(session.exercises.single.sets.single.isTimeBased, isTrue);
      expect(
        session.exercises.single.sets.single.loadMode,
        WorkoutLoadMode.unknown,
      );
      expect(session.importSource!['timingReconstructed'], false);
      expect(
        HealthWorkoutImport.inspect(
          source(60),
          exercises: ExerciseDatabase.getAll(),
          existing: session,
        ).action,
        WorkoutImportAction.update,
      );
      expect(
        HealthWorkoutImport.inspect(
          source(60),
          exercises: ExerciseDatabase.getAll(),
          existing: session.copyWith(notes: 'My own notes'),
        ).action,
        WorkoutImportAction.conflict,
      );
    },
  );

  test('imports ordinary Health Connect sessions without custom notes', () {
    final start = DateTime.utc(2026, 11, 13, 10);
    final record = HealthConnectWorkout(
      recordId: 'ordinary',
      origin: 'another.workout.app',
      start: start,
      end: start.add(const Duration(minutes: 20)),
      segments: [],
      title: 'Morning training',
    );
    final session = HealthWorkoutImport.convert(
      record,
      exercises: ExerciseDatabase.getAll(),
    );
    expect(session.duration, 20);
    expect(session.exercises, isEmpty);
    expect(session.importSource!['origin'], 'another.workout.app');
    expect(
      HealthWorkoutImport.inspect(
        record,
        exercises: ExerciseDatabase.getAll(),
      ).message,
      contains('Limited exercise details'),
    );
    expect(session.notes, isNot(contains('Fitify')));
    final other = HealthConnectWorkout(
      recordId: 'ordinary',
      origin: 'different.app',
      start: start,
      end: record.end,
      segments: [],
    );
    expect(
      HealthWorkoutImport.localId(record),
      isNot(HealthWorkoutImport.localId(other)),
    );
    expect(
      HealthWorkoutImport.inspect(
        record,
        exercises: ExerciseDatabase.getAll(),
        existing: session,
      ).action,
      WorkoutImportAction.current,
    );
  });
}
