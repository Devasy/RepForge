import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/exercise_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/utils/exercise_history.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';
import 'fitify_workout_import_test.dart' show sourceWorkout;
import 'fitify_import_widget_test.dart' show ImportReader;
import 'package:repforge/screens/widgets/health_workout_import_card.dart';

class ReviewStorage extends MockStorageService {
  bool failHistory = false;
  Completer<void>? readStarted, releaseRead;
  @override
  Future<List<WorkoutSession>> getAllWorkoutSessions() async {
    if (failHistory) throw StateError('history unavailable');
    return super.getAllWorkoutSessions();
  }

  @override
  Future<WorkoutSession?> getWorkoutSession(String id) async {
    final captured = await super.getWorkoutSession(id);
    if (readStarted != null) {
      readStarted!.complete();
      await releaseRead!.future;
      readStarted = null;
    }
    return captured;
  }
}

void main() {
  late ReviewStorage storage;
  late WorkoutProvider provider;
  late HistoryManager history;
  setUp(() async {
    storage = ReviewStorage();
    history = HistoryManager(storage);
    provider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      historyManager: history,
      programManager: ProgramManager(storage),
    );
    await provider.init();
  });
  tearDown(() => provider.dispose());

  test(
    'rename and unchanged primary preserve precise resistance and secondaries',
    () async {
      const exercise = Exercise(
        id: 'custom_precise',
        name: 'Precise',
        category: 'other',
        isCustom: true,
        resistanceIntensities: {'chest': 9.55, 'triceps': 4.25},
        resistanceIntensityOverride: true,
      );
      storage.addMockCustomExercise(exercise);
      await provider.loadAllData();
      final updated = await provider.updateExercise(
        id: exercise.id,
        name: 'Renamed',
      );
      expect(updated.resistanceIntensities, exercise.resistanceIntensities);
      final manager = ExerciseManager(storage);
      await manager.loadExercises();
      final edited = await manager.updateExercise(
        id: exercise.id,
        name: 'Another name',
        primaryMuscleGroupId: 'chest',
      );
      expect(edited.resistanceIntensities, exercise.resistanceIntensities);
      manager.dispose();
    },
  );
  test(
    'new exercises require resistance or stretch while stretch-only stays valid',
    () async {
      expect(
        () => provider.addCustomExercise(
          name: 'Empty',
          category: 'other',
          primaryMuscleGroupId: 'chest',
          resistanceIntensities: {},
        ),
        throwsArgumentError,
      );
      final manager = ExerciseManager(storage);
      await manager.loadExercises();
      expect(
        () => manager.addCustomExercise(
          name: 'Empty',
          category: 'other',
          primaryMuscleGroupId: 'chest',
          resistanceIntensities: {},
        ),
        throwsArgumentError,
      );
      await provider.addCustomExercise(
        name: 'Stretch',
        category: 'other',
        primaryMuscleGroupId: 'hamstrings',
        resistanceIntensities: {},
        stretchIntensities: {'hamstrings': 5},
      );
      expect(provider.allExercises.last.stretchIntensities, {'hamstrings': 5});
      manager.dispose();
    },
  );
  test('load history keeps known sets from a mixed-load log', () {
    final known = WorkoutSet(weight: 40, reps: 8);
    final session = WorkoutSession(
      id: 'mixed',
      date: DateTime(2026),
      duration: 10,
      exercises: [
        ExerciseLog(
          exerciseId: 'bench_press',
          sets: [
            known,
            WorkoutSet(weight: 0, reps: 10, loadMode: WorkoutLoadMode.unknown),
          ],
        ),
      ],
    );
    final logs = comparableExerciseLogs('bench_press', [session]);
    expect(logs.single.log.sets, [known]);
    expect(latestLoadReferences([session])['bench_press'], same(known));
    expect(session.exercises.single.sets.length, 2);
  });
  test('a local edit queued during import survives the import save', () async {
    await provider.importHealthWorkouts([sourceWorkout()]);
    final edited = provider.sessions.single.copyWith(notes: 'Dad edited this');
    storage.readStarted = Completer<void>();
    storage.releaseRead = Completer<void>();
    final importing = provider.importHealthWorkouts([
      sourceWorkout(version: 2),
    ]);
    await storage.readStarted!.future;
    final editing = provider.updateWorkoutSession(edited);
    await Future<void>.delayed(Duration.zero);
    storage.releaseRead!.complete();
    await Future.wait([importing, editing]);
    expect(provider.sessions.single.notes, 'Dad edited this');
    expect(provider.sessions.single.importSource!['version'], 2);
  });
  test(
    'committed import retains counts and can retry failed history refresh',
    () async {
      storage.failHistory = true;
      final report = await provider.importHealthWorkouts([sourceWorkout()]);
      expect(report.added, 1);
      expect(provider.sessions.length, 1);
      expect(provider.hasPendingImportRefresh, isTrue);
      storage.failHistory = false;
      expect(await provider.retryImportedWorkoutRefresh(), isTrue);
      expect(history.sessions.length, 1);
      expect(provider.hasPendingImportRefresh, isFalse);
      expect(
        (await provider.importHealthWorkouts([sourceWorkout()])).current,
        1,
      );
    },
  );
  test(
    'bodyweight drill-down and charts use the same exposure measure',
    () async {
      await provider.importHealthWorkouts([sourceWorkout()]);
      await provider.updateWorkoutSession(
        provider.sessions.single.copyWith(
          date: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      final expected = provider.getMuscleTrainingExposure()['chest']!;
      expect(expected, greaterThan(0));
      expect(
        provider
            .getMuscleExerciseBreakdown('chest', exposure: true)
            .single
            .volume,
        expected,
      );
      expect(
        provider
            .getRecentMuscleSessionSummaries('chest', exposure: true)
            .single
            .volume,
        expected,
      );
      expect(
        provider
            .getMuscleWeeklyVolumeSeries('chest', exposure: true)
            .fold(0.0, (sum, p) => sum + p.volume),
        expected,
      );
      expect(provider.getMuscleExerciseBreakdown('chest').single.volume, 0);
    },
  );
  testWidgets(
    'refresh retry remains available after reopening and rereading imports',
    (tester) async {
      storage.failHistory = true;
      await provider.importHealthWorkouts([sourceWorkout()]);
      final reader = ImportReader();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HealthWorkoutImportCard(reader: reader),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Refresh imported workouts'), findsOneWidget);
      await tester.ensureVisible(find.text('Read workouts'));
      await tester.tap(find.text('Read workouts'));
      await tester.pumpAndSettle();
      expect(find.text('Refresh imported workouts'), findsOneWidget);
      storage.failHistory = false;
      await tester.tap(find.text('Refresh imported workouts'));
      await tester.pumpAndSettle();
      expect(provider.hasPendingImportRefresh, isFalse);
      expect(history.sessions.length, 1);
    },
  );
}
