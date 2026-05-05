import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color tokens ────────────────────────────────────────────────────────────

class AppColors {
  // Backgrounds
  static const Color bg = Color(0xFF07070A);
  static const Color bg1 = Color(0xFF0C0C12);
  static const Color bg2 = Color(0xFF11111A);

  // Surfaces (layered translucent white)
  static const Color surface = Color(0x0AFFFFFF);   // 4%
  static const Color surface2 = Color(0x0FFFFFFF);  // 6%
  static const Color surface3 = Color(0x17FFFFFF);  // 9%

  // Borders
  static const Color border = Color(0x12FFFFFF);       // 7%
  static const Color borderStrong = Color(0x21FFFFFF); // 13%

  // Foreground
  static const Color fg = Color(0xFFF4F4F8);
  static const Color fg2 = Color(0xB8F4F4F8); // 72%
  static const Color fg3 = Color(0x7AF4F4F8); // 48%
  static const Color fg4 = Color(0x52F4F4F8); // 32%

  // Accent — electric violet (oklch 0.68 0.18 285)
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accentSoft = Color(0x268B5CF6); // 15%

  // Data — cyan (oklch 0.78 0.14 200)
  static const Color data = Color(0xFF22D3EE);
  static const Color dataSoft = Color(0x2622D3EE);

  // Semantic
  static const Color success = Color(0xFF34D399); // mint
  static const Color warn = Color(0xFFFBBF24);    // amber
  static const Color danger = Color(0xFFF87171);  // coral

  // Muscle group palette (unchanged from original)
  static const Map<String, Color> muscleGroupColors = {
    'chest': Color(0xFFFF6B6B),
    'upper_chest': Color(0xFFFF8E8E),
    'back': Color(0xFF4ECDC4),
    'lats': Color(0xFF45B7AA),
    'lower_back': Color(0xFF3D9D94),
    'shoulders': Color(0xFF8B5CF6),
    'front_delts': Color(0xFF9D88F0),
    'side_delts': Color(0xFFAFA6EC),
    'rear_delts': Color(0xFFBFBAEE),
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

  static Color getMuscleColor(String muscleId) =>
      muscleGroupColors[muscleId] ?? accent;

  // Backwards-compatible aliases used by older screens
  static const Color primaryColor = accent;
  static const Color secondaryColor = data;
  static const Color accentColor = danger;
  static const Color backgroundColor = bg;
  static const Color surfaceColor = bg1;
  static const Color cardColor = bg2;
  static const Color textPrimary = fg;
  static const Color textSecondary = fg2;
  static const Color textMuted = fg4;
  static const Color successColor = success;
  static const Color warningColor = warn;
  static const Color errorColor = danger;
}

// ─── Spacing & radius ────────────────────────────────────────────────────────

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 18;
  static const double xxl = 24;
  static const double full = 999;
}

// ─── Typography helpers ───────────────────────────────────────────────────────

class AppFonts {
  static TextStyle geist({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.fg,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.geist(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle mono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.fg,
    double? letterSpacing,
  }) =>
      GoogleFonts.geistMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing ?? -0.02,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

// ─── Theme ───────────────────────────────────────────────────────────────────

class AppTheme {
  // Keep legacy static getters for backward compat with existing screens
  static const Color primaryColor = AppColors.accent;
  static const Color secondaryColor = AppColors.data;
  static const Color accentColor = AppColors.danger;
  static const Color backgroundColor = AppColors.bg;
  static const Color surfaceColor = AppColors.bg1;
  static const Color cardColor = AppColors.bg2;
  static const Color textPrimary = AppColors.fg;
  static const Color textSecondary = AppColors.fg2;
  static const Color textMuted = AppColors.fg4;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warn;
  static const Color error = AppColors.danger;

  static const Map<String, Color> muscleColors = AppColors.muscleGroupColors;
  static Color getMuscleColor(String muscleId) =>
      AppColors.getMuscleColor(muscleId);

  static ThemeData get darkTheme {
    final base = GoogleFonts.geistTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.data,
        surface: AppColors.bg1,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: AppColors.fg,
        onError: Colors.white,
      ),

      textTheme: base.copyWith(
        headlineLarge: base.headlineLarge?.copyWith(
          color: AppColors.fg,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.04,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          color: AppColors.fg,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.04,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          color: AppColors.fg,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02,
        ),
        titleLarge: base.titleLarge?.copyWith(
          color: AppColors.fg,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02,
        ),
        titleMedium: base.titleMedium?.copyWith(
          color: AppColors.fg,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: base.titleSmall?.copyWith(
          color: AppColors.fg2,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          color: AppColors.fg,
          fontSize: 15,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          color: AppColors.fg2,
          fontSize: 13,
        ),
        bodySmall: base.bodySmall?.copyWith(
          color: AppColors.fg3,
          fontSize: 11,
        ),
        labelLarge: base.labelLarge?.copyWith(
          color: AppColors.fg,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelSmall: base.labelSmall?.copyWith(
          color: AppColors.fg3,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.fg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.fg,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.fg,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.fg4),
        labelStyle: const TextStyle(color: AppColors.fg3),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accentSoft,
        labelStyle: const TextStyle(color: AppColors.fg, fontSize: 12),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bg2,
        contentTextStyle: const TextStyle(color: AppColors.fg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.accent : AppColors.fg3),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.accentSoft : AppColors.surface3),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      listTileTheme: const ListTileThemeData(
        textColor: AppColors.fg,
        iconColor: AppColors.fg3,
        tileColor: Colors.transparent,
      ),

      iconTheme: const IconThemeData(color: AppColors.fg2, size: 20),
    );
  }
}
