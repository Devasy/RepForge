import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';
import 'package:repforge/genui/src/components/filter_chips.dart';

FilterChipsProps parse(Map<String, Object?> props) => const FilterChipsSpec()
    .parseProps(A2UiNode(name: 'FilterChips', props: A2UiProps(props)));

Future<void> pump(WidgetTester tester, Map<String, Object?> props) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => const FilterChipsSpec().render(
            context,
            A2UiNode(name: 'FilterChips', props: A2UiProps(props)),
            A2UiTheme.dark,
          ),
        ),
      ),
    ));

void main() {
  group('FilterChipsProps parsing', () {
    test('reads options and the active option', () {
      final p = parse({
        'options': ['7d', '30d', '90d'],
        'activeOption': '30d',
      });
      expect(p.options, ['7d', '30d', '90d']);
      expect(p.activeOption, '30d');
    });

    test('nulls a missing active option instead of crashing', () {
      expect(parse({'options': ['7d', '30d']}).activeOption, isNull);
    });

    test('matches the active option case-insensitively', () {
      expect(parse({'options': ['Week', 'Month'], 'active': 'MONTH'})
          .activeOption, 'Month');
    });

    test('nulls an active option that is not in the list', () {
      expect(
        parse({'options': ['7d'], 'activeOption': '365d'}).activeOption,
        isNull,
      );
    });

    test('stringifies non-string options', () {
      expect(parse({'options': [7, 30, 90]}).options, ['7', '30', '90']);
    });

    test('hasData is false without options', () {
      expect(parse({}).hasData, isFalse);
      expect(parse({'options': []}).hasData, isFalse);
      expect(parse({'options': ['a']}).hasData, isTrue);
    });

    test('never throws on hostile input', () {
      expect(
        () => parse({'options': 5, 'activeOption': <String, Object?>{}}),
        returnsNormally,
      );
    });
  });

  group('FilterChips rendering', () {
    testWidgets('renders every option', (tester) async {
      await pump(tester, {
        'options': ['7d', '30d', '90d'],
        'activeOption': '30d',
      });
      expect(find.text('7d'), findsOneWidget);
      expect(find.text('30d'), findsOneWidget);
      expect(find.text('90d'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with no active option', (tester) async {
      await pump(tester, {'options': ['7d', '30d']});
      expect(find.text('7d'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders nothing when there are no options', (tester) async {
      await pump(tester, {'options': []});
      expect(find.byType(Wrap), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
