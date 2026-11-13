import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/analytics_overview.dart';
import 'package:repforge/screens/widgets/body_heatmap.dart';
import 'package:repforge/services/ml_service.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

class RecoveryMl extends MockMLService {
  @override
  Map<String, MuscleRecoveryStatus> computeMuscleRecoveryScores(
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap, {
    DateTime? asOf,
  }) => const RecoveryCalculator().computeMuscleRecoveryScores(
    sessions,
    exerciseMap,
    asOf: asOf,
  );
}

void main() {
  test(
    'calendar-week aggregates include Monday and exclude Sunday and future records',
    () async {
      final storage = MockStorageService();
      storage.addMockCustomExercise(
        Exercise(
          id: 'timed',
          name: 'Timed work',
          category: 'core',
          isCustom: true,
          exerciseType: ExerciseType.timeBased,
          resistanceIntensities: {'abs': 10},
        ),
      );
      storage.addMockCustomExercise(
        Exercise(
          id: 'weighted',
          name: 'Loaded work',
          category: 'compound',
          isCustom: true,
          resistanceIntensities: {'chest': 10},
        ),
      );
      void add(String id, DateTime date, String exercise, WorkoutSet set) =>
          storage.addMockSession(
            WorkoutSession(
              id: id,
              date: date,
              duration: 10,
              exercises: [
                ExerciseLog(exerciseId: exercise, sets: [set]),
              ],
            ),
          );
      WorkoutSet timed() => WorkoutSet(
        weight: 0,
        reps: 0,
        timeTaken: 30,
        loadMode: WorkoutLoadMode.unknown,
      );
      add('sunday', DateTime(2026, 11, 8, 23, 59, 59), 'timed', timed());
      add('monday', DateTime(2026, 11, 9), 'timed', timed());
      add('friday', DateTime(2026, 11, 13, 11), 'timed', timed());
      add('future', DateTime(2026, 11, 13, 13), 'timed', timed());
      add(
        'old-load',
        DateTime(2026, 11, 8, 23, 59),
        'weighted',
        WorkoutSet(weight: 100, reps: 10),
      );
      add(
        'current-load',
        DateTime(2026, 11, 9),
        'weighted',
        WorkoutSet(weight: 50, reps: 10),
      );
      add(
        'future-load',
        DateTime(2026, 11, 13, 13),
        'weighted',
        WorkoutSet(weight: 200, reps: 10),
      );
      final p = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await p.init();
      final now = DateTime(2026, 11, 13, 12);
      expect(WorkoutProvider.weekStartFor(now), DateTime(2026, 11, 9));
      expect(p.getMuscleTrainingExposure(asOf: now), {
        'abs': 2.0,
        'chest': 1.0,
      });
      expect(p.getWeeklyVolumeByMuscle(asOf: now)['chest'], 500);
      expect(
        p
            .getMuscleExerciseBreakdown('abs', end: now, exposure: true)
            .single
            .volume,
        2,
      );
      expect(
        p.hasUnknownLoadsSince(DateTime(2026, 11, 13, 12), asOf: now),
        isFalse,
      );
      p.dispose();
    },
  );
  for (final mode in [WorkoutLoadMode.unknown, WorkoutLoadMode.external]) {
    testWidgets('rest week stays neutral after last Sunday (${mode.name})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final storage = MockStorageService();
      storage.addMockSession(
        WorkoutSession(
          id: 'last-week',
          date: DateTime(now.year, now.month, now.day - now.weekday, 12),
          duration: 20,
          exercises: [
            ExerciseLog(
              exerciseId: 'plank',
              sets: [
                WorkoutSet(weight: 0, reps: 0, timeTaken: 30, loadMode: mode),
              ],
            ),
          ],
        ),
      );
      final p = WorkoutProvider(
        storage,
        mlService: RecoveryMl(),
        programManager: ProgramManager(storage),
      );
      await p.init();
      final settings = SettingsProvider(storage);
      await settings.init();
      expect(p.getMuscleRecoveryScores(), isNotEmpty);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: p),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AnalyticsOverviewTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = tester.widget<MuscleBodyMap>(find.byType(MuscleBodyMap));
      expect(map.muscleVolumes, isEmpty);
      expect(
        find.textContaining('No training logged this week'),
        findsOneWidget,
      );
      p.dispose();
      settings.dispose();
    });
  }
}
