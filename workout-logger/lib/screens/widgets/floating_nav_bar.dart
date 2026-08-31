// floating_nav_bar.dart — Self-contained floating navigation bar for Flutter.
//
// Redesigned with the "expanding chip" pattern from EssentialsFloatingToolbar:
//   • Selected tab expands horizontally (spring physics) to reveal an inline label
//   • Unselected tabs show icon-only at a fixed compact size
//   • Badge dot support on any nav item
//   • Glassmorphic container — backdrop blur + border + outer glow
//   • Scroll-aware hide/show via FloatingNavBarScaffold
//
// ─── Quick start ──────────────────────────────────────────────────────────────
//
// ```dart
// const items = [
//   FloatingNavItem(icon: Icons.home,   label: 'Home'),
//   FloatingNavItem(icon: Icons.search, label: 'Search'),
//   FloatingNavItem(icon: Icons.person, label: 'Profile'),
// ];
//
// FloatingNavBarScaffold(
//   items: items,
//   currentIndex: _index,
//   onTabChanged: (i) => setState(() => _index = i),
//   body: IndexedStack(index: _index, children: _pages),
// )
// ```
//
// ─── Drop-in dependency ───────────────────────────────────────────────────────
// Only needs the Flutter SDK (material.dart · dart:ui · flutter/physics.dart).

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FloatingNavItem
// ─────────────────────────────────────────────────────────────────────────────

/// A single tab entry for [FloatingNavBar].
///
/// [label] is displayed as an expanding inline text when the tab is active
/// and is also used for screen-reader semantics (TalkBack / VoiceOver).
/// Supply [activeIcon] for a distinct icon when selected.
/// Set [hasBadge] to `true` to render a small red indicator dot.
@immutable
class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.hasBadge = false,
  });

  /// Icon shown when this tab is **inactive**.
  final IconData icon;

  /// Optional icon shown when this tab is **active**. Falls back to [icon].
  final IconData? activeIcon;

  /// Text displayed as an expanding label when active, and used for semantics.
  final String label;

  /// When `true`, a small red dot is painted at the top-right of the icon.
  final bool hasBadge;

  /// Returns the correct icon for the given [active] state.
  IconData iconFor(bool active) => active ? (activeIcon ?? icon) : icon;
}

// ─────────────────────────────────────────────────────────────────────────────
// FloatingNavBarTheme
// ─────────────────────────────────────────────────────────────────────────────

/// Visual and behavioural configuration for [FloatingNavBar] and
/// [FloatingNavBarScaffold].
///
/// All colour fields are nullable — `null` values derive from the ambient
/// [ThemeData.colorScheme] at runtime. Override only what you need.
@immutable
class FloatingNavBarTheme {
  const FloatingNavBarTheme({
    // ── Colours ──────────────────────────────────────────────────────────────
    this.backgroundColor,
    this.backgroundOpacity = 0.82,
    this.borderColor,
    this.borderWidth = 1.2,
    /// Background of the selected tab chip.
    this.selectedChipColor,
    /// Border of the selected tab chip.
    this.selectedChipBorderColor,
    /// Glow shadow of the selected tab chip.
    this.selectedChipShadowColor,
    /// Icon + label colour inside the selected chip.
    this.selectedContentColor,
    this.inactiveIconColor,
    this.outerShadowColor,
    this.outerGlowColor,
    /// Colour of the unread-indicator dot on a badged item.
    this.badgeColor = const Color(0xFFE05040),
    // ── Sizes ────────────────────────────────────────────────────────────────
    this.navHeight = 60.0,
    this.chipHeight = 46.0,
    /// Fixed width of each icon tap cell (active and inactive).
    this.iconCellSize = 48.0,
    /// Extra width that slides open when a chip becomes active (label area).
    this.labelWidth = 80.0,
    this.iconSize = 22.0,
    /// Symmetric horizontal inset inside the container.
    this.horizontalPadding = 8.0,
    /// Gap between adjacent chips.
    this.itemSpacing = 4.0,
    this.blurSigma = 18.0,
    // ── Label ────────────────────────────────────────────────────────────────
    /// Set to `false` to disable label expansion (icon-only compact mode).
    this.showLabels = true,
    /// Override the label [TextStyle]. Colour is always resolved from theme.
    this.labelStyle,
    // ── Spring animation ─────────────────────────────────────────────────────
    /// Spring mass (heavier = slower).
    this.springMass = 1.0,
    /// Spring stiffness (higher = snappier).
    this.springStiffness = 500.0,
    /// Damping ratio: 0.5 = bouncy, 1.0 = critically damped.
    this.springDampingRatio = 0.72,
    /// Duration for collapsing (non-spring ease-in).
    this.collapseDuration = const Duration(milliseconds: 200),
    // ── Show / hide animation ─────────────────────────────────────────────────
    this.showDuration = const Duration(milliseconds: 250),
    this.hideDuration = const Duration(milliseconds: 280),
    this.showCurve = Curves.easeInOutCubic,
    this.hideCurve = Curves.easeInOutCubic,
    // ── Scroll behaviour ─────────────────────────────────────────────────────
    /// Set to false to keep the nav bar permanently visible.
    this.hideOnScroll = true,
    /// Cumulative downward travel, in pixels, before the bar hides.
    this.scrollDownThreshold = 48.0,
    /// Cumulative upward travel before it returns; smaller, so it comes back fast.
    this.scrollUpThreshold = 16.0,
    // ── Misc ─────────────────────────────────────────────────────────────────
    this.bottomMargin = 16.0,
    this.hapticFeedback = true,
    // ── Fallback colour opacities ─────────────────────────────────────────────
    this.defaultBorderOpacity = 0.13,
    this.defaultChipOpacity = 0.10,
    this.defaultChipBorderOpacity = 0.25,
    this.defaultChipShadowOpacity = 0.15,
    this.defaultInactiveOpacity = 0.48,
    this.defaultShadowOpacity = 0.45,
    this.defaultGlowOpacity = 0.08,
    // ── Shadow geometry ───────────────────────────────────────────────────────
    this.outerShadowBlurRadius = 28.0,
    this.outerShadowSpread = -4.0,
    this.outerShadowOffset = const Offset(0, 10),
    this.outerGlowBlurRadius = 32.0,
    // ── Slide animation ───────────────────────────────────────────────────────
    /// Offset applied to [AnimatedSlide] when the nav bar hides.
    this.slideHideOffset = const Offset(0, 1.5),
    /// Fade-out duration = hideDuration × fadeOutDurationFactor.
    this.fadeOutDurationFactor = 0.75,
  });

  // ── Colours ─────────────────────────────────────────────────────────────────
  final Color? backgroundColor;
  final double backgroundOpacity;
  final Color? borderColor;
  final double borderWidth;
  final Color? selectedChipColor;
  final Color? selectedChipBorderColor;
  final Color? selectedChipShadowColor;
  final Color? selectedContentColor;
  final Color? inactiveIconColor;
  final Color? outerShadowColor;
  final Color? outerGlowColor;
  final Color badgeColor;

  // ── Sizes ────────────────────────────────────────────────────────────────────
  final double navHeight;
  final double chipHeight;
  final double iconCellSize;
  final double labelWidth;
  final double iconSize;
  final double horizontalPadding;
  final double itemSpacing;
  final double blurSigma;

  // ── Label ────────────────────────────────────────────────────────────────────
  final bool showLabels;
  final TextStyle? labelStyle;

  // ── Spring animation ─────────────────────────────────────────────────────────
  final double springMass;
  final double springStiffness;
  final double springDampingRatio;
  final Duration collapseDuration;

  // ── Show / hide animation ────────────────────────────────────────────────────
  final Duration showDuration;
  final Duration hideDuration;
  final Curve showCurve;
  final Curve hideCurve;

  // ── Scroll ───────────────────────────────────────────────────────────────────
  final bool hideOnScroll;
  final double scrollDownThreshold;
  final double scrollUpThreshold;

  // ── Misc ─────────────────────────────────────────────────────────────────────
  final double bottomMargin;
  final bool hapticFeedback;

  // ── Fallback opacities ───────────────────────────────────────────────────────
  final double defaultBorderOpacity;
  final double defaultChipOpacity;
  final double defaultChipBorderOpacity;
  final double defaultChipShadowOpacity;
  final double defaultInactiveOpacity;
  final double defaultShadowOpacity;
  final double defaultGlowOpacity;

  // ── Shadow geometry ──────────────────────────────────────────────────────────
  final double outerShadowBlurRadius;
  final double outerShadowSpread;
  final Offset outerShadowOffset;
  final double outerGlowBlurRadius;

  // ── Slide animation ──────────────────────────────────────────────────────────
  final Offset slideHideOffset;
  final double fadeOutDurationFactor;
}

// ─────────────────────────────────────────────────────────────────────────────
// FloatingNavBar — pure stateless presentation widget
// ─────────────────────────────────────────────────────────────────────────────

/// A compact, pill-shaped, glassmorphic navigation bar with expanding chip tabs.
///
/// The selected tab chips open sideways with a spring animation to reveal the
/// tab label; inactive tabs show the icon only. Inspired by the
/// EssentialsFloatingToolbar pattern from the Compose world.
///
/// **Purely presentational** — no internal state, no scroll listening.
///
/// Use [FloatingNavBarScaffold] for the full scroll-aware experience.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.theme = const FloatingNavBarTheme(),
  }) : assert(items.length >= 2, 'FloatingNavBar requires at least 2 items.');

  /// Index of the currently selected tab.
  final int currentIndex;

  /// Called with the tapped tab index.
  final ValueChanged<int> onTap;

  /// Tab definitions. Minimum 2.
  final List<FloatingNavItem> items;

  /// Visual and layout configuration.
  final FloatingNavBarTheme theme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    // Never below bottomMargin, and always a visible gap above any inset.
    final bottomInset =
        bottomPad + 8 > theme.bottomMargin ? bottomPad + 8 : theme.bottomMargin;

    // ── Resolve colours ──────────────────────────────────────────────────────
    final bg = theme.backgroundColor ??
        cs.surface.withValues(alpha: theme.backgroundOpacity);
    final border = theme.borderColor ??
        cs.outline.withValues(alpha: theme.defaultBorderOpacity);
    final chipBg = theme.selectedChipColor ??
        cs.primary.withValues(alpha: theme.defaultChipOpacity);
    final chipContent = theme.selectedContentColor ?? cs.onSurface;
    final inactiveContent = theme.inactiveIconColor ??
        cs.onSurface.withValues(alpha: theme.defaultInactiveOpacity);
    final outerShadow = theme.outerShadowColor ??
        Colors.black.withValues(alpha: theme.defaultShadowOpacity);
    final outerGlow = theme.outerGlowColor ??
        cs.primary.withValues(alpha: theme.defaultGlowOpacity);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        // Clears the system inset and keeps a margin off the gesture handle.
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _ShadowWrapper(
          outerShadow: outerShadow,
          outerGlow: outerGlow,
          shadowBlurRadius: theme.outerShadowBlurRadius,
          shadowSpread: theme.outerShadowSpread,
          shadowOffset: theme.outerShadowOffset,
          glowBlurRadius: theme.outerGlowBlurRadius,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: theme.blurSigma,
                sigmaY: theme.blurSigma,
              ),
              child: Container(
                height: theme.navHeight,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: border, width: theme.borderWidth),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.horizontalPadding,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        _NavCell(
                          item: items[i],
                          active: i == currentIndex,
                          theme: theme,
                          chipBg: chipBg,
                          chipContent: chipContent,
                          inactiveContent: inactiveContent,
                          onTap: () => onTap(i),
                        ),
                        if (i < items.length - 1)
                          SizedBox(width: theme.itemSpacing),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShadowWrapper — outer drop-shadow + ambient glow
// ─────────────────────────────────────────────────────────────────────────────

/// Applies a drop-shadow and ambient glow **outside** the clipped pill shape.
/// Must be a separate widget because [ClipRRect] clips its own BoxDecoration
/// shadows.
class _ShadowWrapper extends StatelessWidget {
  const _ShadowWrapper({
    required this.outerShadow,
    required this.outerGlow,
    required this.shadowBlurRadius,
    required this.shadowSpread,
    required this.shadowOffset,
    required this.glowBlurRadius,
    required this.child,
  });

  final Color outerShadow;
  final Color outerGlow;
  final double shadowBlurRadius;
  final double shadowSpread;
  final Offset shadowOffset;
  final double glowBlurRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: outerShadow,
            blurRadius: shadowBlurRadius,
            spreadRadius: shadowSpread,
            offset: shadowOffset,
          ),
          BoxShadow(color: outerGlow, blurRadius: glowBlurRadius),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavCell — stateful, spring-animated expanding chip
// ─────────────────────────────────────────────────────────────────────────────

/// A single tappable chip inside [FloatingNavBar].
///
/// When [active] becomes `true`, the chip expands rightward using a
/// [SpringSimulation] (bouncy, lively) to reveal the label text.
/// When [active] becomes `false`, the chip collapses with a quick ease-in.
class _NavCell extends StatefulWidget {
  const _NavCell({
    required this.item,
    required this.active,
    required this.theme,
    required this.chipBg,
    required this.chipContent,
    required this.inactiveContent,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool active;
  final FloatingNavBarTheme theme;
  final Color chipBg;
  final Color chipContent;
  final Color inactiveContent;
  final VoidCallback onTap;

  @override
  State<_NavCell> createState() => _NavCellState();
}

class _NavCellState extends State<_NavCell>
    with SingleTickerProviderStateMixin {
  /// Unbounded controller so the spring can overshoot > 1.0 naturally,
  /// producing the satisfying bounce on expansion.
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this)
      ..value = widget.active ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(_NavCell old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;

    if (widget.active) {
      // Spring expand — medium bounce feel, matching DampingRatioMediumBouncy.
      _ctrl.animateWith(
        SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: widget.theme.springMass,
            stiffness: widget.theme.springStiffness,
            ratio: widget.theme.springDampingRatio,
          ),
          _ctrl.value,
          1.0,
          0.0, // initial velocity
        ),
      );
    } else {
      // Quick ease-in collapse — no spring, feels intentional / snappy.
      _ctrl.animateTo(
        0.0,
        duration: widget.theme.collapseDuration,
        curve: Curves.easeIn,
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    return Semantics(
      button: true,
      label: widget.item.label,
      selected: widget.active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (t.hapticFeedback) HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            // Raw spring value — may overshoot [0,1] during bounce.
            final raw = _ctrl.value;

            // Clamped to [0,1] for colour interpolation (no weird colours).
            final colorP = raw.clamp(0.0, 1.0);

            // Width can overshoot slightly for the spring bounce feel.
            // Clamp at 1.2× to prevent excessively wide chips on large oscillation.
            final widthP = raw.clamp(0.0, 1.2);

            // Label fades in during the second half of expansion.
            final labelOpacity = ((colorP - 0.5) * 2.0).clamp(0.0, 1.0);

            // Extra width contributed by the label area.
            final extraW =
                t.showLabels ? widthP * t.labelWidth : 0.0;

            // Right padding inside chip (breathing room for the label).
            final rightPad = t.showLabels ? colorP * 10.0 : 0.0;

            final iconColor = Color.lerp(
              widget.inactiveContent,
              widget.chipContent,
              colorP,
            )!;

            return Container(
              height: t.chipHeight,
              width: (t.iconCellSize + extraW).clamp(
                t.iconCellSize,
                t.iconCellSize + t.labelWidth * 1.2,
              ),
              decoration: BoxDecoration(
                color: Color.lerp(Colors.transparent, widget.chipBg, colorP),
                borderRadius: BorderRadius.circular(9999),
                border: colorP > 0.05
                    ? Border.all(
                        color: (t.selectedChipBorderColor ?? widget.chipContent)
                            .withValues(alpha: 0.28 * colorP),
                        width: 1.0,
                      )
                    : null,
                boxShadow: colorP > 0.05
                    ? [
                        BoxShadow(
                          color:
                              (t.selectedChipShadowColor ?? widget.chipContent)
                                  .withValues(alpha: 0.18 * colorP),
                          blurRadius: 14,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9999),
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Icon (fixed width cell) ──────────────────────────────
                    SizedBox(
                      width: t.iconCellSize,
                      height: t.chipHeight,
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              widget.item.iconFor(widget.active),
                              size: t.iconSize,
                              color: iconColor,
                            ),
                            // Badge dot
                            if (widget.item.hasBadge)
                              Positioned(
                                right: -3,
                                top: -3,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: t.badgeColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      // border matches the chip bg for a
                                      // "punched out" halo effect
                                      color: widget.chipBg,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Expanding label area ─────────────────────────────────
                    if (t.showLabels && extraW > 1.0) ...[
                      Opacity(
                        opacity: labelOpacity,
                        child: Text(
                          widget.item.label,
                          style: (t.labelStyle ??
                                  const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                  ))
                              .copyWith(color: widget.chipContent),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                      SizedBox(width: rightPad),
                    ],
                  ],
                ),
              ),
            ),
          ),
          );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FloatingNavBarScaffold — all-in-one convenience wrapper
// ─────────────────────────────────────────────────────────────────────────────

/// A ready-to-use [Scaffold] that wires [FloatingNavBar] with automatic
/// scroll-aware hide/show logic.
///
/// Scroll notifications propagate from **any** nested scrollable without
/// any [ScrollController] wiring in child widgets.
///
/// ### Visibility rules
/// | Event | Result |
/// |---|---|
/// | Scroll down `> scrollDownThreshold` | Nav hides |
/// | Scroll up `> scrollUpThreshold` | Nav shows |
/// | Scroll reaches position `0` (top) | Nav always shows |
/// | Tab switch via [onTabChanged] | Nav always shows |
///
/// ### Bottom content padding
/// The floating nav overlaps content. Add bottom padding to inner lists:
/// ```dart
/// ListView(
///   padding: EdgeInsets.only(
///     bottom: MediaQuery.of(context).padding.bottom
///           + theme.navHeight
///           + theme.bottomMargin
///           + 8,
///   ),
/// )
/// ```
class FloatingNavBarScaffold extends StatefulWidget {
  const FloatingNavBarScaffold({
    super.key,
    required this.items,
    required this.body,
    required this.currentIndex,
    required this.onTabChanged,
    this.theme = const FloatingNavBarTheme(),
    this.scaffoldBackgroundColor,
  }) : assert(
          items.length >= 2,
          'FloatingNavBarScaffold requires at least 2 items.',
        );

  /// Tab definitions. Minimum 2.
  final List<FloatingNavItem> items;

  /// Main content — typically an [IndexedStack] or [PageView].
  final Widget body;

  /// Currently selected index, managed by the parent.
  final int currentIndex;

  /// Called when the user taps a tab. The parent must update [currentIndex].
  final ValueChanged<int> onTabChanged;

  /// Visual and behavioural config.
  final FloatingNavBarTheme theme;

  /// [Scaffold] background colour.
  final Color? scaffoldBackgroundColor;

  @override
  State<FloatingNavBarScaffold> createState() => _FloatingNavBarScaffoldState();
}

class _FloatingNavBarScaffoldState extends State<FloatingNavBarScaffold> {
  bool _visible = true;

  // ── Tab change — always restore visibility ────────────────────────────────

  void _handleTabChange(int index) {
    _travel = 0;
    if (!_visible) setState(() => _visible = true);
    widget.onTabChanged(index);
  }

  // ── Scroll detection ──────────────────────────────────────────────────────

  /// Travel since the last direction change; positive is down, reset on reversal.
  double _travel = 0;

  bool _handleScrollNotification(ScrollNotification n) {
    if (!widget.theme.hideOnScroll) return false;

    // A settled scroll starts a fresh gesture — don't carry momentum across.
    if (n is ScrollEndNotification) {
      _travel = 0;
      return false;
    }

    if (n is ScrollUpdateNotification) {
      // Ignore overscroll bounce: rubber-banding reads as a drag it isn't.
      final m = n.metrics;
      if (m.pixels < m.minScrollExtent || m.pixels > m.maxScrollExtent) {
        return false;
      }

      final delta = n.scrollDelta ?? 0;
      // Direction reversal restarts the count.
      if (delta.sign != _travel.sign) _travel = 0;
      _travel += delta;

      if (_travel > widget.theme.scrollDownThreshold && _visible) {
        _travel = 0;
        setState(() => _visible = false);
      } else if (-_travel > widget.theme.scrollUpThreshold && !_visible) {
        _travel = 0;
        setState(() => _visible = true);
      }

      // Near the very top → always show. A small band rather than an exact
      // zero, so the bar is already back by the time the bounce settles.
      if (m.pixels <= m.minScrollExtent + 8 && !_visible) {
        _travel = 0;
        setState(() => _visible = true);
      }
    }

    // Never absorb — let notifications keep bubbling.
    return false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Content: scroll notifications propagate upward from here.
          NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: widget.body,
          ),

          // Floating nav bar with slide + fade animation.
          AnimatedSlide(
            offset: _visible ? Offset.zero : widget.theme.slideHideOffset,
            duration: _visible
                ? widget.theme.showDuration
                : widget.theme.hideDuration,
            curve:
                _visible ? widget.theme.showCurve : widget.theme.hideCurve,
            child: AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: _visible
                  ? widget.theme.showDuration
                  : Duration(
                      milliseconds: (widget.theme.hideDuration.inMilliseconds *
                              widget.theme.fadeOutDurationFactor)
                          .round(),
                    ),
              curve:
                  _visible ? widget.theme.showCurve : widget.theme.hideCurve,
              // Disable hit-testing when fully hidden.
              child: IgnorePointer(
                ignoring: !_visible,
                child: FloatingNavBar(
                  currentIndex: widget.currentIndex,
                  onTap: _handleTabChange,
                  items: widget.items,
                  theme: widget.theme,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
