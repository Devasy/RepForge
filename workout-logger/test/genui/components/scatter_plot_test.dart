import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';
import 'package:repforge/genui/src/components/scatter_plot.dart';

ScatterPlotProps parse(Map<String, Object?> props) => const ScatterPlotSpec()
    .parseProps(A2UiNode(name: 'ScatterPlot', props: A2UiProps(props)));

Future<void> pump(WidgetTester tester, Map<String, Object?> props) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: Builder(
            builder: (context) => const ScatterPlotSpec().render(
              context,
              A2UiNode(name: 'ScatterPlot', props: A2UiProps(props)),
              A2UiTheme.dark,
            ),
          ),
        ),
      ),
    ));

void main() {
  group('ScatterPlotProps parsing', () {
    test('reads the happy path', () {
      final p = parse({
        'title': 'Sleep vs Volume',
        'xLabel': 'Sleep Hours',
        'yLabel': 'Volume',
        'correlation': 0.82,
        'points': [
          {'x': 7.5, 'y': 1600},
          {'x': 6.0, 'y': 1200},
        ],
      });
      expect(p.title, 'Sleep vs Volume');
      expect(p.xLabel, 'Sleep Hours');
      expect(p.points, hasLength(2));
      expect(p.correlation, 0.82);
    });

    test('coerces stringified coordinates', () {
      final p = parse({
        'points': [
          {'x': '7.5', 'y': '1600'}
        ]
      });
      expect(p.points.single.x, 7.5);
      expect(p.points.single.y, 1600);
    });

    test('drops points missing a coordinate instead of throwing', () {
      final p = parse({
        'points': [
          {'x': 1, 'y': 2},
          {'x': 3},
          {'y': 4},
          {'x': 'abc', 'y': 5},
          'garbage',
        ],
      });
      expect(p.points, hasLength(1));
    });

    test('resolves the x_label snake_case alias', () {
      expect(parse({'x_label': 'Sleep'}).xLabel, 'Sleep');
      expect(parse({'y_label': 'Volume'}).yLabel, 'Volume');
    });

    test('falls back to X and Y axis labels', () {
      final p = parse({});
      expect(p.xLabel, 'X');
      expect(p.yLabel, 'Y');
      expect(p.title, 'Scatter Plot');
    });

    test('nulls an unparseable correlation', () {
      expect(parse({'correlation': 'strong'}).correlation, isNull);
      expect(parse({}).correlation, isNull);
      expect(parse({'r': -0.4}).correlation, -0.4);
    });

    test('never throws on hostile input', () {
      expect(() => parse({'points': 5, 'correlation': []}), returnsNormally);
    });
  });

  group('ScatterPlotProps bounds', () {
    test('widens a degenerate axis so the span is never zero', () {
      final b = parse({
        'points': [
          {'x': 5, 'y': 5}
        ]
      }).bounds;
      expect(b.maxX - b.minX, greaterThan(0));
      expect(b.maxY - b.minY, greaterThan(0));
    });

    test('adds a margin around a real spread', () {
      final b = parse({
        'points': [
          {'x': 0, 'y': 0},
          {'x': 10, 'y': 100},
        ],
      }).bounds;
      expect(b.minX, lessThanOrEqualTo(0));
      expect(b.maxX, greaterThanOrEqualTo(10));
      expect(b.minY, lessThanOrEqualTo(0));
      expect(b.maxY, greaterThanOrEqualTo(100));
    });
  });

  group('ScatterPlot rendering', () {
    testWidgets('renders the chart, axis caption and correlation badge',
        (tester) async {
      await pump(tester, {
        'title': 'Sleep vs Volume',
        'xLabel': 'Sleep',
        'yLabel': 'Volume',
        'correlation': 0.82,
        'points': [
          {'x': 1, 'y': 2},
          {'x': 3, 'y': 4},
        ],
      });
      expect(find.byType(ScatterChart), findsOneWidget);
      expect(find.text('Sleep vs Volume'), findsOneWidget);
      expect(find.text('Volume vs. Sleep'), findsOneWidget);
      expect(find.text('r = +0.82'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('formats a negative correlation without a plus sign',
        (tester) async {
      await pump(tester, {
        'correlation': -0.35,
        'points': [
          {'x': 1, 'y': 2}
        ],
      });
      expect(find.text('r = -0.35'), findsOneWidget);
    });

    testWidgets('renders an empty panel with no usable points', (tester) async {
      await pump(tester, {'title': 'Sleep vs Volume', 'points': []});
      expect(find.textContaining('No paired data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ScatterPlotSpec doc', () {
    test('example payload is renderable', () {
      final props = const ScatterPlotSpec().doc.example['props']!
          as Map<String, Object?>;
      expect(parse(props).points, isNotEmpty);
    });
  });
}
