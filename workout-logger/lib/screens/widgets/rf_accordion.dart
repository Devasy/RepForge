import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shared disclosure control. ExpansionTile provides keyboard accessibility,
/// expansion semantics and removes collapsed child subtrees from the layout.
class RFAccordion extends StatelessWidget {
  const RFAccordion({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = false,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    maintainState: false,
    tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    childrenPadding: const EdgeInsets.only(
      left: AppSpacing.sm,
      right: AppSpacing.sm,
      bottom: AppSpacing.sm,
    ),
    iconColor: AppColors.primary,
    collapsedIconColor: AppColors.textMuted,
    shape: const Border(),
    collapsedShape: const Border(),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    children: children,
  );
}
