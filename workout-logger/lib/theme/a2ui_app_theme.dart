import '../genui/src/a2ui_theme.dart';
import 'app_theme.dart';

/// Maps RepForge design tokens onto the domain-free [A2UiTheme] the GenUI
/// renderer consumes. This adapter is the only place the two systems meet.
const A2UiTheme repforgeA2UiTheme = A2UiTheme(
  surface: AppColors.card,
  border: AppColors.glassBorder,
  divider: AppColors.divider,
  textPrimary: AppColors.textPrimary,
  textSoft: AppColors.textSoft,
  textMuted: AppColors.textMuted,
  textFaint: AppColors.textFaint,
  accent: AppColors.primary,
  positive: AppColors.success,
  negative: AppColors.error,
  seriesPalette: [
    AppColors.primary,
    AppColors.secondary,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
  ],
  spacing: AppSpacing.md,
  radius: AppRadius.lg,
  pillRadius: AppRadius.full,
);
