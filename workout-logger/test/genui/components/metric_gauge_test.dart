import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';
import 'package:repforge/genui/src/components/metric_gauge.dart';

MetricGaugeProps parse(Map<String, Object?> props) => const MetricGaugeSpec()
    .parseProps(A2UiNode(name: 'MetricGauge', props: A2UiProps(props)));

Future<void> pump(WidgetTester tester, Map<String, Object?> props) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => const MetricGaugeSpec().render(
            context,
            A2UiNode(name: 'MetricGauge', props: A2UiProps(props)),
            A2UiTheme.dark,
          ),
        ),
      ),
    ));

void main() {
  group('MetricGaugeProps parsing', () {
    test('reads the happy path', () {
      final p = parse({
        'title': 'Readiness',
        'value': 88,
        'min': 0,
        'max': 100,
        'unit': '/ 100',
        'status': 'Optimal',
      });
      expect(p.title, 'Readiness');
      expect(p.value, 88);
      expect(p.progress, closeTo(0.88, 0.001));
      expect(p.status, 'Optimal');
    });

    test('accepts a numeric string value — the old validator/renderer mismatch',
        () {
      expect(parse({'value': '88'}).value, 88);
      expect(parse({'value': '88.5'}).value, 88.5);
    });

    test('yields a null value for missing or unparseable input', () {
      expect(parse({}).value, isNull);
      expect(parse({'value': 'optimal'}).value, isNull);
      expect(parse({'value': []}).value, isNull);
    });

    test('defaults min to 0 and max to 100', () {
      final p = parse({'value': 50});
      expect(p.min, 0);
      expect(p.max, 100);
      expect(p.progress, closeTo(0.5, 0.001));
    });

    test('returns 0 progress when max <= min instead of NaN', () {
      final same = parse({'value': 5, 'min': 5, 'max': 5});
      expect(same.progress, 0);
      expect(same.progress.isNaN, isFalse);

      final inverted = parse({'value': 5, 'min': 10, 'max': 2});
      expect(inverted.progress, 0);
    });

    test('clamps progress into [0, 1]', () {
      expect(parse({'value': 500, 'max': 100}).progress, 1);
      expect(parse({'value': -20, 'min': 0, 'max': 100}).progress, 0);
    });

    test('never throws on hostile input', () {
      expect(
        () => parse({'value': {}, 'min': [], 'max': 'x', 'unit': 5}),
        returnsNormally,
      );
    });
  });

  group('MetricGauge rendering', () {
    testWidgets('renders the value, unit and status', (tester) async {
      await pump(tester, {
        'title': 'Readiness',
        'value': 88,
        'unit': 'pts',
        'status': 'Optimal',
      });
      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('pts'), findsOneWidget);
      expect(find.text('Optimal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an empty panel when the value is unusable',
        (tester) async {
      await pump(tester, {'title': 'Readiness', 'value': 'unknown'});
      expect(find.textContaining('No value'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a whole number without a trailing .0', (tester) async {
      await pump(tester, {'value': 88.0});
      expect(find.text('88'), findsOneWidget);
    });
  });

  group('MetricGaugeSpec doc', () {
    test('example payload produces a renderable value', () {
      final props =
          const MetricGaugeSpec().doc.example['props']! as Map<String, Object?>;
      expect(parse(props).value, isNotNull);
    });
  });
}
