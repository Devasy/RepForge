import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

class RFTextField extends StatelessWidget {
  const RFTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.autofocus = false,
    this.enabled = true,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.expands = false,
    this.compact = false,
    this.inline = false,
    this.errorText,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.scrollController,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final bool autofocus;
  final bool enabled;
  final bool obscureText;
  final bool enableSuggestions;
  final bool autocorrect;
  final bool expands;
  final bool compact;
  final bool inline;
  final String? errorText;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    maxLines: maxLines,
    minLines: minLines,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    onEditingComplete: onEditingComplete,
    autofocus: autofocus,
    enabled: enabled,
    obscureText: obscureText,
    enableSuggestions: enableSuggestions,
    autocorrect: autocorrect,
    expands: expands,
    textCapitalization: textCapitalization,
    textAlign: textAlign,
    textAlignVertical: textAlignVertical,
    scrollController: scrollController,
    cursorColor: AppColors.controlFocus,
    style: AppControlTheme.textStyle.merge(style),
    decoration: (decoration ?? const InputDecoration())
        .copyWith(
          hintText: hint,
          labelText: label,
          errorText: errorText,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 22),
          suffixIcon: suffixIcon,
        )
        .applyDefaults(
          AppControlTheme.inputDecoration(compact: compact, inline: inline),
        ),
  );
}

class RFTextFormField extends StatelessWidget {
  const RFTextFormField({
    super.key,
    this.controller,
    this.decoration = const InputDecoration(),
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController? controller;
  final InputDecoration decoration;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    textCapitalization: textCapitalization,
    inputFormatters: inputFormatters,
    validator: validator,
    style: AppControlTheme.textStyle,
    cursorColor: AppColors.controlFocus,
    decoration: decoration.applyDefaults(AppControlTheme.inputDecoration()),
  );
}

class RFDropdown<T> extends StatefulWidget {
  const RFDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
    this.labelBuilder,
    this.compact = true,
  });

  final T? value;
  final List<T> items;
  final FutureOr<void> Function(T?)? onChanged;
  final String? label;
  final String? hint;
  final String Function(T)? labelBuilder;
  final bool compact;

  @override
  State<RFDropdown<T>> createState() => _RFDropdownState<T>();
}

class _RFDropdownState<T> extends State<RFDropdown<T>> {
  late final TextEditingController _controller;

  String _label(T? value) =>
      value == null ? '' : widget.labelBuilder?.call(value) ?? value.toString();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _label(widget.value));
  }

  @override
  void didUpdateWidget(RFDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _restoreSelection();
  }

  void _restoreSelection() {
    final label = _label(widget.value);
    if (_controller.text != label) _controller.text = label;
  }

  Future<void> _select(T? value) async {
    try {
      await widget.onChanged?.call(value);
    } finally {
      if (mounted) _restoreSelection();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DropdownMenu<T>(
    controller: _controller,
    initialSelection: widget.value,
    enabled: widget.onChanged != null,
    expandedInsets: EdgeInsets.zero,
    selectOnly: true,
    label: widget.label == null ? null : Text(widget.label!),
    hintText: widget.hint,
    textStyle: AppControlTheme.textStyle.copyWith(
      fontSize: widget.compact ? 14 : 16,
    ),
    inputDecorationTheme: AppControlTheme.inputDecoration(
      compact: widget.compact,
    ),
    menuHeight: MediaQuery.sizeOf(context).height * 0.5,
    menuStyle: AppControlTheme.menuStyle,
    trailingIcon: const Icon(Icons.expand_more_rounded),
    selectedTrailingIcon: const Icon(Icons.expand_less_rounded),
    onSelected: _select,
    dropdownMenuEntries: [
      for (final item in widget.items)
        DropdownMenuEntry<T>(
          value: item,
          label: _label(item),
          leadingIcon: ExcludeSemantics(
            child: Icon(
              item == widget.value ? Icons.check_rounded : null,
              size: 20,
            ),
          ),
          style: AppControlTheme.menuItemStyle(selected: item == widget.value),
        ),
    ],
  );
}
