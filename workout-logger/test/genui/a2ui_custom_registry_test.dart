// Regression coverage for the registry-propagation fix to A2UiRenderer.
//
// `A2UiRenderer`'s `registry` constructor override used to only apply to the
// top-level node: `GridContainerSpec.buildWidget` recurses via bare
// `A2UiRenderer(node: children[i])` with no registry forwarded, so nested
// children silently fell back to `defaultA2UiRegistry` even when the caller
// passed a custom registry at the root. If the custom registry's components
// weren't in the default one, those children silently rendered
// `SizedBox.shrink()` — blank, with no error.
//
// The fix mirrors the existing theme-injection pattern: `A2UiRenderer` now
// wraps its own subtree in an `A2UiRegistryProvider` carrying the resolved
// registry (explicit override, or whatever was already ambient), so nested
// bare `A2UiRenderer` calls made without an explicit override pick up the
// ambient registry via `A2UiRegistryProvider.of(context)` instead of
// reverting to the default.
//
// This file replaces the old `a2ui_parser_stub_test.dart`, which was
// temporary Task 3 scaffolding (a hand-rolled fake registry, needed only
// because `default_registry.dart` didn't exist yet at that point in the
// refactor) and had become redundant with `a2ui_parser_test.dart`, which
// covers the same parsing behaviors against the real registry.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/src/a2ui_node.dart';
import 'package:repforge/genui/src/a2ui_props.dart';
import 'package:repforge/genui/src/a2ui_registry.dart';
import 'package:repforge/genui/src/a2ui_renderer.dart';
import 'package:repforge/genui/src/a2ui_spec.dart';
import 'package:repforge/genui/src/a2ui_theme.dart';
import 'package:repforge/genui/src/components/grid_container.dart';

/// A minimal spec not present in `defaultA2UiRegistry`, so successfully
/// rendering it proves a custom registry was actually consulted.
class _CustomWidgetSpec extends A2UiSpec<String> {
  const _CustomWidgetSpec();

  @override
  String get name => 'CustomWidget';

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema: 'CustomWidget {label}',
        purpose: 'test-only stub component',
        example: {'component': 'CustomWidget', 'props': {'label': 'x'}},
      );

  @override
  String parseProps(A2UiNode node) => node.props.text('label');

  @override
  Widget buildWidget(BuildContext context, String props, A2UiTheme theme) =>
      Text('custom:$props');
}

void main() {
  final customRegistry = A2UiRegistry(const [
    GridContainerSpec(),
    _CustomWidgetSpec(),
  ]);

  testWidgets(
      'a custom registry propagates through GridContainer to nested children',
      (tester) async {
    final node = A2UiNode(
      name: 'GridContainer',
      props: const A2UiProps({'columns': 1}),
      children: const [
        A2UiNode(
          name: 'CustomWidget',
          props: A2UiProps({'label': 'first'}),
        ),
        A2UiNode(
          name: 'CustomWidget',
          props: A2UiProps({'label': 'second'}),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: A2UiRenderer(node: node, registry: customRegistry),
      ),
    ));

    // Before the fix, nested children resolved against `defaultA2UiRegistry`
    // (which does not know `CustomWidget`) and silently rendered
    // `SizedBox.shrink()` instead of this text.
    expect(find.text('custom:first'), findsOneWidget);
    expect(find.text('custom:second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'without a custom registry, an unknown component silently renders '
      'nothing rather than crashing', (tester) async {
    final node = A2UiNode(
      name: 'GridContainer',
      props: const A2UiProps({'columns': 1}),
      children: const [
        A2UiNode(name: 'CustomWidget', props: A2UiProps({'label': 'x'})),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // No `registry:` override — falls back to `defaultA2UiRegistry`,
        // which does not know `CustomWidget`.
        body: A2UiRenderer(node: node),
      ),
    ));

    expect(find.text('custom:x'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
