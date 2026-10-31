import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/home_training_cards.dart';
import 'package:repforge/screens/widgets/rf_widgets.dart';
import 'package:repforge/theme/app_theme.dart';

import '../../test_utils/test_harness.dart';

void main() {
  testWidgets(
    'zero-volume muscles keep empty progress and readable semantics',
    (tester) async {
      await tester.pumpWidget(
        TestHarness.wrap(
          const WeeklyMuscleVolumeCard(
            volumes: {'chest': 0, 'triceps': 0},
            unitLabel: 'kg',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fills = tester.widgetList<FractionallySizedBox>(
        find.descendant(
          of: find.byType(RFProgressBar),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(fills, hasLength(2));
      expect(fills.every((fill) => fill.widthFactor == 0), isTrue);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.value == '0%',
        ),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final value in [double.nan, double.infinity, double.negativeInfinity]) {
    testWidgets(
      'invalid progress $value renders empty without misleading percentages',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: RFProgressBar(value: value)),
          ),
        );
        expect(
          tester
              .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
              .widthFactor,
          0,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.value == '0%',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'streak card retains day status and resume action after extraction',
    (tester) async {
      var resumed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: TrainingStreakCard(
              streak: 2,
              weekStart: DateTime(2026, 10, 26),
              todayIndex: 1,
              workoutDays: const [
                true,
                true,
                false,
                false,
                false,
                false,
                false,
              ],
              isActive: true,
              onStart: () => resumed = true,
            ),
          ),
        ),
      );
      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsNWidgets(2));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.contains('workout logged, today') ??
                  false),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Resume workout'));
      expect(resumed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
