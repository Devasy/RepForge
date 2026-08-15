import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';
import 'package:repforge/genui/src/components/radar_chart.dart';

RadarChartProps parse(Map<String, Object?> props) => const RadarChartSpec()
    .parseProps(A2UiNode(name: 'RadarChart', props: A2UiProps(props)));

Future<void> pump(WidgetTester tester, Map<String, Object?> props) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: Builder(
            builder: (context) => const RadarChartSpec().render(
              context,
              A2UiNode(name: 'RadarChart', props: A2UiProps(props)),
              A2UiTheme.dark,
            ),
          ),
        ),
      ),
    ));

const _fourAxes = ['Readiness', 'Sleep', 'Volume', 'Intensity'];

void main() {
  group('RadarChartProps parsing', () {
    test('reads the legacy axes key', () {
      final p = parse({
        'title': 'Recovery',
        'axes': _fourAxes,
        'series': [
          {'name': 'Current', 'values': [85, 90, 75, 80]}
        ],
      });
      expect(p.labels, _fourAxes);
      expect(p.series.single.values, [85.0, 90.0, 75.0, 80.0]);
      expect(p.hasData, isTrue);
    });

    test('reads the labels key identically', () {
      expect(
        parse({
          'labels': _fourAxes,
          'series': [
            {'name': 'Current', 'values': [1, 2, 3, 4]}
          ],
        }).labels,
        _fourAxes,
      );
    });

    test('zero-pads a series shorter than the axis count', () {
      final p = parse({
        'axes': _fourAxes,
        'series': [
          {'name': 'Short', 'values': [1, 2]}
        ],
      });
      expect(p.series.single.values, [1.0, 2.0, 0.0, 0.0]);
    });

    test('truncates a series longer than the axis count', () {
      final p = parse({
        'axes': _fourAxes,
        'series': [
          {'name': 'Long', 'values': [1, 2, 3, 4, 5, 6]}
        ],
      });
      expect(p.series.single.values, [1.0, 2.0, 3.0, 4.0]);
    });

    test('coerces stringified values', () {
      final p = parse({
        'axes': _fourAxes,
        'series': [
          {'name': 'S', 'values': ['85', 90, '75', 80]}
        ],
      });
      expect(p.series.single.values, [85.0, 90.0, 75.0, 80.0]);
    });

    test('names an unnamed series positionally', () {
      final p = parse({
        'axes': _fourAxes,
        'series': [
          {'values': [1, 2, 3, 4]}
        ],
      });
      expect(p.series.single.name, 'Series 1');
    });

    test('hasData is false with fewer than three axes or no series', () {
      expect(parse({'axes': ['A', 'B'], 'series': [
        {'name': 'S', 'values': [1, 2]}
      ]}).hasData, isFalse);
      expect(parse({'axes': _fourAxes}).hasData, isFalse);
      expect(parse({}).hasData, isFalse);
    });

    test('never throws on hostile input', () {
      expect(
        () => parse({'axes': 5, 'series': ['junk', 7], 'title': []}),
        returnsNormally,
      );
    });
  });

  group('RadarChart rendering', () {
    testWidgets('renders the chart and a multi-series legend', (tester) async {
      await pump(tester, {
        'title': 'Recovery',
        'axes': _fourAxes,
        'series': [
          {'name': 'Current', 'values': [85, 90, 75, 80]},
          {'name': 'Baseline', 'values': [70, 70, 70, 70]},
        ],
      });
      expect(find.byType(RadarChart), findsOneWidget);
      expect(find.text('Recovery'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Baseline'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides the legend for a single series', (tester) async {
      await pump(tester, {
        'axes': _fourAxes,
        'series': [
          {'name': 'Current', 'values': [1, 2, 3, 4]}
        ],
      });
      expect(find.text('Current'), findsNothing);
    });

    testWidgets('renders an empty panel when there is nothing to plot',
        (tester) async {
      await pump(tester, {'title': 'Recovery', 'axes': ['A', 'B']});
      expect(find.textContaining('No radar data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('RadarChartSpec doc', () {
    test('example payload is renderable', () {
      final props =
          const RadarChartSpec().doc.example['props']! as Map<String, Object?>;
      expect(parse(props).hasData, isTrue);
    });
  });
}
