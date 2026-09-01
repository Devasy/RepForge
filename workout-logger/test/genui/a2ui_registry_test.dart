import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_registry.dart';
import 'package:repforge/genui/src/a2ui_spec.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';

class _FakeProps {
  const _FakeProps(this.title);
  final String title;
}

class _FakeSpec extends A2UiSpec<_FakeProps> {
  const _FakeSpec();

  @override
  String get name => 'StatCard';

  @override
  List<String> get aliases => const ['Stat', 'KpiCard'];

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema: 'StatCard {title, value}',
        purpose: 'A single headline number.',
        example: {
          'component': 'StatCard',
          'props': {'title': 'Volume', 'value': '12000 kg'},
        },
      );

  @override
  _FakeProps parseProps(A2UiNode node) => _FakeProps(node.props.text('title'));

  @override
  Widget buildWidget(BuildContext context, _FakeProps props, A2UiTheme theme) =>
      Text(props.title, textDirection: TextDirection.ltr);
}

/// A minimal fake spec with a configurable name/aliases, for exercising
/// registry collision detection.
class _NamedFakeSpec extends A2UiSpec<_FakeProps> {
  const _NamedFakeSpec(this.name, {this.aliases = const []});

  @override
  final String name;

  @override
  final List<String> aliases;

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema: 'Fake {}',
        purpose: 'A fake component for tests.',
        example: {'component': 'Fake', 'props': {}},
      );

  @override
  _FakeProps parseProps(A2UiNode node) => _FakeProps(node.props.text('title'));

  @override
  Widget buildWidget(BuildContext context, _FakeProps props, A2UiTheme theme) =>
      Text(props.title, textDirection: TextDirection.ltr);
}

void main() {
  final registry = A2UiRegistry(const [_FakeSpec()]);

  group('A2UiRegistry lookup', () {
    test('resolves the canonical name', () {
      expect(registry.specFor('StatCard'), isNotNull);
    });

    test('resolves case, underscore and space variants', () {
      for (final variant in ['statcard', 'STAT_CARD', 'Stat Card', 'stat-card']) {
        expect(registry.specFor(variant), isNotNull, reason: variant);
      }
    });

    test('resolves declared aliases', () {
      expect(registry.specFor('KpiCard')?.name, 'StatCard');
      expect(registry.specFor('stat')?.name, 'StatCard');
    });

    test('returns null for an unknown name', () {
      expect(registry.specFor('HeroBanner'), isNull);
    });

    test('canonicalName maps any accepted variant to the canonical name', () {
      expect(registry.canonicalName('kpi_card'), 'StatCard');
      expect(registry.canonicalName('nope'), isNull);
    });

    test('exposes specs in registration order', () {
      expect(registry.specs.map((s) => s.name), ['StatCard']);
    });

    test('throws when two specs share a canonical name', () {
      expect(
        () => A2UiRegistry(const [
          _NamedFakeSpec('LineChart'),
          _NamedFakeSpec('LineChart'),
        ]),
        throwsStateError,
      );
    });

    test("throws when a spec's alias matches another spec's canonical name",
        () {
      expect(
        () => A2UiRegistry(const [
          _NamedFakeSpec('LineChart'),
          _NamedFakeSpec('BarChart', aliases: ['LineChart']),
        ]),
        throwsStateError,
      );
    });

    test('throws when two specs share an alias', () {
      expect(
        () => A2UiRegistry(const [
          _NamedFakeSpec('LineChart', aliases: ['Chart']),
          _NamedFakeSpec('BarChart', aliases: ['Chart']),
        ]),
        throwsStateError,
      );
    });
  });

  group('A2UiSpec', () {
    testWidgets('render() parses then builds', (tester) async {
      const node = A2UiNode(
        name: 'StatCard',
        props: A2UiProps({'title': 'Weekly Volume'}),
      );
      await tester.pumpWidget(
        Builder(
          builder: (context) =>
              registry.specFor('StatCard')!.render(context, node, A2UiTheme.dark),
        ),
      );
      expect(find.text('Weekly Volume'), findsOneWidget);
    });
  });

  group('A2UiNode', () {
    test('defaults to no children', () {
      const node = A2UiNode(name: 'StatCard', props: A2UiProps.empty);
      expect(node.children, isEmpty);
    });
  });
}
