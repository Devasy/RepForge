import 'package:flutter/material.dart';

// ── AppColors ──────────────────────────────────────────────────────────────
// Single source of truth for all colour tokens. Never use hex literals in
// widget files — always reference AppColors or AppTheme aliases below.
class AppColors {
  const AppColors._();

  // Backgrounds — soft-futurist dark
  static const background = Color(0xFF07070A); // --bg
  static const surface = Color(0xFF0C0C12);    // --bg-1
  static const card = Color(0xFF11111A);        // --bg-2
  static const cardHigh = Color(0xFF1A1A24);   // slightly elevated

  // Glassmorphism surfaces
  static const glass = Color(0x0AFFFFFF);           // --surface  4%
  static const glass2 = Color(0x0FFFFFFF);          // --surface-2 6%
  static const glass3 = Color(0x17FFFFFF);          // --surface-3 9%
  static const glassBorder = Color(0x12FFFFFF);     // --border 7%
  static const glassBorderStrong = Color(0x21FFFFFF); // --border-strong 13%
  static const divider = Color(0x0FFFFFFF);         // 6% white

  // Brand — electric violet primary, cyan data
  static const primary = Color(0xFF7C3AED);         // --accent oklch(0.68 0.18 285)
  static const secondary = Color(0xFF00C2D4);       // --data  oklch(0.78 0.14 200)
  static const accent = Color(0xFF7C3AED);          // alias for primary

  // Semantic
  static const success = Color(0xFF00C89B);         // --success oklch(0.78 0.16 155)
  static const warning = Color(0xFFDBA520);         // --warn   oklch(0.78 0.14 60)
  static const error = Color(0xFFE05040);           // --danger  oklch(0.68 0.20 25)

  // Text — opacity levels over the near-white base #F4F4F8
  static const textPrimary = Color(0xFFF4F4F8);     // --fg
  static const textSoft = Color(0xB8F4F4F8);        // --fg-2 72%
  static const textMuted = Color(0x7AF4F4F8);       // --fg-3 48%
  static const textFaint = Color(0x52F4F4F8);       // --fg-4 32%

  // Glow helpers (use in BoxShadow)
  static Color primaryGlow([double opacity = 0.35]) =>
      primary.withValues(alpha: opacity);
  static Color secondaryGlow([double opacity = 0.35]) =>
      secondary.withValues(alpha: opacity);
  static Color accentGlow([double opacity = 0.35]) =>
      accent.withValues(alpha: opacity);
  static Color successGlow([double opacity = 0.35]) =>
      success.withValues(alpha: opacity);
  static Color warningGlow([double opacity = 0.35]) =>
      warning.withValues(alpha: opacity);

  // Muscle group palette
  static Color muscle(String id) => _muscleColors[id] ?? primary;

  static const Map<String, Color> _muscleColors = {
    'chest': Color(0xFFFF6B6B),
    'upper_chest': Color(0xFFFF8E8E),
    'back': Color(0xFF4ECDC4),
    'lats': Color(0xFF45B7AA),
    'lower_back': Color(0xFF3D9D94),
    'shoulders': Color(0xFF7C3AED),
    'front_delts': Color(0xFF8B7FE8),
    'side_delts': Color(0xFF9D93EA),
    'rear_delts': Color(0xFFAFA6EC),
    'biceps': Color(0xFFFFBE76),
    'triceps': Color(0xFFF9CA24),
    'forearms': Color(0xFFDFB557),
    'quads': Color(0xFF00CEC9),
    'hamstrings': Color(0xFF00B894),
    'glutes': Color(0xFF55EFC4),
    'calves': Color(0xFF81ECEC),
    'core': Color(0xFFFD79A8),
    'traps': Color(0xFFE17055),
  };
}

// ── AppTheme ───────────────────────────────────────────────────────────────
class AppTheme {
  const AppTheme._();

  // Backward-compat aliases
  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.secondary;
  static const Color accentColor = AppColors.accent;
  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;
  static const Color cardColor = AppColors.card;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSoft;
  static const Color textMuted = AppColors.textMuted;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.error;
  static const Map<String, Color> muscleColors = AppColors._muscleColors;

  static Color getMuscleColor(String id) => AppColors.muscle(id);

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      brightness: Brightness.dark,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: 'Geist', 
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.44,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: TextStyle(fontFamily: 'Geist', 
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.textFaint),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.glass2,
        selectedColor: Color(0x267C3AED),
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
        side: const BorderSide(color: AppColors.glassBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardHigh,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      headlineLarge: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.28,
      ),
      headlineMedium: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.12,
      ),
      headlineSmall: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.88,
      ),
      titleLarge: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textSoft,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textPrimary,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textSoft,
        fontSize: 14,
      ),
      bodySmall: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textMuted,
        fontSize: 12,
      ),
      labelLarge: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textPrimary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      labelMedium: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      labelSmall: TextStyle(fontFamily: 'Geist', 
        color: AppColors.textFaint,
        fontSize: 9,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ── Spacing & Radius ────────────────────────────────────────────────────────
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  const AppRadius._();
  static const double xs = 6;     // micro pill, small inner accents
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double button = 14; // standard button shape radius
  static const double xl = 18;    // glass card radius
  static const double xxl = 22;   // nav pill radius
  static const double full = 999;
}

// ── Animation Durations ──────────────────────────────────────────────────────
class AppDurations {
  const AppDurations._();
  /// 100ms — instant toggles, checkbox presses
  static const micro  = Duration(milliseconds: 100);
  /// 150ms — press state feedback, chip selection
  static const fast   = Duration(milliseconds: 150);
  /// 200ms — standard UI transitions (tab switches, card expands)
  static const normal = Duration(milliseconds: 200);
  /// 250ms — slightly heavier containers
  static const moderate = Duration(milliseconds: 250);
  /// 300ms — page & modal slide transitions
  static const medium = Duration(milliseconds: 300);
  /// 600ms — progress rings, loading fills
  static const slow   = Duration(milliseconds: 600);
  /// 800ms — counter roll-up animations
  static const xslow  = Duration(milliseconds: 800);
}

class AppBreakpoints {
  const AppBreakpoints._();

  static const double narrow = 360;
  static const double compact = 600;
  static const double contentMaxWidth = 600;

  static double hPadding(double width) {
    if (width < narrow) return 12;
    if (width < compact) return 20;
    return 32;
  }

  static int gridColumns(double width) => width >= compact ? 4 : 2;

  static double chartHeight(double width) => width < narrow ? 140 : 180;

  static double timerRingSize(double width) => (width * 0.6).clamp(160, 220);

  /// Vertical clearance needed to lift a Scaffold FAB above the custom RFNavBar.
  /// Wrap the FAB in `Padding(padding: EdgeInsets.only(bottom: navBarClearance))`.
  static const double navBarClearance = 80.0;
}
