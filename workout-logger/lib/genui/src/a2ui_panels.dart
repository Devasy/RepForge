import 'package:flutter/widgets.dart';

import 'a2ui_theme.dart';

/// The card chrome every A2UI component sits inside.
class A2UiPanel extends StatelessWidget {
  const A2UiPanel({
    super.key,
    required this.child,
    required this.theme,
    this.padded = true,
  });

  final Widget child;
  final A2UiTheme theme;
  final bool padded;

  @override
  Widget build(BuildContext context) => Container(
        padding: padded ? EdgeInsets.all(theme.spacing) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.radius),
          border: Border.all(color: theme.border),
        ),
        child: child,
      );
}

/// A panel heading with optional right-aligned trailing text.
class A2UiPanelTitle extends StatelessWidget {
  const A2UiPanelTitle({
    super.key,
    required this.title,
    required this.theme,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final A2UiTheme theme;

  @override
  Widget build(BuildContext context) {
    final label = trailing;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (label != null && label.isNotEmpty)
          Text(
            label,
            style: TextStyle(color: theme.textFaint, fontSize: 11),
          ),
      ],
    );
  }
}

/// Shown in place of a chart when a component parsed but carries no data.
///
/// Deliberately visible rather than a blank `SizedBox`: a silent disappearance
/// hides model errors, a labelled panel surfaces them.
class A2UiEmptyPanel extends StatelessWidget {
  const A2UiEmptyPanel({
    super.key,
    required this.message,
    required this.theme,
  });

  final String message;
  final A2UiTheme theme;

  @override
  Widget build(BuildContext context) => A2UiPanel(
        theme: theme,
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textMuted, fontSize: 12),
          ),
        ),
      );
}

/// Series legend shared by the line, bar and radar renderers.
class A2UiLegend extends StatelessWidget {
  const A2UiLegend({
    super.key,
    required this.names,
    required this.theme,
    this.dots = false,
  });

  final List<String> names;
  final A2UiTheme theme;
  final bool dots;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (var i = 0; i < names.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: dots ? 8 : 10,
                  height: dots ? 8 : 3,
                  decoration: BoxDecoration(
                    color: theme.seriesColor(i),
                    shape: dots ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: dots ? null : BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  names[i],
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      );
}
