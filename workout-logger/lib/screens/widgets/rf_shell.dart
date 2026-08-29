// rf_shell.dart — Screen chrome shared by every RepForge screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

// ── RFIconButton ─────────────────────────────────────────────────────────────
// The glass square icon button used in every screen header. One fill, one size.
class RFIconButton extends StatelessWidget {
  const RFIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.size = standardSize,
  });

  /// The painted box size for every header button. [RFScreenHeader]'s
  /// centred-title counterweight assumes each action is this wide.
  static const double standardSize = 38;

  /// Material's minimum touch target. The painted box stays [size]; the
  /// gesture area is expanded to this when [size] is smaller.
  static const double minTapTarget = 48;

  /// The width a default-size button actually occupies once the tap target is
  /// applied — what a caller laying out around it needs, not [standardSize].
  static const double standardExtent = standardSize > minTapTarget
      ? standardSize
      : minTapTarget;

  final IconData icon;
  final VoidCallback? onTap;

  /// Screen-reader label and tooltip. Always supply one: these are icon-only.
  final String? tooltip;

  /// Tints the icon (e.g. destructive actions). Defaults to soft text.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final target = size < minTapTarget ? minTapTarget : size;
    // InkWell, not a bare GestureDetector: this is the back/close control in
    // every header, so it has to be reachable by keyboard and switch access —
    // the same requirement RFOptionChip states below. The Material is there
    // for headers that sit outside a Scaffold, where InkWell has no ancestor
    // to paint its splash into.
    final button = Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onTap!();
                }
              : null,
          // The gesture area is the full 48pt target; only the decorated box
          // inside it is painted at `size`.
          child: SizedBox(
            width: target,
            height: target,
            child: Center(
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.glass2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: enabled
                      ? (color ?? AppColors.textSoft)
                      : AppColors.textFaint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

// ── RFGradientBadge ──────────────────────────────────────────────────────────
// Small brand-gradient tile — the AI mark in headers, avatars and empty states.
class RFGradientBadge extends StatelessWidget {
  const RFGradientBadge({
    super.key,
    required this.icon,
    this.size = 34,
    this.radius = AppRadius.md,
    this.glow = 0.35,
  });

  final IconData icon;
  final double size;
  final double radius;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow(glow),
            blurRadius: size * 0.4,
            spreadRadius: -size * 0.12,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

// ── RFScreenHeader ───────────────────────────────────────────────────────────
// Leading affordance · optional badge · title/subtitle · actions.
class RFScreenHeader extends StatelessWidget {
  const RFScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badgeIcon,
    this.onBack,
    this.leadingIcon = Icons.arrow_back_rounded,
    this.leadingTooltip = 'Back',
    this.actions = const [],
    this.centreTitle = false,
    this.bottom,
  });

  final String title;
  final String? subtitle;

  /// When set, a brand-gradient badge sits between the back button and title.
  final IconData? badgeIcon;

  /// Omit to hide the leading button entirely (root-level screens).
  final VoidCallback? onBack;
  final IconData leadingIcon;
  final String leadingTooltip;
  final List<Widget> actions;
  final bool centreTitle;

  /// Rendered full-bleed under the header row — e.g. a progress bar.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    // One action = one default-size button plus its 8pt gap.
    //
    // This counterweight is only correct while every action is an
    // RFIconButton at the default size: the header cannot measure its actions
    // before layout, so a caller passing differently-sized actions (as
    // workout_header.dart does) with centreTitle: true will see the title sit
    // off centre. Measure the trailing cluster if that case ever needs to work.
    const cellWidth = RFIconButton.standardExtent + AppSpacing.sm;
    final leadingWidth = onBack != null ? cellWidth : 0.0;
    final trailingWidth = actions.length * cellWidth;

    final titleBlock = Column(
      crossAxisAlignment: centreTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centreTitle ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontFamily: 'Geist',
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centreTitle ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              fontFamily: 'Geist',
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (onBack != null) ...[
                    RFIconButton(
                      icon: leadingIcon,
                      tooltip: leadingTooltip,
                      onTap: onBack,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (badgeIcon != null) ...[
                    RFGradientBadge(icon: badgeIcon!),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // Counterweight, so a centred title lands on true centre.
                  if (centreTitle && trailingWidth > leadingWidth)
                    SizedBox(width: trailingWidth - leadingWidth),
                  Expanded(child: titleBlock),
                  if (centreTitle && leadingWidth > trailingWidth)
                    SizedBox(width: leadingWidth - trailingWidth),
                  for (final action in actions) ...[
                    const SizedBox(width: AppSpacing.sm),
                    action,
                  ],
                ],
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: bottom!,
              ),
          ],
        ),
      ),
    );
  }
}

// ── RFBottomBar ──────────────────────────────────────────────────────────────
// Sticky foot-of-screen action strip. Owns its safe-area inset; never add one.
class RFBottomBar extends StatelessWidget {
  const RFBottomBar({super.key, required this.child});

  final Widget child;

  /// Floor for the space a scroll view must reserve to clear a one-row bar.
  static double clearance(BuildContext context) =>
      72 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 4,
        AppSpacing.md,
        AppSpacing.sm + 4 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: child,
    );
  }
}

// ── RFLabel ──────────────────────────────────────────────────────────────────
// The one uppercase micro-label: headings, captions and overlines share it.
class RFLabel extends StatelessWidget {
  const RFLabel(this.text, {super.key, this.color, this.dim = false});

  final String text;
  final Color? color;

  /// Drops to the faintest text tier — for labels over already-quiet content.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Geist',
        color: color ?? (dim ? AppColors.textFaint : AppColors.textMuted),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── RFOptionChip ─────────────────────────────────────────────────────────────
// A chip the user picks, as opposed to RFChip which only labels.
class RFOptionChip extends StatelessWidget {
  const RFOptionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
    this.icon,
    this.inMutuallyExclusiveGroup = false,
  });

  final String label;

  /// Null renders the chip inert (shown, but not selectable).
  final VoidCallback? onTap;
  final bool selected;

  /// Accent for the selected state. Defaults to the brand violet.
  final Color? color;
  final IconData? icon;

  /// Set when this chip is one of a single-choice group (handle picker,
  /// effort rating) so a screen reader announces it as a radio-style choice
  /// rather than a standalone button. Left false for chips that are just
  /// actions, e.g. the coach's suggested prompts.
  final bool inMutuallyExclusiveGroup;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final enabled = onTap != null;
    final fg = selected
        ? c
        : enabled
        ? AppColors.textSoft
        : AppColors.textFaint;

    return Semantics(
      button: enabled,
      enabled: enabled,
      inMutuallyExclusiveGroup: inMutuallyExclusiveGroup,
      selected: selected,
      label: label,
      // InkWell, not a bare GestureDetector: these need to be reachable by
      // keyboard/switch access and to show a focus + press response, not just
      // fire a haptic.
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: AppSpacing.sm + 1,
          ),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.16) : AppColors.glass2,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected
                  ? c.withValues(alpha: 0.55)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    color: fg,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
