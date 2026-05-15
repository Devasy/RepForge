// rf_inputs.dart — RepForge form input widgets

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

// ── RFTextField ───────────────────────────────────────────────────────────────
// Styled text input using AppColors tokens.
class RFTextField extends StatelessWidget {
  const RFTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.errorText,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final String? errorText;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      enabled: enabled,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSoft),
        errorText: errorText,
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.textMuted, size: 20)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

// ── RFNumberField ─────────────────────────────────────────────────────────────
// Large monospace tap-to-edit number for weights and reps.
// Tap → shows inline text field. Long-press → continuous increment.
class RFNumberField extends StatefulWidget {
  const RFNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.step = 1.0,
    this.min = 0.0,
    this.max = 9999.0,
    this.decimals = 0,
    this.color,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String? label;
  final double step;
  final double min;
  final double max;
  final int decimals;
  final Color? color;

  @override
  State<RFNumberField> createState() => _RFNumberFieldState();
}

class _RFNumberFieldState extends State<RFNumberField> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(RFNumberField old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _ctrl.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  String _format(double v) =>
      widget.decimals > 0 ? v.toStringAsFixed(widget.decimals) : v.toInt().toString();

  void _startIncrement(double dir) {
    _step(dir);
    _longPressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      _step(dir);
    });
  }

  void _stopIncrement() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _step(double dir) {
    final next = (widget.value + dir * widget.step).clamp(widget.min, widget.max);
    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  void _commitEdit() {
    final parsed = double.tryParse(_ctrl.text);
    if (parsed != null) {
      widget.onChanged(parsed.clamp(widget.min, widget.max));
    } else {
      _ctrl.text = _format(widget.value);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decrement button
            GestureDetector(
              onTap: () => _step(-1),
              onLongPressStart: (_) => _startIncrement(-1),
              onLongPressEnd: (_) => _stopIncrement(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: AppColors.textSoft,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Value display / edit
            GestureDetector(
              onTap: () {
                setState(() => _editing = true);
                _ctrl.text = _format(widget.value);
                _ctrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _ctrl.text.length,
                );
              },
              child: Container(
                width: 80,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: _editing ? AppColors.primary : AppColors.glassBorder,
                    width: _editing ? 2 : 1,
                  ),
                ),
                child: _editing
                    ? TextField(
                        controller: _ctrl,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          color: c,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _commitEdit(),
                        onEditingComplete: _commitEdit,
                      )
                    : Text(
                        _format(widget.value),
                        style: TextStyle(
                          color: c,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Increment button
            GestureDetector(
              onTap: () => _step(1),
              onLongPressStart: (_) => _startIncrement(1),
              onLongPressEnd: (_) => _stopIncrement(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.textSoft,
                ),
              ),
            ),
          ],
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.label!,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

// ── RFToggle ──────────────────────────────────────────────────────────────────
// Two-option segmented toggle (e.g. kg / lbs, Compound / Isolation).
class RFToggle extends StatelessWidget {
  const RFToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.color,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: selected ? c : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: c.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── RFDropdown ────────────────────────────────────────────────────────────────
class RFDropdown<T> extends StatelessWidget {
  const RFDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.labelBuilder,
  });

  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final String Function(T)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: DropdownButton<T>(
        value: value,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppColors.cardHigh,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        hint: hint != null
            ? Text(hint!, style: const TextStyle(color: AppColors.textMuted))
            : null,
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSoft),
        items: items.map((item) {
          final label =
              labelBuilder != null ? labelBuilder!(item) : item.toString();
          return DropdownMenuItem<T>(value: item, child: Text(label));
        }).toList(),
      ),
    );
  }
}

// ── NumberPickerSheet ─────────────────────────────────────────────────────────
// Bottom sheet with large +/- stepper — extracted from workout_flow logic.
class NumberPickerSheet extends StatefulWidget {
  const NumberPickerSheet({
    super.key,
    required this.title,
    required this.initial,
    required this.step,
    required this.min,
    required this.max,
    this.decimals = 0,
    this.suffix = '',
  });

  final String title;
  final double initial;
  final double step;
  final double min;
  final double max;
  final int decimals;
  final String suffix;

  static Future<double?> show(
    BuildContext context, {
    required String title,
    required double initial,
    required double step,
    required double min,
    required double max,
    int decimals = 0,
    String suffix = '',
  }) {
    return showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => NumberPickerSheet(
        title: title,
        initial: initial,
        step: step,
        min: min,
        max: max,
        decimals: decimals,
        suffix: suffix,
      ),
    );
  }

  @override
  State<NumberPickerSheet> createState() => _NumberPickerSheetState();
}

class _NumberPickerSheetState extends State<NumberPickerSheet> {
  late double _value;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _step(double dir) {
    setState(() {
      _value = (_value + dir * widget.step).clamp(widget.min, widget.max);
    });
    HapticFeedback.selectionClick();
  }

  String get _display => widget.decimals > 0
      ? _value.toStringAsFixed(widget.decimals)
      : _value.toInt().toString();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.textSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _step(-1),
                  onLongPress: () {
                    _holdTimer?.cancel();
                    _holdTimer = Timer.periodic(
                      const Duration(milliseconds: 100),
                      (_) { if (mounted) _step(-1); },
                    );
                  },
                  onLongPressEnd: () {
                    _holdTimer?.cancel();
                    _holdTimer = null;
                  },
                ),
                const SizedBox(width: AppSpacing.xl),
                Text(
                  '$_display${widget.suffix}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                _StepButton(
                  icon: Icons.add_rounded,
                  onTap: () => _step(1),
                  onLongPress: () {
                    _holdTimer?.cancel();
                    _holdTimer = Timer.periodic(
                      const Duration(milliseconds: 100),
                      (_) { if (mounted) _step(1); },
                    );
                  },
                  onLongPressEnd: () {
                    _holdTimer?.cancel();
                    _holdTimer = null;
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            GlowButton(
              label: 'Confirm',
              onPressed: () => Navigator.pop(context, _value),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.onLongPress,
    this.onLongPressEnd,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressEnd: (_) => onLongPressEnd?.call(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.cardHigh,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 28),
      ),
    );
  }
}
