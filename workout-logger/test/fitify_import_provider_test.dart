import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/ml_service.dart';
import 'package:repforge/services/utils/exercise_history.dart';
import 'package:repforge/services/fitify_workout_import.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/models/health_connect_workout.dart';
import 'test_utils/mock_storage_service.dart';
import 'fitify_workout_import_test.dart' show sourceWorkout;

class FailingImportStorage extends MockStorageService {
  bool fail = false;
  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {
    if (fail) throw StateError('disk full');
    await super.saveWorkoutSession(session);
  }
}

void main() {
  late FailingImportStorage storage;
  late WorkoutProvider provider;
  late HistoryManager history;
  setUp(() async {
    storage = FailingImportStorage();
    history = HistoryManager(storage);
    provider = WorkoutProvider(
      storage,
      historyManager: history,
      programManager: ProgramManager(storage),
    );
    await provider.init();
  });
  tearDown(() => provider.dispose());
  test(
    'import is restart-safe, idempotent and refreshes history and recovery',
    () async {
      expect((await provider.importFitifyWorkouts([sourceWorkout()])).added, 1);
      expect(provider.sessions.length, 1);
      expect(history.sessions.length, 1);
      expect(
        provider.getMuscleTrainingExposure(since: DateTime(2020))['chest'],
        greaterThan(0),
      );
      expect(provider.sessions.single.totalVolume, 0);
      expect(
        MLService().lastTrainedPerMuscle(provider.sessions, {
          for (final e in provider.allExercises) e.id: e,
        }),
        contains('chest'),
      );
      expect(comparableExerciseLogs('push_ups', provider.sessions), isEmpty);
      await provider.loadAllData();
      expect(
        (await provider.importFitifyWorkouts([sourceWorkout()])).current,
        1,
      );
      expect(provider.sessions.length, 1);
      expect(
        (await provider.importFitifyWorkouts([
          sourceWorkout(version: 2),
        ])).updated,
        1,
      );
    },
  );
  test(
    'source updates keep local edits and unresolved records never become partial sessions',
    () async {
      await provider.importFitifyWorkouts([sourceWorkout()]);
      await provider.updateWorkoutSession(
        provider.sessions.single.copyWith(notes: 'Dad edited this'),
      );
      final report = await provider.importFitifyWorkouts([
        sourceWorkout(version: 2),
        sourceWorkout(code: 'unknown_code'),
      ]);
      expect(report.issues.length, 2);
      expect(provider.sessions.single.notes, 'Dad edited this');
    },
  );
  test(
    'failed storage write is retryable and concurrent imports do not duplicate',
    () async {
      storage.fail = true;
      expect(
        (await provider.importFitifyWorkouts([sourceWorkout()])).issues.length,
        1,
      );
      expect(provider.sessions, isEmpty);
      storage.fail = false;
      final results = await Future.wait([
        provider.importFitifyWorkouts([sourceWorkout()]),
        provider.importFitifyWorkouts([sourceWorkout()]),
      ]);
      expect(results.fold(0, (n, r) => n + r.added), 1);
      expect(provider.sessions.length, 1);
    },
  );
  test(
    'same source version and different HC ID retain stable local identity',
    () async {
      final first = sourceWorkout();
      final recreated = HealthConnectWorkout(
        recordId: 'new-hc-id',
        origin: first.origin,
        start: first.start,
        end: first.end,
        segments: first.segments,
        clientRecordId: first.clientRecordId,
        version: first.version,
        notes: first.notes,
        title: first.title,
      );
      expect(
        FitifyWorkoutImport.localId(first),
        FitifyWorkoutImport.localId(recreated),
      );
    },
  );
  test('source updates protect a locally assigned routine', () async {
    await provider.importFitifyWorkouts([sourceWorkout()]);
    await provider.updateWorkoutSession(
      provider.sessions.single.copyWith(routineId: 'dads-routine'),
    );
    final report = await provider.importFitifyWorkouts([
      sourceWorkout(version: 2),
    ]);
    expect(report.issues.length, 1);
    expect(provider.sessions.single.routineId, 'dads-routine');
  });
}
