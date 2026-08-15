import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/a2ui.dart';

final _parser = A2UiParser(defaultA2UiRegistry);

/// Every payload here is something a weak model plausibly emits. None may
/// throw; each either renders or is cleanly rejected as prose.
const _payloads = <String>[
  // Well-formed.
  '{"component":"StatCard","props":{"title":"Volume","value":12000,"unit":"kg","trend":"improving"}}',
  // Flat, no props wrapper.
  '{"component":"StatCard","title":"Volume","value":"12k"}',
  // Snake-case component and props.
  '{"component":"stat_card","props":{"title":"V","value":1}}',
  // Fenced.
  '```json\n{"component":"MetricGauge","props":{"title":"R","value":"82"}}\n```',
  // Prose wrapper.
  'Sure!\n{"component":"FilterChips","props":{"options":["7d","30d"]}}\nHope that helps.',
  // Bare array.
  '[{"component":"StatCard","title":"A","value":1},{"component":"StatCard","title":"B","value":2}]',
  // Envelope key.
  '{"components":[{"component":"StatCard","title":"A","value":1}]}',
  // Legacy radar with axes.
  '{"component":"RadarChart","props":{"title":"R","axes":["A","B","C"],"series":[{"name":"S","values":[1,2,3]}]}}',
  // Radar with mismatched series length.
  '{"component":"RadarChart","props":{"labels":["A","B","C","D"],"series":[{"name":"S","values":[1,2]}]}}',
  // Numbers as strings throughout.
  '{"component":"DynamicChart","props":{"type":"bar","title":"T","labels":[1,2],"values":["10","20"]}}',
  // More values than labels.
  '{"component":"DynamicChart","props":{"labels":["A"],"series":[{"name":"S","values":[1,2,3,4]}]}}',
  // Missing every optional prop.
  '{"component":"DynamicChart","props":{"values":[1,2,3]}}',
  // Gauge with a degenerate range.
  '{"component":"MetricGauge","props":{"title":"G","value":5,"min":5,"max":5}}',
  // Gauge with a non-numeric value.
  '{"component":"MetricGauge","props":{"title":"G","value":"optimal"}}',
  // List with a missing title and numeric trailing values.
  '{"component":"DataListGroup","props":{"items":[{"primaryText":"Bench","trailingValue":102.5}]}}',
  // List of bare strings.
  '{"component":"DataListGroup","props":{"title":"T","items":["Bench","Squat"]}}',
  // Chips with no active option.
  '{"component":"FilterChips","props":{"options":["7d","30d"]}}',
  // Scatter with broken points mixed in.
  '{"component":"ScatterPlot","props":{"points":[{"x":1,"y":2},{"x":"a","y":3},{"y":4}]}}',
  // Scatter with a single point.
  '{"component":"ScatterPlot","props":{"points":[{"x":5,"y":5}]}}',
  // Grid with a mix of good and unknown children.
  '{"component":"GridContainer","props":{"columns":2,"children":['
      '{"component":"StatCard","title":"A","value":1},'
      '{"component":"HeroBanner","title":"nope"}]}}',
  // Deeply nested grids.
  '{"component":"GridContainer","children":[{"component":"GridContainer","children":['
      '{"component":"StatCard","title":"A","value":1}]}]}',
  // Grid using "components" as an alias for "children" (regression: Task 13
  // widened the parser's per-node child-key lookup to accept
  // components/elements/content, not just children).
  '{"component":"GridContainer","props":{"components":['
      '{"component":"StatCard","title":"A","value":1}]}}',
  // All-negative DynamicChart values (regression: Task 8 fixed the axis
  // bounds — via A2UiSeries.minValue/_yBounds — so an all-negative series
  // is bracketed instead of silently clamped to a 0-start axis that
  // excludes every real data point).
  '{"component":"DynamicChart","props":{"title":"T","labels":["A","B","C"],"values":[-50,-30,-10]}}',
  // Empty data everywhere.
  '{"component":"DynamicChart","props":{"title":"T","labels":[],"series":[]}}',
  // Hostile types.
  '{"component":"StatCard","props":{"title":[],"value":{},"trend":7}}',
  // Prose only.
  'Great session — your bench is up 5kg since June.',
  // Broken JSON.
  '{"component":"StatCard","props":',
  // Empty.
  '',
];

/// Truncated payload text used as a stable test name, so a failure identifies
/// the payload directly instead of an index that shifts whenever `_payloads`
/// gains or loses an entry.
String _label(String payload) =>
    payload.isEmpty ? '<empty>' : payload.substring(0, payload.length.clamp(0, 60));

void main() {
  group('parser never throws', () {
    for (final payload in _payloads) {
      test(_label(payload), () {
        expect(() => _parser.parse(payload), returnsNormally);
      });
    }
  });

  group('renderer never throws', () {
    for (final payload in _payloads) {
      testWidgets(_label(payload), (tester) async {
        final node = _parser.parse(payload);
        if (node == null) return;

        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: A2UiRenderer(node: node)),
          ),
        ));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('no silent blanks', () {
    testWidgets('a component with no data shows a visible empty panel',
        (tester) async {
      final node = _parser
          .parse('{"component":"DynamicChart","props":{"title":"Volume"}}');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: A2UiRenderer(node: node!)),
      ));
      expect(find.textContaining('No chart data'), findsOneWidget);
    });
  });

  // These two regressions were both SILENT-VISUAL, not throwing — a
  // no-exception check structurally can't catch either, so each gets a
  // positive assertion pinning the actual fixed behavior, not just
  // "didn't crash".
  group('silent-visual regressions stay fixed', () {
    testWidgets(
        'all-negative DynamicChart values render an axis that brackets '
        'the data instead of clamping to a 0-start range (Task 8)',
        (tester) async {
      final node = _parser.parse(
        '{"component":"DynamicChart","props":{"title":"T",'
        '"labels":["A","B","C"],"values":[-50,-30,-10]}}',
      )!;

      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: A2UiRenderer(node: node)),
      ));

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      // The true minimum is -50; a broken axis that clamps at 0 would give
      // minY == 0 and silently drop every point off the visible chart. The
      // axis must actually bracket the real minimum, not just dip below
      // some weak threshold that a partially-broken bound could still clear.
      expect(chart.data.minY, lessThanOrEqualTo(-50));
      expect(chart.data.maxY, greaterThanOrEqualTo(-10));
    });

    test(
        'GridContainer accepts "components" as an alias for "children" '
        'and actually populates the node tree (Task 13)', () {
      final node = _parser.parse(
        '{"component":"GridContainer","props":{"components":['
        '{"component":"StatCard","title":"A","value":1}]}}',
      );

      expect(node, isNotNull);
      // A broken alias lookup would still parse without throwing but leave
      // children empty, silently rendering an empty grid.
      expect(node!.children, isNotEmpty);
      expect(node.children.single.name, 'StatCard');
    });
  });
}
