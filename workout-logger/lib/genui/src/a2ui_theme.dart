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
  Color seriesColor(int i) => seriesPalette[i % seriesPalette.length];

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
