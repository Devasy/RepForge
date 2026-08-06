import 'package:flutter/widgets.dart';

import 'a2ui_node.dart';
import 'a2ui_registry.dart';
import 'a2ui_theme.dart';
import 'default_registry.dart';

/// Renders an [A2UiNode] tree as Flutter widgets.
///
/// Purely presentational and fully local — no network, no side effects. Theme
/// comes from the nearest [A2UiThemeProvider], falling back to
/// [A2UiTheme.dark].
class A2UiRenderer extends StatelessWidget {
  const A2UiRenderer({super.key, required this.node, this.registry});

  final A2UiNode node;

  /// Defaults to [defaultA2UiRegistry]; override to render a custom vocabulary.
  final A2UiRegistry? registry;

  @override
  Widget build(BuildContext context) {
    final spec = (registry ?? defaultA2UiRegistry).specFor(node.name);
    if (spec == null) return const SizedBox.shrink();
    return spec.render(context, node, A2UiThemeProvider.of(context));
  }
}
