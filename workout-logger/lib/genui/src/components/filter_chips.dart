import 'package:flutter/material.dart';

import '../a2ui_node.dart';
import '../a2ui_spec.dart';
import '../a2ui_theme.dart';

@immutable
class FilterChipsProps {
  const FilterChipsProps({required this.options, this.activeOption});

  final List<String> options;

  /// Null when the model omitted it or named an option that does not exist.
  /// The old renderer cast this to a non-null String and crashed.
  final String? activeOption;

  bool get hasData => options.isNotEmpty;
}

/// A decorative row of context chips showing the window a dashboard covers.
///
/// Deliberately non-interactive: A2UI has no action contract yet, so a tappable
/// chip would imply behaviour the renderer cannot deliver. Adding interactivity
/// means threading an `onAction` callback through `A2UiRenderer` first.
class FilterChipsSpec extends A2UiSpec<FilterChipsProps> {
  const FilterChipsSpec();

  @override
  String get name => 'FilterChips';

  @override
  List<String> get aliases => const ['Chips', 'FilterRow', 'Tags'];

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema: 'FilterChips {options: [string], activeOption?}',
        purpose:
            'Labels the window or scope a dashboard covers. Decorative — the '
            'chips are not tappable.',
        example: {
          'component': 'FilterChips',
          'props': {
            'options': ['7 days', '30 days', '90 days'],
            'activeOption': '30 days',
          },
        },
      );

  @override
  FilterChipsProps parseProps(A2UiNode node) {
    final p = node.props;
    final options = p.stringList('options');
    final requested = p.textOrNull('activeOption');

    String? active;
    if (requested != null) {
      for (final option in options) {
        if (option.toLowerCase() == requested.toLowerCase()) {
          active = option;
          break;
        }
      }
    }

    return FilterChipsProps(options: options, activeOption: active);
  }

  @override
  Widget buildWidget(
    BuildContext context,
    FilterChipsProps props,
    A2UiTheme theme,
  ) {
    if (!props.hasData) return const SizedBox.shrink();

    return Wrap(
      spacing: theme.spacing / 2,
      runSpacing: theme.spacing / 2,
      children: [
        for (final option in props.options)
          _Chip(
            label: option,
            active: option == props.activeOption,
            theme: theme,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.theme,
  });

  final String label;
  final bool active;
  final A2UiTheme theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? theme.accent.withValues(alpha: 0.18)
              : theme.border,
          borderRadius: BorderRadius.circular(theme.pillRadius),
          border: Border.all(
            color: active
                ? theme.accent.withValues(alpha: 0.45)
                : theme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? theme.accent : theme.textSoft,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
