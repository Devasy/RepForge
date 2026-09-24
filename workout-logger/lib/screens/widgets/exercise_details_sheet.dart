// exercise_details_sheet.dart — Bottom sheet showing exercise detail & stats

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../services/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../data/exercise_database.dart';
import '../add_custom_exercise_screen.dart';
import 'rf_widgets.dart';

class ExerciseDetailsSheet extends StatelessWidget {
  const ExerciseDetailsSheet({
    super.key,
    required this.exercise,
    required this.provider,
  });

  final Exercise exercise;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final lastSession = provider.getLastSessionForExercise(exercise.id);
    final growthModel = provider.getGrowthModel(exercise.id);
    final color = exercise.isCustom ? AppColors.warning : AppColors.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  exercise.exerciseType == ExerciseType.timeBased
                      ? Icons.timer_rounded
                      : (exercise.category == 'compound'
                          ? Icons.fitness_center_rounded
                          : Icons.accessibility_new_rounded),
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        RFChip(
                          label: exercise.category,
                          small: true,
                          color: AppColors.primary,
                        ),
                        RFChip(
                          label: exercise.exerciseType.displayName,
                          small: true,
                          color: AppColors.cyan,
                        ),
                        if (exercise.isCustom) ...[
                          const RFChip(
                            label: 'Custom',
                            small: true,
                            color: AppColors.warning,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  Navigator.of(context).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddCustomExerciseScreen(
                        initialExercise: exercise,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              if (exercise.isCustom)
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),

          // Available Attachments
          if (exercise.availableHandles != null &&
              exercise.availableHandles!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const RFSectionHeader('Available Attachments'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: exercise.availableHandles!.map((h) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardHigh,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded, size: 13, color: AppColors.cyan),
                    const SizedBox(width: 4),
                    Text(
                      h,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Muscle activations
          const RFSectionHeader('Muscle Activation'),
          const SizedBox(height: AppSpacing.sm),
          ...exercise.muscleActivations.map((a) {
            final muscleColor = AppColors.muscle(a.muscleGroupId);
            final name = MuscleGroups.names[a.muscleGroupId] ?? a.muscleGroupId;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: muscleColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: RFProgressBar(
                      value: a.activationPercentage / 100,
                      color: muscleColor,
                      height: 6,
                      showGlow: false,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${a.activationPercentage}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: muscleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Last session
          if (lastSession != null) ...[
            const SizedBox(height: AppSpacing.md),
            const RFSectionHeader('Last Session'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: lastSession.sets.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    (exercise.exerciseType == ExerciseType.timeBased && (s.timeTaken ?? 0) > 0)
                        ? '${s.timeTaken}s${s.weight > 0 ? " (+${settings.toDisplay(s.weight).toStringAsFixed(0)}${settings.unitLabel})" : ""}'
                        : '${settings.toDisplay(s.weight).toStringAsFixed(settings.toDisplay(s.weight) == settings.toDisplay(s.weight).truncateToDouble() ? 0 : 1)}${settings.unitLabel} × ${s.reps}',
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Growth trend
          if (growthModel != null && growthModel.r2 > 0.2) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '+${settings.toDisplay(growthModel.slope * 7).toStringAsFixed(1)} ${settings.unitLabel} volume/week',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'R² ${(growthModel.r2 * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Delete Exercise?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Delete "${exercise.name}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSoft),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);
      final success = await provider.deleteCustomExercise(exercise.id);
      if (success && context.mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('"${exercise.name}" deleted'),
            backgroundColor: AppColors.cardHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      } else if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('"${exercise.name}" could not be deleted'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      }
    }
  }
}
