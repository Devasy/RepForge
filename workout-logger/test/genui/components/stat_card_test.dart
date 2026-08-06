import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';
import 'package:repforge/genui/src/components/stat_card.dart';

StatCardProps parse(Map<String, Object?> props) => const StatCardSpec()
    .parseProps(A2UiNode(name: 'StatCard', props: A2UiProps(props)));

Future<void> pump(WidgetTester tester, Map<String, Object?> props) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => const StatCardSpec().render(
          context,
          A2UiNode(name: 'StatCard', props: A2UiProps({})),
          A2UiTheme.dark,
        ),
      ),
    ),
  ));
}

void main() {
  group('StatCardProps parsing', () {
    test('reads the happy path', () {
      final p = parse({
        'title': 'Weekly Volume',
        'value': '12,400 kg',
        'subtitle': 'Last 7 days',
        'trend': 'up',
      });
      expect(p.title, 'Weekly Volume');
      expect(p.value, '12,400 kg');
      expect(p.subtitle, 'Last 7 days');
      expect(p.trend, A2UiTrend.up);
    });

    test('falls back when title and value are missing', () {
      final p = parse({});
      expect(p.title, 'Metric');
      expect(p.value, '—');
      expect(p.subtitle, isNull);
      expect(p.trend, A2UiTrend.neutral);
    });

    test('stringifies a numeric value', () {
      expect(parse({'value': 88}).value, '88');
      expect(parse({'value': 88.5}).value, '88.5');
    });

    test('appends a unit that is not already present', () {
      expect(parse({'value': 88, 'unit': 'kg'}).value, '88 kg');
      expect(parse({'value': '88 kg', 'unit': 'kg'}).value, '88 kg');
    });

    test('accepts loose trend synonyms', () {
      for (final up in ['up', 'improving', 'positive', 'RISING']) {
        expect(parse({'trend': up}).trend, A2UiTrend.up, reason: up);
      }
      for (final down in ['down', 'declining', 'negative', 'falling']) {
        expect(parse({'trend': down}).trend, A2UiTrend.down, reason: down);
      }
      expect(parse({'trend': 'sideways'}).trend, A2UiTrend.neutral);
      expect(parse({'trend': 42}).trend, A2UiTrend.neutral);
    });

    test('resolves aliased keys', () {
      final p = parse({'name': 'Bench', 'val': 100});
      expect(p.title, 'Bench');
      expect(p.value, '100');
    });

    test('never throws on hostile input', () {
      expect(() => parse({'title': [], 'value': {}, 'trend': []}), returnsNormally);
    });
  });

  group('StatCard rendering', () {
    testWidgets('renders title, value and subtitle', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => const StatCardSpec().render(
              context,
              const A2UiNode(
                name: 'StatCard',
                props: A2UiProps({
                  'title': 'Volume',
                  'value': '12k',
                  'subtitle': 'week',
                  'trend': 'up',
                }),
              ),
              A2UiTheme.dark,
            ),
          ),
        ),
      ));
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('12k'), findsOneWidget);
      expect(find.text('week'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('renders without crashing on empty props', (tester) async {
      await pump(tester, {});
      expect(find.text('Metric'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('StatCardSpec doc', () {
    test('example payload round-trips through the spec', () {
      final example = const StatCardSpec().doc.example;
      expect(example['component'], 'StatCard');
      final props = example['props']! as Map<String, Object?>;
      final p = parse(props);
      expect(p.title, isNotEmpty);
      expect(p.value, isNot('—'));
    });
  });
}
