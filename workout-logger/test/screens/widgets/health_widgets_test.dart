import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/sleep_hr_models.dart';
import 'package:repforge/screens/widgets/sleep_hr_charts.dart';
import 'package:repforge/screens/widgets/muscle_detail_sheet.dart';
import 'package:repforge/screens/widgets/health_detail_shell.dart';
import 'package:repforge/screens/widgets/sparkline_painter.dart';
import 'package:repforge/screens/widgets/activity_heatmap.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/mock_ml_service.dart';
import '../../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders SleepHrDayView overnight chart widget', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final snapshot = SleepHrSnapshot(
      sleepStart: DateTime(2026, 5, 10, 0, 0),
      sleepEnd: DateTime(2026, 5, 10, 8, 0),
      p5Bpm: 54,
      p95Bpm: 75,
      segments: [
        SleepHrSegment(
          windowStart: DateTime(2026, 5, 10, 1, 0),
          minBpm: 52,
          maxBpm: 65,
          avgBpm: 58.0,
          stage: 'deep',
        ),
        SleepHrSegment(
          windowStart: DateTime(2026, 5, 10, 3, 0),
          minBpm: 55,
          maxBpm: 70,
          avgBpm: 62.0,
          stage: 'rem',
        ),
      ],
      stageStats: const [
        SleepStageStats(stage: 'deep', minBpm: 52, p25Bpm: 55, avgBpm: 58.0, p75Bpm: 62, maxBpm: 65, sampleCount: 12),
        SleepStageStats(stage: 'rem', minBpm: 55, p25Bpm: 58, avgBpm: 62.0, p75Bpm: 66, maxBpm: 70, sampleCount: 12),
      ],
    );

    await tester.pumpWidget(TestHarness.wrap(
      SleepHrDayView(snapshot: snapshot),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('54 bpm'), findsOneWidget);
  });

  testWidgets('Renders MuscleDetailSheet with muscle breakdown', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final storage = MockStorageService();
    final provider = WorkoutProvider(storage, mlService: MockMLService(), programManager: ProgramManager(storage));
    await provider.init();

    await tester.pumpWidget(TestHarness.wrap(
      MuscleDetailSheet(muscleId: 'chest', provider: provider),
      storage: storage,
      workoutProvider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chest'), findsOneWidget);
  });

  testWidgets('Renders HealthDetailShell container with granularity selection', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    HealthGranularity currentG = HealthGranularity.day;

    await tester.pumpWidget(TestHarness.wrap(
      HealthDetailShell(
        title: 'Sleep History',
        icon: Icons.nightlight_round,
        iconColor: Colors.purple,
        dateLabel: 'May 10, 2026',
        granularity: currentG,
        onGranularityChanged: (g) => currentG = g,
        onPrev: () {},
        onNext: () {},
        canGoNext: false,
        child: const SizedBox(height: 100, child: Text('Child Content')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Sleep History'), findsOneWidget);
    expect(find.text('May 10, 2026'), findsOneWidget);
    expect(find.text('Child Content'), findsOneWidget);
  });

  testWidgets('Renders SparklinePainter canvas', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    await tester.pumpWidget(TestHarness.wrap(
      const CustomPaint(
        size: Size(100, 30),
        painter: SparklinePainter(
          data: [10.0, 15.0, 8.0, 20.0, 25.0],
          color: Colors.blue,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Renders ActivityHeatmap canvas', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final activityData = List.filled(98, 2);

    await tester.pumpWidget(TestHarness.wrap(
      ActivityHeatmap(data: activityData),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityHeatmap), findsOneWidget);
  });
}
