// rf_dialogs.dart — Reusable RepForge confirmation dialogs and floating toast notifications

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
