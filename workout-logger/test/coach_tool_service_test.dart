// Unit tests for CoachToolService — each tool returns expected JSON shapes,
// backed by a seeded WorkoutProvider + PRManager.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' show FunctionCall;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/ai/sql_query_service.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  group('CoachToolService', () {
    late MockStorageService storage;
    late WorkoutProvider provider;
    late PRManager pr;
    late CoachToolService tools;

    WorkoutSession benchSession(DateTime date, double weight, {String? routineId}) {
      return WorkoutSession(
        id: 'sess-${date.millisecondsSinceEpoch}',
        date: date,
        routineId: routineId,
        duration: 45,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [
              WorkoutSet(weight: weight, reps: 8),
              WorkoutSet(weight: weight, reps: 8),
            ],
          ),
        ],
      );
    }

    setUp(() async {
      storage = MockStorageService();

      // Two bench sessions on different days → enough for a growth model.
      final now = DateTime.now();
      storage.addMockRoutine(
        Routine(id: 'r1', name: 'Push Day', exerciseIds: ['bench_press']),
      );
      storage.addMockSession(
        benchSession(now.subtract(const Duration(days: 10)), 60, routineId: 'r1'),
      );
      storage.addMockSession(
        benchSession(now.subtract(const Duration(days: 3)), 65, routineId: 'r1'),
      );

      provider = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await provider.init();

      pr = PRManager(storage);
      await pr.backfillFromSessions(provider.sessions);

      tools = CoachToolService(workoutProvider: provider, prManager: pr);
    });

    group('run_sql_query', () {
      late String dbPath;
      late SqliteStorageService sqliteStorage;

      setUpAll(() {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      });

      setUp(() async {
        dbPath = '${Directory.systemTemp.path}/coach_sql_test_${DateTime.now().microsecondsSinceEpoch}.db';
        sqliteStorage = SqliteStorageService(databasePathOverride: dbPath);
        await sqliteStorage.init();
        await sqliteStorage.saveWorkoutSession(WorkoutSession(
          id: 'sess1', date: DateTime(2026, 5, 1), duration: 40,
          exercises: [ExerciseLog(exerciseId: 'bench_press', sets: [WorkoutSet(weight: 70, reps: 8)])],
        ));
      });

      tearDown(() async {
        await sqliteStorage.close();
        // Best-effort cleanup: the sqflite ffi connection may still hold the
        // file handle open on some platforms (e.g. Windows), which would
        // otherwise turn cleanup noise into a spurious test failure.
        try {
          final f = File(dbPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      });

      test('is not advertised when no SqlQueryService is provided', () {
        final declared =
            tools.buildTools().expand((t) => t.functionDeclarations ?? []).map((f) => f.name);
        expect(declared, isNot(contains('run_sql_query')));
      });

      test('is advertised and runs a live SELECT when wired', () async {
        final withSql = CoachToolService(
          workoutProvider: provider,
          prManager: pr,
          sqlQuery: SqlQueryService(dbPath),
        );

        final declared =
            withSql.buildTools().expand((t) => t.functionDeclarations ?? []).map((f) => f.name);
        expect(declared, contains('run_sql_query'));

        final result = await withSql.handleCall(
          FunctionCall('run_sql_query', {'query': 'SELECT id, duration_min FROM sessions'}),
        );
        expect(result['row_count'], 1);
        expect((result['rows'] as List).first, {'id': 'sess1', 'duration_min': 40});
      });
    });

    test('exposes the expected tool declarations', () {
      final declared = tools
          .buildTools()
          .expand((t) => t.functionDeclarations ?? [])
          .map((f) => f.name)
          .toSet();
      expect(
        declared,
        containsAll([
          'get_exercise_performance',
          'get_workouts_in_range',
          'get_routine_performance',
          'get_personal_records',
          'get_goal_progress',
          'get_muscle_recovery',
        ]),
      );
    });

    test('get_exercise_performance returns trend + PR for a known exercise',
        () async {
      final result = await tools.handleCall(
        FunctionCall('get_exercise_performance', {'exercise_name': 'Bench Press'}),
      );

      expect(result['exercise'], 'Bench Press');
      expect(result['session_count'], 2);
      expect(result['volume_trend'], isA<List<dynamic>>());
      expect((result['volume_trend'] as List), isNotEmpty);
      expect(result['personal_record'], isNotNull);
    });

    test('get_exercise_performance returns an error for an unknown exercise',
        () async {
      final result = await tools.handleCall(
        FunctionCall('get_exercise_performance', {'exercise_name': 'Nonexistent'}),
      );
      expect(result['error'], isNotNull);
      expect(result['available_examples'], isA<List<dynamic>>());
    });

    test('get_workouts_in_range summarizes sessions in the window', () async {
      final result = await tools.handleCall(
        FunctionCall('get_workouts_in_range', {'days': 30}),
      );
      expect(result['session_count'], 2);
      expect(result['total_volume'], isA<num>());
      expect((result['total_volume'] as num) > 0, isTrue);
    });

    test('get_routine_performance returns sessions logged against the routine',
        () async {
      final result = await tools.handleCall(
        FunctionCall('get_routine_performance', {'routine_name': 'Push Day'}),
      );
      expect(result['routine'], 'Push Day');
      expect(result['session_count'], 2);
      expect(result['exercises'], contains('Bench Press'));
    });

    test('get_routine_performance errors for an unknown routine', () async {
      final result = await tools.handleCall(
        FunctionCall('get_routine_performance', {'routine_name': 'Leg Day'}),
      );
      expect(result['error'], isNotNull);
      expect(result['available_routines'], contains('Push Day'));
    });

    test('get_personal_records returns all records when unfiltered', () async {
      final result = await tools.handleCall(
        FunctionCall('get_personal_records', {}),
      );
      final records = result['records'] as List;
      expect(records, isNotEmpty);
      expect((records.first as Map)['exercise'], 'Bench Press');
    });

    test('get_goal_progress reflects active targets', () async {
      await provider.createTarget(
        exerciseId: 'bench_press',
        type: 'weight',
        targetValue: 100,
      );

      final result = await tools.handleCall(
        FunctionCall('get_goal_progress', {'exercise_name': 'Bench Press'}),
      );
      final goals = result['goals'] as List;
      expect(goals, hasLength(1));
      expect((goals.first as Map)['type'], 'weight');
      expect((goals.first as Map)['target_value'], 100);
    });

    test('get_muscle_recovery returns per-muscle status', () async {
      final result = await tools.handleCall(
        FunctionCall('get_muscle_recovery', {}),
      );
      final muscles = result['muscles'] as List;
      expect(muscles, isNotEmpty);
      final first = muscles.first as Map;
      expect(first['muscle'], isA<String>());
      expect(first['recovery_percent'], isA<int>());
      expect(first['status'], isA<String>());
    });

    test('add_custom_exercise creates timeBased exercise with handles', () async {
      final result = await tools.handleCall(
        FunctionCall('add_custom_exercise', {
          'name': 'Dead Hang',
          'category': 'isolation',
          'primary_muscle': 'forearms',
          'exercise_type': 'timeBased',
          'available_handles': ['Thick Bar', 'Standard Bar'],
        }),
      );
      expect(result['created'], true);
      expect(result['exercise_name'], 'Dead Hang');
      expect(result['exercise_type'], 'timeBased');
      expect(result['available_handles'], ['Thick Bar', 'Standard Bar']);

      final ex = provider.allExercises.firstWhere((e) => e.name == 'Dead Hang');
      expect(ex.exerciseType, ExerciseType.timeBased);
      expect(ex.availableHandles, ['Thick Bar', 'Standard Bar']);
    });

    test('update_exercise updates exercise metadata, type, and handles', () async {
      // First ensure an exercise exists
      await tools.handleCall(
        FunctionCall('add_custom_exercise', {
          'name': 'Cable Lateral Raise',
          'category': 'isolation',
          'primary_muscle': 'shoulders',
        }),
      );

      final updateResult = await tools.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'Cable Lateral Raise',
          'new_name': 'Cable Lateral Raise (Cuff)',
          'available_handles': ['Ankle Cuff', 'D-Handle'],
        }),
      );
      expect(updateResult['updated'], true);
      expect(updateResult['exercise_name'], 'Cable Lateral Raise (Cuff)');
      expect(updateResult['available_handles'], ['Ankle Cuff', 'D-Handle']);

      final updated = provider.allExercises.firstWhere(
        (e) => e.name == 'Cable Lateral Raise (Cuff)',
      );
      expect(updated.availableHandles, ['Ankle Cuff', 'D-Handle']);
    });

    test('create_routine saves default exercise_handles', () async {
      final result = await tools.handleCall(
        FunctionCall('create_routine', {
          'name': 'Upper Hypertrophy',
          'exercise_names': ['Bench Press'],
          'exercise_handles': {'Bench Press': 'Wide Grip'},
        }),
      );
      expect(result['created'], true);
      expect(result['routine_name'], 'Upper Hypertrophy');

      final routine = provider.routines.firstWhere((r) => r.name == 'Upper Hypertrophy');
      expect(routine.defaultHandles?['bench_press'], 'Wide Grip');
    });

    test('create_routine and update_routine support list of object handles and clearing handles', () async {
      final createRes = await tools.handleCall(
        FunctionCall('create_routine', {
          'name': 'Back and Biceps',
          'exercise_names': ['Bench Press'],
          'exercise_handles': [
            {'exercise_name': 'Bench Press', 'handle': 'Close Grip'},
          ],
        }),
      );
      expect(createRes['created'], true);
      var routine = provider.routines.firstWhere((r) => r.name == 'Back and Biceps');
      expect(routine.defaultHandles?['bench_press'], 'Close Grip');

      // Update routine to clear handle
      final updateRes = await tools.handleCall(
        FunctionCall('update_routine', {
          'routine_name': 'Back and Biceps',
          'exercise_handles': [
            {'exercise_name': 'Bench Press', 'handle': ''},
          ],
        }),
      );
      expect(updateRes['updated'], true);
      routine = provider.routines.firstWhere((r) => r.name == 'Back and Biceps');
      expect(routine.defaultHandles?.containsKey('bench_press') ?? false, false);
    });

    test('add_custom_exercise and update_exercise reject invalid exercise_type', () async {
      final invalidAdd = await tools.handleCall(
        FunctionCall('add_custom_exercise', {
          'name': 'Invalid Exercise',
          'category': 'isolation',
          'primary_muscle': 'shoulders',
          'exercise_type': 'repsOnly',
        }),
      );
      expect(invalidAdd['error'], contains('Invalid exercise_type'));

      final invalidUpdate = await tools.handleCall(
        FunctionCall('update_exercise', {
          'exercise_name': 'Bench Press',
          'exercise_type': 'cardioBased',
        }),
      );
      expect(invalidUpdate['error'], contains('Invalid exercise_type'));
    });
  });
}
