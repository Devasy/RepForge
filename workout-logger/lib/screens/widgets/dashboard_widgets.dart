// dashboard_widgets.dart — Dashboard-specific helper widgets for home_screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';
import 'rf_cards.dart';

// ── WeekActivityStrip ─────────────────────────────────────────────────────────
// 7-dot strip showing which days this week had a workout.
class WeekActivityStrip extends StatelessWidget {
  const WeekActivityStrip({super.key, required this.sessions});

  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Weekday 1=Mon … 7=Sun; align strip Mon→Sun
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final startOfWeek = todayMidnight.subtract(Duration(days: today.weekday - 1));
    final startOfNextWeek = startOfWeek.add(const Duration(days: 7));
    final trainedDays = sessions
        .where((s) => !s.date.isBefore(startOfWeek) && s.date.isBefore(startOfNextWeek))
        .map((s) => s.date.weekday)
        .toSet();

    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final weekday = i + 1;
        final trained = trainedDays.contains(weekday);
        final isToday = weekday == today.weekday;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: trained
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.card,
                border: Border.all(
                  color: isToday
                      ? AppColors.primary
                      : trained
                          ? AppColors.primary
                          : AppColors.glassBorder,
                  width: isToday ? 2 : 1,
                ),
                boxShadow: trained
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGlow(0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: trained
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              labels[i],
              style: TextStyle(
                color: isToday ? AppColors.primary : AppColors.textMuted,
                fontSize: 10,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── StatGrid ──────────────────────────────────────────────────────────────────
// 2×2 grid of StatGridCards from quick stats map.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.stats});

  final Map<String, dynamic> stats;

  static String _formatVolume(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final weeklyWorkouts = stats['weeklyWorkouts'] ?? 0;
    final weeklyVolume = (stats['weeklyVolume'] ?? 0.0).toDouble();
    final exercisesThisWeek = stats['exercisesThisWeek'] ?? 0;
    final totalWorkouts = stats['totalWorkouts'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatGridCard(
                icon: Icons.fitness_center_rounded,
                value: '$weeklyWorkouts',
                label: 'This Week',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatGridCard(
                icon: Icons.trending_up_rounded,
                value: _formatVolume(settings.toDisplay(weeklyVolume)),
                label: 'Volume (${settings.unitLabel})',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: StatGridCard(
                icon: Icons.bar_chart_rounded,
                value: '$exercisesThisWeek',
                label: 'Exercises',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatGridCard(
                icon: Icons.emoji_events_rounded,
                value: '$totalWorkouts',
                label: 'All Time',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── QuickActionTile ───────────────────────────────────────────────────────────
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: c, size: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── RecentWorkoutsSection ─────────────────────────────────────────────────────
class RecentWorkoutsSection extends StatelessWidget {
  const RecentWorkoutsSection({
    super.key,
    required this.sessions,
    required this.getExerciseName,
    required this.onSeeAll,
    required this.onTap,
  });

  final List<WorkoutSession> sessions;
  final String Function(String) getExerciseName;
  final VoidCallback onSeeAll;
  final void Function(WorkoutSession) onTap;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return RFEmptyState(
        icon: Icons.fitness_center_outlined,
        title: 'No workouts yet',
        subtitle: 'Start your first workout to see it here',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RFSectionHeader(
          'Recent Workouts',
          trailing: TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See All',
              style: TextStyle(color: AppColors.primary, fontSize: 13),
            ),
          ),
        ),
        ...sessions.map(
          (s) => RecentSessionTile(
            session: s,
            getExerciseName: getExerciseName,
            onTap: () => onTap(s),
          ),
        ),
      ],
    );
  }
}
