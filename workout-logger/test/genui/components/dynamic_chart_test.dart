import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_panels.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';
import 'package:repforge/genui/src/components/dynamic_chart.dart';

DynamicChartProps parse(Map<String, Object?> props) => const DynamicChartSpec()
    .parseProps(A2UiNode(name: 'DynamicChart', props: A2UiProps(props)));

Future<void> pump(WidgetTester tester, Map<String, Object?> props) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: Builder(
            builder: (context) => const DynamicChartSpec().render(
              context,
              A2UiNode(name: 'DynamicChart', props: A2UiProps(props)),
              A2UiTheme.dark,
            ),
          ),
        ),
      ),
    ));

void main() {
  group('chart type', () {
    test('defaults to line and normalizes spellings', () {
      expect(parse({}).type, A2UiChartType.line);
      expect(parse({'type': 'bar'}).type, A2UiChartType.bar);
      expect(parse({'type': 'PIE'}).type, A2UiChartType.pie);
      expect(parse({'type': 'bar_chart'}).type, A2UiChartType.bar);
      expect(parse({'type': 'LineChart'}).type, A2UiChartType.line);
      expect(parse({'type': 'donut'}).type, A2UiChartType.pie);
      expect(parse({'type': 'nonsense'}).type, A2UiChartType.line);
    });
  });

  group('DynamicChartProps parsing', () {
    test('reads multi-series payloads', () {
      final p = parse({
        'type': 'bar',
        'title': 'Biceps vs Triceps',
        'labels': ['07-06', '07-09'],
        'series': [
          {'name': 'Biceps', 'values': [0, 645]},
          {'name': 'Triceps', 'values': [2390, 0]},
        ],
      });
      expect(p.title, 'Biceps vs Triceps');
      expect(p.series, hasLength(2));
      expect(p.labels, ['07-06', '07-09']);
      expect(p.hasData, isTrue);
    });

    test('reads the single-values shorthand', () {
      final p = parse({
        'title': 'Weekly Sets',
        'labels': ['Mon', 'Wed'],
        'values': [12, 15],
      });
      expect(p.series, hasLength(1));
      expect(p.series.single.name, 'Weekly Sets');
    });

    test('stringifies numeric labels instead of throwing', () {
      expect(parse({'labels': [1, 2, 3], 'values': [1, 2, 3]}).labels,
          ['1', '2', '3']);
    });

    test('stringifies a numeric title', () {
      expect(parse({'title': 2024, 'values': [1]}).title, '2024');
    });

    test('coerces stringified series values', () {
      final p = parse({
        'labels': ['a'],
        'series': [
          {'name': 'S', 'values': ['1.5']}
        ],
      });
      expect(p.series.single.values, [1.5]);
    });

    test('pads labels up to the longest series length', () {
      final p = parse({
        'labels': ['Mon'],
        'series': [
          {'name': 'S', 'values': [1, 2, 3]}
        ],
      });
      expect(p.labels, ['Mon', '', '']);
    });

    test('pads labels using the longest of multiple series, not just the first',
        () {
      final p = parse({
        'labels': ['Mon'],
        'series': [
          {'name': 'Short', 'values': [1, 2]},
          {'name': 'Long', 'values': [1, 2, 3, 4]},
        ],
      });
      expect(p.labels, ['Mon', '', '', '']);
    });

    test('hasData is false when there is nothing to plot', () {
      expect(parse({}).hasData, isFalse);
      expect(parse({'labels': ['a', 'b']}).hasData, isFalse);
      expect(parse({'values': [1, 2]}).hasData, isTrue);
    });

    test('never throws on hostile input', () {
      expect(
        () => parse({
          'labels': 'nope',
          'series': [42, null],
          'values': {},
          'title': [],
        }),
        returnsNormally,
      );
    });
  });

  group('DynamicChart rendering', () {
    testWidgets('renders a line chart', (tester) async {
      await pump(tester, {
        'type': 'line',
        'title': 'Volume',
        'labels': ['A', 'B'],
        'values': [1, 2],
      });
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Volume'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a bar chart', (tester) async {
      await pump(tester, {
        'type': 'bar',
        'labels': ['A', 'B'],
        'values': [1, 2],
      });
      expect(find.byType(BarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a pie chart with a label list', (tester) async {
      await pump(tester, {
        'type': 'pie',
        'labels': ['Chest', 'Back'],
        'values': [60, 40],
      });
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.textContaining('Chest'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'pie chart with mixed-sign values renders only the positive slice',
        (tester) async {
      // Regression test for the fix in DynamicChart._pie: negative/zero
      // values have no geometric meaning in a pie and must be filtered out
      // before building sections, rather than crashing or silently
      // corrupting the percentage math.
      await pump(tester, {
        'type': 'pie',
        'labels': ['Chest', 'Back'],
        'values': [60, -40],
      });
      expect(tester.takeException(), isNull);
      final pieChart = tester.widget<PieChart>(find.byType(PieChart));
      expect(pieChart.data.sections, hasLength(1));
      expect(pieChart.data.sections.single.title, '100%');
    });

    testWidgets('pie chart with all-negative values falls back to the '
        'empty panel instead of throwing', (tester) async {
      await pump(tester, {
        'type': 'pie',
        'labels': ['Chest', 'Back'],
        'values': [-60, -40],
      });
      expect(tester.takeException(), isNull);
      expect(find.byType(PieChart), findsNothing);
      expect(find.textContaining('No positive values to chart'),
          findsOneWidget);
    });

    testWidgets('renders a legend only for multi-series non-pie charts',
        (tester) async {
      await pump(tester, {
        'type': 'line',
        'labels': ['A'],
        'series': [
          {'name': 'Biceps', 'values': [1]},
          {'name': 'Triceps', 'values': [2]},
        ],
      });
      expect(find.text('Biceps'), findsOneWidget);
      expect(find.text('Triceps'), findsOneWidget);
      expect(find.byType(A2UiLegend), findsOneWidget);

      await pump(tester, {
        'type': 'line',
        'labels': ['A'],
        'values': [1],
      });
      expect(find.byType(A2UiLegend), findsNothing);

      await pump(tester, {
        'type': 'pie',
        'labels': ['A', 'B'],
        'series': [
          {'name': 'Biceps', 'values': [1]},
          {'name': 'Triceps', 'values': [2]},
        ],
      });
      expect(find.byType(A2UiLegend), findsNothing);
    });

    testWidgets('renders an empty panel with no data', (tester) async {
      await pump(tester, {'title': 'Volume'});
      expect(find.textContaining('No chart data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives more series values than labels', (tester) async {
      await pump(tester, {
        'type': 'bar',
        'labels': ['A'],
        'series': [
          {'name': 'S', 'values': [1, 2, 3, 4]}
        ],
      });
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives all-zero values without a zero-height axis',
        (tester) async {
      await pump(tester, {'labels': ['A', 'B'], 'values': [0, 0]});
      expect(tester.takeException(), isNull);
    });

    testWidgets('all-negative line chart brackets its data within minY/maxY',
        (tester) async {
      await pump(tester, {
        'type': 'line',
        'labels': ['A', 'B', 'C'],
        'values': [-10, -5, -3],
      });
      expect(tester.takeException(), isNull);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.minY, lessThanOrEqualTo(-10));
      expect(data.maxY, greaterThanOrEqualTo(-3));
      expect(data.minY, lessThan(data.maxY));
    });

    testWidgets('all-negative bar chart brackets its data within minY/maxY',
        (tester) async {
      await pump(tester, {
        'type': 'bar',
        'labels': ['A', 'B', 'C'],
        'values': [-10, -5, -3],
      });
      expect(tester.takeException(), isNull);
      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      expect(data.minY, lessThanOrEqualTo(-10));
      expect(data.maxY, greaterThanOrEqualTo(-3));
      expect(data.minY, lessThan(data.maxY));
    });
  });

  group('DynamicChartSpec doc', () {
    test('example payload is renderable', () {
      final props = const DynamicChartSpec().doc.example['props']!
          as Map<String, Object?>;
      expect(parse(props).hasData, isTrue);
    });
  });
}
