import 'package:flutter/material.dart';

import '../a2ui_node.dart';
import '../a2ui_renderer.dart';
import '../a2ui_spec.dart';
import '../a2ui_theme.dart';

@immutable
class GridContainerProps {
  const GridContainerProps({required this.columns, required this.children});

  /// Always 1 or 2.
  final int columns;
  final List<A2UiNode> children;
}

/// Vertical stack or two-column grid of other components.
///
/// Children are already parsed by [A2UiParser]; this spec only lays them out,
/// and recursion runs through the public [A2UiRenderer] so the injected theme
/// keeps flowing down the tree.
class GridContainerSpec extends A2UiSpec<GridContainerProps> {
  const GridContainerSpec();

  /// Below this width a two-column grid squeezes charts unreadably.
  static const double _collapseWidth = 420;

  @override
  String get name => 'GridContainer';

  @override
  List<String> get aliases => const ['Grid', 'Dashboard', 'Container', 'Layout'];

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema: 'GridContainer {columns: 1|2, children: [component, ...]}',
        purpose:
            'The wrapper for a multi-part dashboard. Use columns:2 for compact '
            'StatCards and columns:1 when it contains charts.',
        example: {
          'component': 'GridContainer',
          'props': {
            'columns': 2,
            'children': [
              {
                'component': 'StatCard',
                'props': {'title': 'Sessions', 'value': 14, 'trend': 'up'},
              },
              {
                'component': 'StatCard',
                'props': {'title': 'Volume', 'value': 128000, 'unit': 'kg'},
              },
            ],
          },
        },
      );

  @override
  GridContainerProps parseProps(A2UiNode node) => GridContainerProps(
        columns: node.props.integer('columns', or: 1).clamp(1, 2),
        children: node.children,
      );

  @override
  Widget buildWidget(
    BuildContext context,
    GridContainerProps props,
    A2UiTheme theme,
  ) {
    final children = props.children;
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < _collapseWidth ? 1 : props.columns;

        if (columns == 1) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                A2UiRenderer(node: children[i]),
                if (i < children.length - 1)
                  SizedBox(height: theme.spacing / 2),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += 2) {
          final right = i + 1 < children.length ? children[i + 1] : null;
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: A2UiRenderer(node: children[i])),
                  SizedBox(width: theme.spacing / 2),
                  Expanded(
                    child: right == null
                        ? const SizedBox.shrink()
                        : A2UiRenderer(node: right),
                  ),
                ],
              ),
            ),
          );
          if (i + 2 < children.length) {
            rows.add(SizedBox(height: theme.spacing / 2));
          }
        }
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }
}
