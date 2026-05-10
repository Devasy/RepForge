import 'package:flutter/material.dart';

// ── AppColors ──────────────────────────────────────────────────────────────
// Single source of truth for all colour tokens. Never use hex literals in
// widget files — always reference AppColors or AppTheme aliases below.
class AppColors {
  const AppColors._();

  // Backgrounds
  static const background = Color(0xFF080B10);
  static const surface = Color(0xFF0F1318);
  static const card = Color(0xFF161B22);
  static const cardHigh = Color(0xFF1C2333);

  // Glassmorphism
  static const glass = Color(0x0AFFFFFF); // 4 % white
  static const glassBorder = Color(0x14FFFFFF); // 8 % white
  static const divider = Color(0x0FFFFFFF); // 6 % white

  // Brand
  static const primary = Color(0xFF6C5CE7);
  static const secondary = Color(0xFF00D9FF);
  static const accent = Color(0xFFFF6B6B);

  // Semantic
  static const success = Color(0xFF00D26A);
  static const warning = Color(0xFFFFB800);
  static const error = Color(0xFFFF4757);

  // Text
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSoft = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);

  // Glow helpers (use in BoxShadow)
  static Color primaryGlow([double opacity = 0.35]) =>
      primary.withValues(alpha: opacity);
  static Color secondaryGlow([double opacity = 0.35]) =>
      secondary.withValues(alpha: opacity);
  static Color accentGlow([double opacity = 0.35]) =>
      accent.withValues(alpha: opacity);

  // Muscle group palette
  static Color muscle(String id) => _muscleColors[id] ?? primary;

  static const Map<String, Color> _muscleColors = {
    'chest': Color(0xFFFF6B6B),
    'upper_chest': Color(0xFFFF8E8E),
    'back': Color(0xFF4ECDC4),
    'lats': Color(0xFF45B7AA),
    'lower_back': Color(0xFF3D9D94),
    'shoulders': Color(0xFF6C5CE7),
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
// Backward-compat aliases + ThemeData builder.
class AppTheme {
  const AppTheme._();

  // Aliases (keep existing callsites compiling during migration)
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
    return ThemeData(
      useMaterial3: true,
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
        onSecondary: Colors.black,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSoft,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: Color(0x4D6C5CE7),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardHigh,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: AppColors.textSoft,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textSoft, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.textMuted, fontSize: 12),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
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
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
}
