import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/a2ui.dart';

Future<void> pumpText(WidgetTester tester, String text,
    {Size size = const Size(800, 600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final node = A2UiParser(defaultA2UiRegistry).parse(text);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: node == null
            ? const Text('PROSE')
            : A2UiRenderer(node: node),
      ),
    ),
  ));
}

void main() {
  group('registry completeness', () {
    test('registers all eight components', () {
      expect(
        defaultA2UiRegistry.specs.map((s) => s.name).toList()..sort(),
        [
          'DataListGroup',
          'DynamicChart',
          'FilterChips',
          'GridContainer',
          'MetricGauge',
          'RadarChart',
          'ScatterPlot',
          'StatCard',
        ],
      );
    });

    test('every spec example parses back to its own component', () {
      final parser = A2UiParser(defaultA2UiRegistry);
      for (final spec in defaultA2UiRegistry.specs) {
        if (spec.name == 'GridContainer') continue;
        final node = parser.parseJson(spec.doc.example);
        expect(node?.name, spec.name, reason: '${spec.name} example');
      }
    });
  });

  // Regression coverage for a Task 13 fix to a2ui_parser.dart (a Task 3
  // file), discovered during registry integration: `_parseChildren` and
  // `_declaresChildren` used to resolve `children` through A2UiProps'
  // alias-aware `lookup()`, which treats `items` as an alias for `children`.
  // That collided with DataListGroup, whose own canonical data-row key is
  // also `items` — so a DataListGroup node's `items` list of
  // `{primaryText, ...}` maps was mistaken for a list of child *components*,
  // none of them parsed as one, and the node was then discarded outright as
  // "declared children, ended up with none."
  //
  // First fix pass restricted per-node structural recursion to the literal
  // `children` key only. That was too narrow: it silently dropped
  // `components`/`elements`/`content` tolerance at the per-node level even
  // though those keys never collided with anything — only `items` did. A
  // payload like `{"component":"GridContainer","props":{"components":[...]}}`
  // resolved fine before the original bug and regressed to zero children
  // after the first fix, with `_declaresChildren` no longer even recognizing
  // it as "declared children" — so instead of falling back to `null` (which
  // at least lets the caller show the raw text as prose), it silently
  // rendered as an empty, blank `GridContainer`. Fixed by widening the
  // per-node lookup to the same literal key set `_envelopeKeys` already
  // tolerates (`children`/`components`/`elements`/`content`), still
  // excluding `items`, still without going through the alias-aware
  // `A2UiProps.lookup()`.
  group('children vs items key collision (a2ui_parser.dart fix)', () {
    test('DataListGroup example parses instead of being swallowed', () {
      // Before the fix this returned null: `items` resolved as an alias for
      // `children`, none of the rows parsed as components, and the node was
      // discarded as an emptied-out container.
      final parser = A2UiParser(defaultA2UiRegistry);
      final spec = defaultA2UiRegistry.specFor('DataListGroup')!;
      final node = parser.parseJson(spec.doc.example);
      expect(node?.name, 'DataListGroup');
    });

    testWidgets('DataListGroup items render end to end through the parser',
        (tester) async {
      await pumpText(tester, '''
{"component":"DataListGroup","props":{"items":[
  {"primaryText":"Bench Press","trailingValue":"102.5 kg"}
]}}
''');
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('102.5 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("GridContainer's literal children key still resolves",
        (tester) async {
      await pumpText(tester, '''
{"component":"GridContainer","props":{"columns":1,"children":[
  {"component":"StatCard","props":{"title":"Still Works","value":"1"}}
]}}
''');
      expect(find.text('Still Works'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('per-node components/elements/content keys resolve to real children',
        () {
      // Regression for the too-narrow first fix pass: these are literal
      // (non-`items`) child-list keys at the *per-node* level, not the
      // top-level envelope path — a different code path (`_parseChildren`
      // via `parseJson`, not `parse`'s top-level envelope scan).
      final parser = A2UiParser(defaultA2UiRegistry);
      for (final key in ['components', 'elements', 'content']) {
        final node = parser.parseJson({
          'component': 'GridContainer',
          'props': {
            'columns': 1,
            key: [
              {
                'component': 'StatCard',
                'props': {'title': 'Via $key', 'value': '1'},
              },
            ],
          },
        });
        expect(node?.name, 'GridContainer', reason: 'per-node key "$key"');
        expect(node?.children, hasLength(1), reason: 'per-node key "$key"');
        expect(node?.children.single.name, 'StatCard',
            reason: 'per-node key "$key"');
      }
    });

    test('per-node items key stays excluded from child resolution', () {
      // Confirms the widened fix did not accidentally let `items` back in
      // as a per-node child-list key — it must still be treated as
      // DataListGroup's own data, not a list of child components.
      final parser = A2UiParser(defaultA2UiRegistry);
      final node = parser.parseJson({
        'component': 'GridContainer',
        'props': {
          'columns': 1,
          'items': [
            {
              'component': 'StatCard',
              'props': {'title': 'Should not be a child', 'value': '1'},
            },
          ],
        },
      });
      // GridContainer has no other content, so with `items` correctly
      // excluded from child resolution it has zero children and is dropped
      // entirely rather than silently rendered blank — `_declaresChildren`
      // does not fire for `items`, so this actually returns a real
      // zero-children node here (GridContainer doesn't declare `items` as
      // its own data key), which is the expected non-crashing behavior.
      expect(node?.name, 'GridContainer');
      expect(node?.children, isEmpty);
    });

    test('top-level envelope aliases (components/elements/ui) are unaffected',
        () {
      // A single-item envelope still wraps in a GridContainer rather than
      // collapsing to the bare child — naming an envelope key is an explicit
      // "this is a container" signal (see A2UiParser._wrap's
      // collapseSingle doc). That behavior predates this fix and must be
      // unaffected by it.
      final parser = A2UiParser(defaultA2UiRegistry);
      for (final key in ['components', 'elements', 'ui']) {
        final node = parser.parse(
          '{"$key":[{"component":"StatCard","props":{"title":"E","value":"1"}}]}',
        );
        expect(node?.name, 'GridContainer', reason: 'envelope key "$key"');
        expect(node?.children.single.name, 'StatCard',
            reason: 'envelope key "$key"');
      }
    });
  });

  group('GridContainer', () {
    testWidgets('renders children side by side at two columns',
        (tester) async {
      await pumpText(tester, '''
{"component":"GridContainer","props":{"columns":2,"children":[
  {"component":"StatCard","props":{"title":"A","value":"1"}},
  {"component":"StatCard","props":{"title":"B","value":"2"}}
]}}
''');
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('collapses to one column on a narrow viewport',
        (tester) async {
      await pumpText(tester, '''
{"component":"GridContainer","props":{"columns":2,"children":[
  {"component":"StatCard","props":{"title":"A","value":"1"}},
  {"component":"StatCard","props":{"title":"B","value":"2"}}
]}}
''', size: const Size(360, 800));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.byType(IntrinsicHeight), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles an odd child count', (tester) async {
      await pumpText(tester, '''
{"component":"GridContainer","props":{"columns":2,"children":[
  {"component":"StatCard","props":{"title":"A","value":"1"}},
  {"component":"StatCard","props":{"title":"B","value":"2"}},
  {"component":"StatCard","props":{"title":"C","value":"3"}}
]}}
''');
      expect(find.text('C'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a mixed dashboard end to end', (tester) async {
      await pumpText(tester, '''
{"component":"GridContainer","props":{"columns":1,"children":[
  {"component":"StatCard","props":{"title":"Volume","value":12400,"unit":"kg","trend":"improving"}},
  {"component":"DynamicChart","props":{"type":"bar","title":"Sets","labels":["Mon","Wed"],"values":[12,15]}},
  {"component":"MetricGauge","props":{"title":"Readiness","value":"82"}},
  {"component":"DataListGroup","props":{"items":[{"primaryText":"Bench","trailingValue":102.5}]}},
  {"component":"FilterChips","props":{"options":["7d","30d"]}}
]}}
''');
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('12400 kg'), findsOneWidget);
      expect(find.text('Sets'), findsOneWidget);
      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('Bench'), findsOneWidget);
      expect(find.text('7d'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('A2UiRenderer', () {
    testWidgets('renders nothing for a node the registry does not know',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: A2UiRenderer(
            node: A2UiNode(name: 'Unregistered', props: A2UiProps.empty),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('picks up an injected theme', (tester) async {
      const custom = A2UiTheme.dark;
      await tester.pumpWidget(const MaterialApp(
        home: A2UiThemeProvider(
          theme: custom,
          child: Scaffold(
            body: A2UiRenderer(
              node: A2UiNode(
                name: 'StatCard',
                props: A2UiProps({'title': 'Themed', 'value': '1'}),
              ),
            ),
          ),
        ),
      ));
      expect(find.text('Themed'), findsOneWidget);
    });
  });
}
