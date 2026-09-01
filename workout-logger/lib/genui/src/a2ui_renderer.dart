import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'a2ui_node.dart';
import 'a2ui_registry.dart';
import 'a2ui_theme.dart';

/// Renders an [A2UiNode] tree as Flutter widgets.
///
/// Purely presentational and fully local — no network, no side effects. Theme
/// comes from the nearest [A2UiThemeProvider], falling back to
/// [A2UiTheme.dark]. Registry comes from the explicit [registry] override if
/// given, else the nearest [A2UiRegistryProvider], falling back to
/// [defaultA2UiRegistry] — and whichever registry is resolved here is made
/// ambient to nested [A2UiRenderer] calls (e.g. from `GridContainer`) via
/// [A2UiRegistryProvider], so an override at any level of the tree propagates
/// to everything below it instead of silently reverting to the default past
/// one level of nesting.
class A2UiRenderer extends StatelessWidget {
  const A2UiRenderer({super.key, required this.node, this.registry});

  final A2UiNode node;

  /// Defaults to [defaultA2UiRegistry]; override to render a custom vocabulary.
  final A2UiRegistry? registry;

  @override
  Widget build(BuildContext context) {
    final resolvedRegistry = registry ?? A2UiRegistryProvider.of(context);
    final spec = resolvedRegistry.specFor(node.name);
    if (spec == null) {
      if (kDebugMode) {
        debugPrint('A2UiRenderer: no spec registered for "${node.name}"');
      }
      return const SizedBox.shrink();
    }
    return A2UiRegistryProvider(
      registry: resolvedRegistry,
      child: spec.render(context, node, A2UiThemeProvider.of(context)),
    );
  }
}
