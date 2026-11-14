import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/widgets/analytics_overview.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

WorkoutSet hold(
  int seconds, {
  WorkoutLoadMode mode = WorkoutLoadMode.unknown,
}) => WorkoutSet(weight: 0, reps: 0, timeTaken: seconds, loadMode: mode);

void main() {
  test(
    'timed work counts only positive timed sets, not rest or rep-set durations',
    () {
      final session = WorkoutSession(
        id: 's',
        date: DateTime.now(),
        duration: 90,
        exercises: [
          ExerciseLog(
            exerciseId: 'plank',
            sets: [hold(30), hold(60), hold(0), hold(-5)],
          ),
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [WorkoutSet(weight: 20, reps: 10, timeTaken: 120)],
          ),
        ],
      );
      expect(session.timedWorkSeconds, 90);
    },
  );

  test(
    'duration progression includes unknown loads and repeated circuit entries',
    () async {
      final storage = MockStorageService();
      storage.addMockSession(
        WorkoutSession(
          id: 's1',
          date: DateTime(2026, 11, 1),
          duration: 20,
          exercises: [
            ExerciseLog(
              exerciseId: 'plank',
              sets: [hold(20, mode: WorkoutLoadMode.external)],
            ),
          ],
        ),
      );
      storage.addMockSession(
        WorkoutSession(
          id: 's2',
          date: DateTime(2026, 11, 2),
          duration: 30,
          exercises: [
            ExerciseLog(exerciseId: 'plank', sets: [hold(30)]),
            ExerciseLog(exerciseId: 'plank', sets: [hold(45)]),
          ],
        ),
      );
      final p = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await p.init();
      final rows = p.getSetProgression('plank', duration: true);
      expect(
        rows.map((r) => r.sets.fold(0, (sum, s) => sum + (s.timeTaken ?? 0))),
        [20, 75],
      );
      expect(p.getVolumeProgression('plank').map((r) => r.date), [
        DateTime(2026, 11, 1),
      ]);
      expect(p.tracksDuration('plank'), isTrue);
      expect(p.prefersTimedWork, isTrue);
      p.dispose();
    },
  );

  testWidgets(
    'timed-only overview defaults to actual minutes and can switch metrics',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MockStorageService();
      storage.addMockSession(
        WorkoutSession(
          id: 'today',
          date: DateTime.now(),
          duration: 90,
          exercises: [
            ExerciseLog(
              exerciseId: 'plank',
              sets: [hold(30), hold(60), hold(30)],
            ),
          ],
        ),
      );
      final p = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await p.init();
      final settings = SettingsProvider(storage);
      await settings.init();
      await settings.setWeightUnit(WeightUnit.lbs);
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
      expect(find.text('Timed Work Trend'), findsOneWidget);
      expect(find.text('min · per week'), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart).first);
      expect(chart.data.lineBarsData.single.spots.last.y, 2);
      expect(find.text('2.0 min in this period'), findsOneWidget);
      await tester.tap(find.text('Load volume'));
      await tester.pumpAndSettle();
      expect(find.text('Volume Trend'), findsOneWidget);
      await tester.tap(find.text('Timed work'));
      await tester.pumpAndSettle();
      expect(find.text('Timed Work Trend'), findsOneWidget);
      p.dispose();
      settings.dispose();
    },
  );
}
