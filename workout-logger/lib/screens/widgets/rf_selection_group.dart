import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class RFSelectionOption<T> {
  const RFSelectionOption({required this.value, required this.label});

  final T value;
  final String label;
}

class RFSelectionGroup<T> extends StatelessWidget {
  const RFSelectionGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.width,
  }) : assert(options.length > 0);

  final List<RFSelectionOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) => width != null
      ? _buildGroup(context, width!)
      : LayoutBuilder(
          builder: (context, constraints) =>
              _buildGroup(context, constraints.maxWidth),
        );

  Widget _buildGroup(BuildContext context, double availableWidth) {
    final textScaler = MediaQuery.textScalerOf(context);
    final style = AppControlTheme.textStyle.copyWith(
      fontWeight: FontWeight.w600,
    );
    final naturalWidth = options.fold<double>(0, (width, option) {
      final painter = TextPainter(
        text: TextSpan(text: option.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      final result = math.max(width, painter.width + 60);
      painter.dispose();
      return result;
    });
    final width = availableWidth.isFinite
        ? availableWidth
        : naturalWidth * options.length + AppSpacing.xs * (options.length - 1);
    final columns = ((width + AppSpacing.xs) / (naturalWidth + AppSpacing.xs))
        .floor()
        .clamp(1, options.length);
    final buttonWidth = (width - AppSpacing.xs * (columns - 1)) / columns;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < options.length; i++)
          SizedBox(
            width: buttonWidth,
            child: _SelectionButton(
              label: options[i].label,
              selected: selected == options[i].value,
              first: i % columns == 0,
              last: i % columns == columns - 1 || i == options.length - 1,
              onPressed: onChanged == null
                  ? null
                  : () => onChanged!(options[i].value),
            ),
          ),
      ],
    );
  }
}

class _SelectionButton extends StatelessWidget {
  const _SelectionButton({
    required this.label,
    required this.selected,
    required this.first,
    required this.last,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool first;
  final bool last;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      selected: selected,
      enabled: onPressed != null,
      inMutuallyExclusiveGroup: true,
      child: FilledButton(
        onPressed: onPressed,
        style: AppControlTheme.selectionStyle(
          selected: selected,
          first: first,
          last: last,
          reduceMotion: MediaQuery.disableAnimationsOf(context),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 20,
                child: selected
                    ? const Icon(Icons.check_rounded, size: 20)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    ),
  );
}
