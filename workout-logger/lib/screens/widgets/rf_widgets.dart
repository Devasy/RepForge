// rf_widgets.dart — RepForge primitive widget library
// All widgets consume AppColors/AppSpacing/AppRadius tokens only.

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

// ── Route helper ──────────────────────────────────────────────────────────────
// Right-to-left slide push, shared by the home screen and detail entry points.
PageRouteBuilder<T> slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 300),
  );
}

// ── GlassCard ───────────────────────────────────────────────────────────────
// Soft-futurist glass card — gradient top-to-bottom + subtle inner highlight.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.glowColor,
    this.borderColor,
    this.accentBorder = false,
    this.onTap,
    this.semanticsLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? glowColor;
  final Color? borderColor;
  /// When true, uses accent colour border (e.g. Analytics exercise selector).
  final bool accentBorder;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.xl);
    final effectiveBorderColor = accentBorder
        ? AppColors.primary
        : (borderColor ?? AppColors.glassBorder);

    final decoration = BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x09FFFFFF), Color(0x04FFFFFF)],
      ),
      borderRadius: radius,
      border: Border.all(color: effectiveBorderColor, width: 1),
      boxShadow: glowColor != null
          ? [
              BoxShadow(
                color: glowColor!.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ]
          : null,
    );

    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      margin: margin,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: content,
      ),
    );
  }
}

// ── AmbientGlow ──────────────────────────────────────────────────────────────
// Decorative ambient gradient wash — place inside a Stack as first child.
// Matches the design's rf-ambient pseudo-elements.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({super.key, this.showBottom = true});
  final bool showBottom;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Top violet wash
            Positioned(
              top: -120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 480,
                  height: 480,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF5B21B6).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.6],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom cyan wash
            if (showBottom)
              Positioned(
                bottom: -200,
                right: -100,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.secondary.withValues(alpha: 0.20),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.6],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── RFNavBar ─────────────────────────────────────────────────────────────────
// Premium floating glassmorphic bottom navigation bar with perfect rounded blur,
// deep drop shadow, and clean transparent padding so it sits elegantly above the content.
class RFNavBar extends StatelessWidget {
  const RFNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<RFNavItem> items;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      color: Colors.transparent, // Completely transparent outer container
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        bottomPadding > 0 ? bottomPadding + 8 : 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 28,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8), // Sleek transparent surface
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(
                  color: AppColors.glassBorderStrong,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (i) {
                  final active = i == currentIndex;
                  return _NavItem(
                    item: items[i],
                    active: active,
                    onTap: () => onTap(i),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RFNavItem {
  const RFNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final RFNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Accent indicator above icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 18 : 0,
                height: 2,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: AppColors.primary,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              Icon(
                item.icon,
                size: 19,
                color: active ? AppColors.textPrimary : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: GoogleFonts.geist(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? AppColors.textPrimary : AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── GlowButton ──────────────────────────────────────────────────────────────
// Full-width primary action button with glow shadow + haptic feedback.
class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
    this.fullWidth = true,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final bool fullWidth;
  final bool small;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTapDown(TapDownDetails _) async {
    await _ctrl.reverse();
  }

  Future<void> _onTapUp(TapUpDetails _) async {
    HapticFeedback.heavyImpact();
    await _ctrl.forward();
    if (!mounted) return;
    widget.onPressed?.call();
  }

  Future<void> _onTapCancel() async {
    await _ctrl.forward();
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    final disabled = widget.onPressed == null;
    final vPad = widget.small ? 12.0 : 18.0;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          onTapDown: disabled ? null : _onTapDown,
          onTapUp: disabled ? null : _onTapUp,
          onTapCancel: disabled ? null : _onTapCancel,
          child: Container(
            width: widget.fullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: vPad,
            ),
            decoration: BoxDecoration(
              color: disabled ? AppColors.glass2 : color,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: disabled
                  ? Border.all(color: AppColors.glassBorder)
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1,
                    ),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 32,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize:
                  widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: disabled ? AppColors.textMuted : Colors.white,
                    size: widget.small ? 18 : 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: disabled ? AppColors.textMuted : Colors.white,
                    fontSize: widget.small ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── OutlineGlowButton ────────────────────────────────────────────────────────
class OutlineGlowButton extends StatelessWidget {
  const OutlineGlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
    this.fullWidth = false,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final bool fullWidth;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final vPad = small ? 10.0 : 14.0;
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c, width: 1.5),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: vPad,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        icon: icon != null
            ? Icon(icon, size: small ? 16 : 18)
            : const SizedBox.shrink(),
        label: Text(
          label,
          style: TextStyle(
            fontSize: small ? 13 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── RFChip ───────────────────────────────────────────────────────────────────
// Pill-shaped label chip — muscle tags, category badges, etc.
class RFChip extends StatelessWidget {
  const RFChip({
    super.key,
    required this.label,
    this.color,
    this.small = false,
  });

  final String label;
  final Color? color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: c.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── RFSectionHeader ──────────────────────────────────────────────────────────
class RFSectionHeader extends StatelessWidget {
  const RFSectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.bottomPad = true,
  });

  final String title;
  final Widget? trailing;
  final bool bottomPad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad ? AppSpacing.sm : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── RFStatBox ────────────────────────────────────────────────────────────────
class RFStatBox extends StatelessWidget {
  const RFStatBox({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.delta,
  });

  final String value;
  final String label;
  final Color? color;
  final double? delta; // positive = up, negative = down, null = no arrow

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: c,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: 4),
              Icon(
                delta! >= 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 14,
                color: delta! >= 0 ? AppColors.success : AppColors.error,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── AnimatedCounter ──────────────────────────────────────────────────────────
// Smoothly animates a number from 0 to [value] on first build.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 800),
  });

  final double value;
  final TextStyle? style;
  final int decimals;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final display = decimals > 0
            ? v.toStringAsFixed(decimals)
            : v.toInt().toString();
        return Text(
          '$display$suffix',
          style: style ??
              const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
        );
      },
    );
  }
}

// ── MetricHero ───────────────────────────────────────────────────────────────
// Large monospace number + small label — for weights, reps, PRs.
class MetricHero extends StatelessWidget {
  const MetricHero({
    super.key,
    required this.value,
    required this.unit,
    this.color,
    this.size = 48,
  });

  final String value;
  final String unit;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.textPrimary,
            fontSize: size,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
            height: 1.0,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Text(
            unit,
            style: TextStyle(
              color: (color ?? AppColors.textPrimary).withValues(alpha: 0.6),
              fontSize: size * 0.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── RFDivider ────────────────────────────────────────────────────────────────
class RFDivider extends StatelessWidget {
  const RFDivider({super.key, this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.divider,
      thickness: 1,
      height: 1,
      indent: indent,
    );
  }
}

// ── RFEmptyState ─────────────────────────────────────────────────────────────
class RFEmptyState extends StatelessWidget {
  const RFEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(icon, size: 32, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── RFLoadingDots ─────────────────────────────────────────────────────────────
class RFLoadingDots extends StatefulWidget {
  const RFLoadingDots({super.key, this.color});
  final Color? color;

  @override
  State<RFLoadingDots> createState() => _RFLoadingDotsState();
}

class _RFLoadingDotsState extends State<RFLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.primary;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
            final opacity = math.sin(phase * math.pi).clamp(0.2, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── RFProgressBar ─────────────────────────────────────────────────────────────
class RFProgressBar extends StatelessWidget {
  const RFProgressBar({
    super.key,
    required this.value, // 0.0 – 1.0
    this.color,
    this.height = 6,
    this.showGlow = true,
  });

  final double value;
  final Color? color;
  final double height;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final clamped = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * clamped,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.white, 0.2)!]),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: showGlow
                      ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── RestTimerRing ────────────────────────────────────────────────────────────
// Circular countdown ring for rest timer.
class RestTimerRing extends StatelessWidget {
  const RestTimerRing({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 200,
  });

  final int remaining;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    final label =
        mins > 0 ? '$mins:${secs.toString().padLeft(2, '0')}' : '$secs';

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress: progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'REST',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: size * 0.08,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.card
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    final sweep = 2 * math.pi * progress;
    final paint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── SkeletonBox ──────────────────────────────────────────────────────────────
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final double? borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.card, AppColors.cardHigh, _ctrl.value),
          borderRadius: BorderRadius.circular(
            widget.borderRadius ?? AppRadius.sm,
          ),
        ),
      ),
    );
  }
}
