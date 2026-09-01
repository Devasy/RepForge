import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/screens/workout_flow_screen.dart';
import '../test_utils/test_harness.dart';

void main() {
  testWidgets('Renders WorkoutFlowScreen with active exercise details', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final routine = Routine(
      id: 'chest_day',
      name: 'Chest & Triceps',
      exerciseIds: ['bench_press', 'incline_dumbbells'],
    );

    await tester.pumpWidget(TestHarness.wrap(
      WorkoutFlowScreen(routine: routine),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(WorkoutFlowScreen), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('Renders WorkoutFlowScreen quick start mode', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    await tester.pumpWidget(TestHarness.wrap(
      const WorkoutFlowScreen(isQuickStart: true),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(WorkoutFlowScreen), findsOneWidget);
    // Quick-start mode has no pre-set routine: the Add Exercise control is shown.
    expect(
      find.byIcon(Icons.add_rounded).evaluate().isNotEmpty ||
          find.textContaining('Exercise').evaluate().isNotEmpty,
      isTrue,
      reason: 'Quick-start mode should show an add-exercise control or empty exercise area',
    );
  });
}
