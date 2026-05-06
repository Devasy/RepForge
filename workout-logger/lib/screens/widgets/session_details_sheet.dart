// session_details_sheet.dart — Bottom sheet showing full workout session detail

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

const Color _hcColor = Color(0xFF4ECDC4);

class SessionDetailsSheet extends StatelessWidget {
  const SessionDetailsSheet({
    super.key,
    required this.session,
    required this.provider,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkoutSession session;
  final WorkoutProvider provider;
  final ScrollController scrollController;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(session.date);
    final timeStr = DateFormat('h:mm a').format(session.date);
    final totalSets = session.exercises.fold<int>(0, (s, e) => s + e.sets.length);
    final volume = session.totalVolume;
    final volStr = volume >= 1000
        ? '${(volume / 1000).toStringAsFixed(1)}k'
        : volume.toStringAsFixed(0);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        // Handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Date + actions row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$timeStr · ${session.duration} min',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      if (session.hcSyncedAt != null) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message:
                              'Synced ${DateFormat('MMM d, h:mm a').format(session.hcSyncedAt!)}',
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 13,
                            color: _hcColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _ActionChip(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: AppColors.primary,
                  onTap: onEdit,
                ),
                const SizedBox(width: AppSpacing.sm),
                _ActionChip(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: AppColors.error,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // Stat banner
        Row(
          children: [
            Expanded(
              child: _StatBannerBox(
                value: '${session.exercises.length}',
                label: 'Exercises',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatBannerBox(
                value: '$totalSets',
                label: 'Sets',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatBannerBox(
                value: volStr,
                label: 'Volume kg',
                color: AppColors.success,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        const RFSectionHeader('Exercises'),
        const SizedBox(height: AppSpacing.sm),

        ...session.exercises.map(
          (log) => _ExerciseDetailCard(log: log, provider: provider),
        ),

        if (session.notes != null && session.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          const RFSectionHeader('Notes'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              session.notes!,
              style: const TextStyle(
                color: AppColors.textSoft,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Stat banner box ───────────────────────────────────────────────────────────
class _StatBannerBox extends StatelessWidget {
  const _StatBannerBox({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Action chip button ────────────────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exercise detail card ───────────────────────────────────────────────────────
class _ExerciseDetailCard extends StatelessWidget {
  const _ExerciseDetailCard({required this.log, required this.provider});

  final ExerciseLog log;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final exercise = provider.getExercise(log.exerciseId);
    final name = exercise?.name ?? 'Unknown Exercise';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise name header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${log.sets.length} sets',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Set rows
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: log.sets.asMap().entries.map((entry) {
                return _SetRow(index: entry.key, set: entry.value);
              }).toList(),
            ),
          ),
          // Total
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.md),
                bottomRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Total ',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                Text(
                  '${log.totalVolume.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

// ── Individual set row ────────────────────────────────────────────────────────
class _SetRow extends StatelessWidget {
  const _SetRow({required this.index, required this.set});
  final int index;
  final WorkoutSet set;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${set.weight} kg × ${set.reps} reps',
              style: const TextStyle(
                color: AppColors.textSoft,
                fontSize: 13,
              ),
            ),
          ),
          if (set.isDropset)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DROP',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Text(
            '${set.volume.toStringAsFixed(0)} kg',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
