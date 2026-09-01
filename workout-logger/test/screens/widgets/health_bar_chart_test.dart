import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/sleep_hr_models.dart';
import 'package:repforge/screens/widgets/health_bar_chart.dart';
import '../../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders SleepBarsChart with daily sleep stage data', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final now = DateTime(2026, 5, 10);
    final List<SleepDayBar> bars = [
      SleepDayBar(
        date: now.subtract(const Duration(days: 2)),
        totalMinutes: 480,
        deepMin: 90,
        remMin: 120,
        lightMin: 240,
        awakeMin: 30,
      ),
      SleepDayBar(
        date: now.subtract(const Duration(days: 1)),
        totalMinutes: 395,
        deepMin: 60,
        remMin: 90,
        lightMin: 200,
        awakeMin: 45,
      ),
      SleepDayBar(
        date: now,
        totalMinutes: 0,
        deepMin: 0,
        remMin: 0,
        lightMin: 0,
        awakeMin: 0,
      ),
    ];

    final workoutDays = {'2026-05-08', '2026-05-10'};

    await tester.pumpWidget(TestHarness.wrap(
      SleepBarsChart(
        bars: bars,
        workoutDays: workoutDays,
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(SleepBarsChart), findsOneWidget);

    // Tap on a bar area to trigger tooltip interaction
    await tester.tap(find.byType(SleepBarsChart));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Renders HrRangeChart with heart rate min-max range data', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final now = DateTime(2026, 5, 10);
    final List<HrRangeBar> bars = [
      HrRangeBar(
        date: now.subtract(const Duration(days: 2)),
        label: 'Fri',
        minBpm: 55,
        maxBpm: 145,
        avgBpm: 75.0,
        restingBpm: 58,
      ),
      HrRangeBar(
        date: now.subtract(const Duration(days: 1)),
        label: 'Sat',
        minBpm: 60,
        maxBpm: 165,
        avgBpm: 82.0,
        restingBpm: 62,
      ),
      HrRangeBar(
        date: now,
        label: 'Sun',
        minBpm: 0,
        maxBpm: 0,
        avgBpm: 0.0,
        restingBpm: null,
      ),
    ];

    final workoutDays = {'2026-05-09'};

    await tester.pumpWidget(TestHarness.wrap(
      HrRangeChart(
        bars: bars,
        workoutDays: workoutDays,
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(HrRangeChart), findsOneWidget);

    // Tap on HrRangeChart to test tap gestures
    await tester.tap(find.byType(HrRangeChart));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
