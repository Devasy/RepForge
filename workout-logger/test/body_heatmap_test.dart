import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/body_heatmap.dart';

void main() {
  testWidgets('all figures and views render and expose working muscle actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final figure in BodyFigure.values) {
      for (final view in BodyView.values) {
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BodyHeatmapWidget(
                width: 300,
                height: 600,
                figure: figure,
                view: view,
                muscleVolumes: const {'lats': 1, 'core': .5, 'rear_delts': .8},
                onMuscleTap: (id) => selected = id,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final painter = tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(BodyHeatmapWidget),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!;
        final nodes = painter.semanticsBuilder!(const Size(300, 600));
        final wanted = view == BodyView.front ? 'Core' : 'Lats';
        final node = nodes.firstWhere(
          (n) => n.properties.label == '$wanted, ${view.name}',
        );
        node.properties.onTap!();
        expect(selected, view == BodyView.front ? 'core' : 'lats');
        // Tap the center of the left pectoral using the same contain transform.
        if (figure == BodyFigure.male && view == BodyView.front) {
          final scale = 300 / 727;
          await tester.tapAt(
            tester.getTopLeft(find.byType(BodyHeatmapWidget)) +
                Offset(
                  310 * scale,
                  (600 - 1280 * scale) / 2 + (375 - 95) * scale,
                ),
          );
          expect(selected, 'chest');
        }
      }
    }
    semantics.dispose();
  });

  testWidgets(
    'detailed map fits a narrow phone and supports female view and exact groups',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 280,
                child: MuscleBodyMap(onMuscleTap: (id) => selected = id),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Front'), findsOneWidget);
      expect(find.text('Back'), findsNWidgets(2));
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<BodyHeatmapWidget>(find.byType(BodyHeatmapWidget))
            .every((w) => w.figure == BodyFigure.female),
        isTrue,
      );
      await tester.ensureVisible(find.text('Rear Delts'));
      await tester.tap(find.text('Rear Delts'));
      expect(selected, 'rear_delts');
      expect(tester.takeException(), isNull);
    },
  );
}
