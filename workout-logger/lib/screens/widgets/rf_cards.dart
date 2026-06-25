// rf_cards.dart — RepForge card widget variants
// Stateless cards that consume AppColors tokens and rf_widgets primitives.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

// ── SessionCard ───────────────────────────────────────────────────────────────
// History list card: date column | main info | volume.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.getExerciseName,
    this.onTap,
    this.trailing,
    this.synced = false,
  });

  final WorkoutSession session;
  final String Function(String) getExerciseName;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool synced;

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('d').format(session.date);
    final month = DateFormat('MMM').format(session.date).toUpperCase();
    final weekday = DateFormat('EEE').format(session.date).toUpperCase();
    final volume = session.totalVolume;
    final volStr = volume >= 1000
        ? '${(volume / 1000).toStringAsFixed(1)}k'
        : volume.toStringAsFixed(0);

    final exerciseNames = session.exercises
        .take(3)
        .map((e) => getExerciseName(e.exerciseId))
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            // Date column
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, maxWidth: 64),
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekday,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    day,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    month,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              ),
            ),
            // Main info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${session.exercises.length} exercises · ${session.duration} min',
                          style: const TextStyle(
                            color: AppColors.textSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (synced) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.favorite_rounded,
                            size: 12,
                            color: Color(0xFF4ECDC4),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: exerciseNames
                          .map(
                            (n) => RFChip(label: n, small: true),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Volume
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$volStr kg',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── StatGridCard ──────────────────────────────────────────────────────────────
// 2×2 grid tile: icon + value + label. Used on dashboard and summary screen.
class StatGridCard extends StatelessWidget {
  const StatGridCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
    this.animate = true,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    final numericValue = double.tryParse(
      value.replaceAll(RegExp(r'[^0-9.]'), ''),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: c, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          animate && numericValue != null
              ? AnimatedCounter(
                  value: numericValue,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  suffix: value.replaceAll(RegExp(r'[0-9.]'), ''),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── RecentSessionTile ─────────────────────────────────────────────────────────
// Compact recent workout row for the dashboard.
class RecentSessionTile extends StatelessWidget {
  const RecentSessionTile({
    super.key,
    required this.session,
    required this.getExerciseName,
    this.onTap,
  });

  final WorkoutSession session;
  final String Function(String) getExerciseName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d').format(session.date);
    final timeStr = DateFormat('h:mm a').format(session.date);
    final volume = session.totalVolume;
    final volStr = volume >= 1000
        ? '${(volume / 1000).toStringAsFixed(1)}k kg'
        : '${volume.toStringAsFixed(0)} kg';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${session.exercises.length} exercises · $timeStr',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              volStr,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── RoutineCard ───────────────────────────────────────────────────────────────
class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    required this.getExerciseName,
    required this.onStart,
    this.onEdit,
    this.onDelete,
  });

  final Routine routine;
  final String Function(String) getExerciseName;
  final VoidCallback onStart;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final names = routine.exerciseIds.take(3).map(getExerciseName).toList();
    final extra = routine.exerciseIds.length - names.length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${routine.exerciseIds.length} exercises',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    color: AppColors.cardHigh,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSoft,
                    ),
                    onSelected: (v) {
                      if (v == 'edit') onEdit?.call();
                      if (v == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...names.map((n) => RFChip(label: n, small: true)),
                      if (extra > 0)
                        RFChip(
                          label: '+$extra more',
                          small: true,
                          color: AppColors.textSoft,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: onStart,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGlow(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── TargetCard ────────────────────────────────────────────────────────────────
class TargetCard extends StatelessWidget {
  const TargetCard({
    super.key,
    required this.target,
    required this.exerciseName,
    this.onDelete,
  });

  final Target target;
  final String exerciseName;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final pct = (target.progressPercentage * 100).clamp(0, 100);
    final etaStr = target.estimatedCompletionDate != null
        ? DateFormat('MMM d, y').format(target.estimatedCompletionDate!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exerciseName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              RFChip(
                label: target.targetType,
                small: true,
                color: AppColors.secondary,
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${target.currentValue.toStringAsFixed(1)} / ${target.targetValue.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 12,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RFProgressBar(value: target.progressPercentage),
          if (etaStr != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 11, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Est. $etaStr',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── ExerciseCard ──────────────────────────────────────────────────────────────
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.selected = false,
  });

  final Exercise exercise;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final muscleColor = exercise.muscleActivations.isNotEmpty
        ? AppColors.muscle(exercise.muscleActivations.first.muscleGroupId)
        : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: AppSpacing.md),
              decoration: BoxDecoration(
                color: muscleColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (exercise.muscleActivations.isNotEmpty)
                    Text(
                      exercise.primaryMuscle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (exercise.isCustom)
                  const RFChip(
                    label: 'Custom',
                    small: true,
                    color: AppColors.accent,
                  ),
                if (exercise.isCustom) const SizedBox(width: 4),
                RFChip(
                  label: exercise.category,
                  small: true,
                  color: AppColors.textSoft,
                ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
