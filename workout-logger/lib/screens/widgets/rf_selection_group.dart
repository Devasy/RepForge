import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RFSelectionOption<T> {
  const RFSelectionOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// Glass choices with an intrinsic compact variant for chart toolbars.
class RFSelectionGroup<T> extends StatelessWidget {
  const RFSelectionGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.width,
    this.compact = false,
    this.expanded = true,
  }) : assert(options.length > 0);
  final List<RFSelectionOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final double? width;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) => width != null
      ? _buildGroup(context, width!)
      : LayoutBuilder(
          builder: (context, constraints) =>
              _buildGroup(context, constraints.maxWidth),
        );

  Widget _buildGroup(BuildContext context, double available) {
    final style = AppControlTheme.textStyle.copyWith(
      fontSize: compact ? 12 : 14,
      fontWeight: FontWeight.w600,
    );
    final naturalWidth = options.fold<double>(48, (largest, option) {
      final painter = TextPainter(
        text: TextSpan(text: option.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final measured = math.max(largest, painter.width + (compact ? 20 : 28));
      painter.dispose();
      return measured;
    });
    const inset = AppSpacing.xs;
    final desired = naturalWidth * options.length + inset * 2;
    final groupWidth = available.isFinite
        ? (expanded ? available : math.min(desired, available))
        : desired;
    final innerWidth = math.max(0.0, groupWidth - inset * 2);
    final columns = (innerWidth / naturalWidth).floor().clamp(
      1,
      options.length,
    );
    final buttonWidth = innerWidth / columns;
    return SizedBox(
      width: groupWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.glassFillTop, AppColors.glassFillBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.glassBorderStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.all(inset),
          child: Wrap(
            runSpacing: inset,
            children: [
              for (final option in options)
                SizedBox(
                  width: buttonWidth,
                  child: MergeSemantics(
                    child: Semantics(
                      selected: selected == option.value,
                      enabled: onChanged != null,
                      inMutuallyExclusiveGroup: true,
                      child: FilledButton(
                        onPressed: onChanged == null
                            ? null
                            : () => onChanged!(option.value),
                        style:
                            AppControlTheme.selectionStyle(
                              selected: selected == option.value,
                              first: false,
                              last: false,
                              reduceMotion: MediaQuery.disableAnimationsOf(
                                context,
                              ),
                            ).copyWith(
                              minimumSize: const WidgetStatePropertyAll(
                                Size(48, 40),
                              ),
                              padding: WidgetStatePropertyAll(
                                EdgeInsets.symmetric(
                                  horizontal: compact ? 8 : 12,
                                  vertical: 8,
                                ),
                              ),
                              textStyle: WidgetStatePropertyAll(style),
                            ),
                        child: Text(option.label, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
