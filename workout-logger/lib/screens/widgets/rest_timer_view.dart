// rest_timer_view.dart — Full-screen rest timer overlay for WorkoutFlowScreen

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';
import 'rf_shell.dart';

class RestTimerView extends StatelessWidget {
  const RestTimerView({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onAdjust,
    required this.onSkip,
    this.nextExerciseName,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final void Function(int delta) onAdjust;
  final VoidCallback onSkip;
  final String? nextExerciseName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Top hint
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: const RFLabel('Rest'),
            ),
            // Ring + time fills most of the screen
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ringSize = AppBreakpoints.timerRingSize(constraints.maxWidth);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RestTimerRing(
                        remaining: remainingSeconds,
                        total: totalSeconds,
                        size: ringSize,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // Adjust buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _AdjustButton(label: '−30s', onTap: () => onAdjust(-30)),
                          const SizedBox(width: AppSpacing.xl),
                          _AdjustButton(label: '+30s', onTap: () => onAdjust(30)),
                        ],
                      ),
                      if (nextExerciseName != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        const RFLabel('Next up', dim: true),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          nextExerciseName!,
                          style: const TextStyle(
                            color: AppColors.textSoft,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            // Skip button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: OutlineGlowButton(
                label: 'Skip rest',
                onPressed: onSkip,
                color: AppColors.textSoft,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSoft,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
