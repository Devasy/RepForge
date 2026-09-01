import 'package:flutter/widgets.dart';

/// Visual tokens the A2UI renderer draws with.
///
/// Injected rather than imported so `lib/genui/` carries no dependency on any
/// particular app's design system.
@immutable
class A2UiTheme {
  const A2UiTheme({
    required this.surface,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSoft,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.positive,
    required this.negative,
    required this.seriesPalette,
    required this.spacing,
    required this.radius,
    required this.pillRadius,
  });

  final Color surface;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSoft;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color positive;
  final Color negative;
  final List<Color> seriesPalette;
  final double spacing;
  final double radius;
  final double pillRadius;

  /// Colour for series index [i], cycling through [seriesPalette].
  Color seriesColor(int i) {
    assert(
      seriesPalette.isNotEmpty,
      'seriesPalette must not be empty — seriesColor() indexes into it '
      'with a modulo, which throws on an empty list.',
    );
    if (seriesPalette.isEmpty) return accent;
    return seriesPalette[i % seriesPalette.length];
  }

  /// Neutral dark default so the package renders standalone.
  static const A2UiTheme dark = A2UiTheme(
    surface: Color(0xFF11111A),
    border: Color(0x12FFFFFF),
    divider: Color(0x0FFFFFFF),
    textPrimary: Color(0xFFF4F4F8),
    textSoft: Color(0xB8F4F4F8),
    textMuted: Color(0x7AF4F4F8),
    textFaint: Color(0x52F4F4F8),
    accent: Color(0xFF7C3AED),
    positive: Color(0xFF00C89B),
    negative: Color(0xFFE05040),
    seriesPalette: [
      Color(0xFF7C3AED),
      Color(0xFF00C2D4),
      Color(0xFF00C89B),
      Color(0xFFDBA520),
      Color(0xFFE05040),
    ],
    spacing: 16,
    radius: 16,
    pillRadius: 999,
  );
}

/// Supplies an [A2UiTheme] to the renderer subtree.
///
/// Absent a provider, [of] returns [A2UiTheme.dark] so the package renders
/// standalone in tests and previews.
class A2UiThemeProvider extends InheritedWidget {
  const A2UiThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  final A2UiTheme theme;

  static A2UiTheme of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<A2UiThemeProvider>()
          ?.theme ??
      A2UiTheme.dark;

  @override
  bool updateShouldNotify(A2UiThemeProvider oldWidget) =>
      oldWidget.theme != theme;
}
