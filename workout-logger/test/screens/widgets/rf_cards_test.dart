import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/rf_cards.dart';
import '../../test_utils/test_fixtures.dart';
import '../../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders SessionCard with exercise details', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final session = TestFixtures.sampleSession();

    await tester.pumpWidget(TestHarness.wrap(
      SessionCard(
        session: session,
        getExerciseName: (id) => id == 'bench_press' ? 'Bench Press' : 'Squats',
        synced: true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('Renders StatGridCard with counter label', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    await tester.pumpWidget(TestHarness.wrap(
      const StatGridCard(
        icon: Icons.fitness_center,
        value: '125 kg',
        label: 'Max Bench',
        animate: false,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Max Bench'), findsOneWidget);
  });

  testWidgets('Renders RecentSessionTile item', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final session = TestFixtures.sampleSession();

    await tester.pumpWidget(TestHarness.wrap(
      RecentSessionTile(
        session: session,
        getExerciseName: (id) => 'Bench Press',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('exercises'), findsOneWidget);
  });

  testWidgets('Renders RoutineCard with action triggers', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final routine = TestFixtures.sampleRoutine();
    bool started = false;

    await tester.pumpWidget(TestHarness.wrap(
      RoutineCard(
        routine: routine,
        getExerciseName: (id) => id,
        onStart: () => started = true,
        onEdit: () {},
        onDelete: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Upper Body Power'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    expect(started, isTrue);
  });
}
