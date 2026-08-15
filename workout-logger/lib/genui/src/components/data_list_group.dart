import 'package:flutter/material.dart';

import '../a2ui_node.dart';
import '../a2ui_panels.dart';
import '../a2ui_props.dart';
import '../a2ui_spec.dart';
import '../a2ui_theme.dart';

@immutable
class A2UiListRow {
  const A2UiListRow({
    required this.primaryText,
    this.secondaryText,
    this.trailingValue,
  });

  final String primaryText;
  final String? secondaryText;
  final String? trailingValue;
}

@immutable
class DataListGroupProps {
  const DataListGroupProps({required this.rows, this.title});

  /// Null renders no header — the old code cast this to a non-null String.
  final String? title;
  final List<A2UiListRow> rows;

  bool get hasData => rows.isNotEmpty;
}

/// A titled list of primary / secondary / trailing rows.
class DataListGroupSpec extends A2UiSpec<DataListGroupProps> {
  const DataListGroupSpec();

  @override
  String get name => 'DataListGroup';

  @override
  List<String> get aliases => const ['DataList', 'ListGroup', 'Table', 'List'];

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema: 'DataListGroup {title?, items: '
            '[{primaryText, secondaryText?, trailingValue?}]}',
        purpose:
            'A short ranked or dated list. Use for records, recent sessions '
            'and top-N breakdowns.',
        example: {
          'component': 'DataListGroup',
          'props': {
            'title': 'Recent Personal Records',
            'items': [
              {
                'primaryText': 'Bench Press',
                'secondaryText': '2026-07-04',
                'trailingValue': '102.5 kg',
              },
              {
                'primaryText': 'Back Squat',
                'secondaryText': '2026-06-28',
                'trailingValue': '140 kg',
              },
            ],
          },
        },
      );

  @override
  DataListGroupProps parseProps(A2UiNode node) {
    final p = node.props;
    final title = p.textOrNull('title');

    final rows = <A2UiListRow>[];
    final raw = p.lookup('items');
    if (raw is List) {
      for (final item in raw) {
        final row = _row(item);
        if (row != null) rows.add(row);
      }
    }

    return DataListGroupProps(
      title: (title == null || title.isEmpty) ? null : title,
      rows: rows,
    );
  }

  /// Builds a row from a map or a bare scalar, or returns null when the item
  /// carries nothing displayable.
  A2UiListRow? _row(Object? item) {
    if (item is String || item is num || item is bool) {
      return A2UiListRow(primaryText: item.toString());
    }
    if (item is! Map) return null;

    final props = A2UiProps(A2UiProps.stringKeyed(item));
    var primary = props.textOrNull('primaryText');

    // Last resort: the first value in the map that stringifies, so a row keyed
    // with unexpected names still shows something.
    if (primary == null || primary.isEmpty) {
      for (final value in props.raw.values) {
        if (value is String && value.isNotEmpty) {
          primary = value;
          break;
        }
        if (value is num || value is bool) {
          primary = value.toString();
          break;
        }
      }
    }
    if (primary == null || primary.isEmpty) return null;

    final secondary = props.textOrNull('secondaryText');
    final trailing = props.textOrNull('trailingValue');

    return A2UiListRow(
      primaryText: primary,
      secondaryText:
          (secondary == null || secondary.isEmpty || secondary == primary)
              ? null
              : secondary,
      trailingValue: (trailing == null || trailing.isEmpty || trailing == primary)
          ? null
          : trailing,
    );
  }

  @override
  Widget buildWidget(
    BuildContext context,
    DataListGroupProps props,
    A2UiTheme theme,
  ) {
    if (!props.hasData) {
      return A2UiEmptyPanel(
        message: '${props.title ?? 'List'}: No items available',
        theme: theme,
      );
    }

    return A2UiPanel(
      theme: theme,
      padded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (props.title case final String title)
            Padding(
              padding: EdgeInsets.all(theme.spacing),
              child: Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          for (var i = 0; i < props.rows.length; i++)
            _Row(
              row: props.rows[i],
              theme: theme,
              showDivider: i < props.rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.theme,
    required this.showDivider,
  });

  final A2UiListRow row;
  final A2UiTheme theme;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing,
          vertical: theme.spacing / 2 + 2,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: theme.divider))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.primaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (row.secondaryText case final String secondary) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.textMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (row.trailingValue case final String trailing) ...[
              SizedBox(width: theme.spacing / 2),
              Text(
                trailing,
                style: TextStyle(
                  color: theme.seriesColor(1),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      );
}
