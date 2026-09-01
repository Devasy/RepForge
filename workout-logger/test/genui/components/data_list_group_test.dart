import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';
import 'package:repforge/genui/src/components/data_list_group.dart';

DataListGroupProps parse(Map<String, Object?> props) =>
    const DataListGroupSpec()
        .parseProps(A2UiNode(name: 'DataListGroup', props: A2UiProps(props)));

Future<void> pump(WidgetTester tester, Map<String, Object?> props) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => const DataListGroupSpec().render(
            context,
            A2UiNode(name: 'DataListGroup', props: A2UiProps(props)),
            A2UiTheme.dark,
          ),
        ),
      ),
    ));

void main() {
  group('DataListGroupProps parsing', () {
    test('reads the happy path', () {
      final p = parse({
        'title': 'Recent PRs',
        'items': [
          {
            'primaryText': 'Bench Press',
            'secondaryText': '2026-07-04',
            'trailingValue': '102.5 kg',
          },
        ],
      });
      expect(p.title, 'Recent PRs');
      expect(p.rows.single.primaryText, 'Bench Press');
      expect(p.rows.single.trailingValue, '102.5 kg');
    });

    test('treats a missing title as no header, not a crash', () {
      final p = parse({
        'items': [
          {'primaryText': 'Bench'}
        ]
      });
      expect(p.title, isNull);
      expect(p.rows, hasLength(1));
    });

    test('stringifies a numeric trailing value', () {
      final p = parse({
        'items': [
          {'primaryText': 'Bench', 'trailingValue': 102.5}
        ]
      });
      expect(p.rows.single.trailingValue, '102.5');
    });

    test('accepts plain-string items', () {
      final p = parse({'items': ['Bench Press', 'Squat']});
      expect(p.rows.map((r) => r.primaryText), ['Bench Press', 'Squat']);
      expect(p.rows.first.secondaryText, isNull);
    });

    test('falls back to the first stringifiable value when primaryText is absent',
        () {
      final p = parse({
        'items': [
          {'exercise': 'Deadlift', 'volume': 4200}
        ]
      });
      expect(p.rows.single.primaryText, 'Deadlift');
    });

    test('drops items with nothing renderable', () {
      final p = parse({
        'items': [
          {'primaryText': 'Bench'},
          <String, Object?>{},
          {'nested': <String, Object?>{}},
        ],
      });
      expect(p.rows, hasLength(1));
    });

    test('resolves row key aliases', () {
      final p = parse({
        'rows': [
          {'primary': 'Bench', 'detail': 'Mon', 'right': '100 kg'}
        ]
      });
      expect(p.rows.single.primaryText, 'Bench');
      expect(p.rows.single.secondaryText, 'Mon');
      expect(p.rows.single.trailingValue, '100 kg');
    });

    test('never throws on hostile input', () {
      expect(() => parse({'items': 5, 'title': []}), returnsNormally);
    });
  });

  group('DataListGroup rendering', () {
    testWidgets('renders title and all rows', (tester) async {
      await pump(tester, {
        'title': 'Recent PRs',
        'items': [
          {'primaryText': 'Bench', 'secondaryText': 'Mon', 'trailingValue': '100'},
          {'primaryText': 'Squat', 'secondaryText': 'Wed', 'trailingValue': '140'},
        ],
      });
      expect(find.text('Recent PRs'), findsOneWidget);
      expect(find.text('Bench'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('140'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders rows with only a primary text', (tester) async {
      await pump(tester, {'items': ['Bench Press']});
      expect(find.text('Bench Press'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an empty panel when there are no rows',
        (tester) async {
      await pump(tester, {'title': 'Recent PRs', 'items': []});
      expect(find.textContaining('No items'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DataListGroupSpec doc', () {
    test('example payload is renderable', () {
      final props = const DataListGroupSpec().doc.example['props']!
          as Map<String, Object?>;
      expect(parse(props).hasData, isTrue);
    });
  });
}
