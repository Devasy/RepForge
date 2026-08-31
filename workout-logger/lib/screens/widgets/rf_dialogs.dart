// rf_dialogs.dart — Reusable RepForge confirmation dialogs and floating toast notifications

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

/// Types of snackbar toast notifications.
enum RFSnackBarType { info, success, warning, error }

extension RFSnackBarContext on BuildContext {
  /// Displays a standardized RepForge floating SnackBar.
  void showRFSnackBar(
    String message, {
    RFSnackBarType type = RFSnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final Color bgColor;
    final Color fgColor;
    final IconData icon;

    switch (type) {
      case RFSnackBarType.success:
        bgColor = AppColors.success;
        fgColor = AppColors.textPrimary; // #F4F4F8 on #00C89B: ~4.6:1 ✓
        icon = Icons.check_circle_outline_rounded;
        break;
      case RFSnackBarType.warning:
        bgColor = AppColors.warning;
        fgColor = const Color(0xFF1A1200); // near-black on #DBA520: >7:1 ✓
        icon = Icons.warning_amber_rounded;
        break;
      case RFSnackBarType.error:
        bgColor = AppColors.error;
        fgColor = AppColors.textPrimary; // #F4F4F8 on #E05040: ~4.7:1 ✓
        icon = Icons.error_outline_rounded;
        break;
      case RFSnackBarType.info:
        bgColor = AppColors.cardHigh;
        fgColor = AppColors.textPrimary; // neutral — unchanged
        icon = Icons.info_outline_rounded;
        break;
    }

    ScaffoldMessenger.of(this).hideCurrentSnackBar();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        content: Row(
          children: [
            Icon(icon, color: fgColor, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Geist',
                  color: fgColor,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One choice in an [showRFActionSheet].
class RFAction<T> {
  const RFAction({
    required this.label,
    required this.value,
    this.description,
    this.icon,
    this.isPrimary = false,
    this.isDanger = false,
  });

  final String label;
  final T value;

  /// One short line under the label saying what the choice does.
  final String? description;
  final IconData? icon;

  /// Renders as the filled brand button. At most one per sheet.
  final bool isPrimary;
  final bool isDanger;
}

/// Bottom sheet for three or more choices, where a dialog's action row wraps.
/// Returns null if dismissed without a choice.
Future<T?> showRFActionSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<RFAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    // Without this the sheet is capped at 9/16 of the viewport. Three actions
    // with descriptions already fill most of that, so at a large text scale
    // the bottom action would be clipped with no way to scroll to it.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grabber
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.glassBorderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Geist',
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Geist',
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            for (final action in actions) ...[
              if (action.isPrimary)
                GlowButton(
                  label: action.label,
                  icon: action.icon,
                  onPressed: () => Navigator.pop(ctx, action.value),
                )
              else
                _SheetChoice<T>(action: action, ctx: ctx),
              if (action != actions.last) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SheetChoice<T> extends StatelessWidget {
  const _SheetChoice({required this.action, required this.ctx});

  final RFAction<T> action;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    final fg = action.isDanger ? AppColors.error : AppColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(ctx, action.value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md - 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.glass2,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
            color: action.isDanger
                ? AppColors.error.withValues(alpha: 0.35)
                : AppColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, size: 18, color: fg),
              const SizedBox(width: AppSpacing.sm + 2),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (action.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      action.description!,
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays a standardized glassmorphic confirm dialog.
Future<bool?> showRFConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String cancelText = 'Cancel',
  String confirmText = 'Confirm',
  bool isDanger = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Geist',
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: Text(
        content,
        style: const TextStyle(
          fontFamily: 'Geist',
          color: AppColors.textSoft,
          fontSize: 14,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            cancelText,
            style: const TextStyle(
              fontFamily: 'Geist',
              color: AppColors.textMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: isDanger ? AppColors.error : AppColors.primary,
          ),
          child: Text(
            confirmText,
            style: TextStyle(
              fontFamily: 'Geist',
              fontWeight: FontWeight.w600,
              color: isDanger ? AppColors.error : AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
}
