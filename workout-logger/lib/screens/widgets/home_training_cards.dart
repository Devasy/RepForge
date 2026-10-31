import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import 'body_heatmap.dart';
import 'rf_widgets.dart';

class TrainingStreakCard extends StatelessWidget {
  const TrainingStreakCard({
    super.key,
    required this.streak,
    required this.weekStart,
    required this.workoutDays,
    required this.todayIndex,
    required this.isActive,
    required this.onStart,
  });

  final int streak;
  final DateTime weekStart;
  final List<bool> workoutDays;
  final int todayIndex;
  final bool isActive;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Streak',
            style: TextStyle(fontSize: 14, color: AppColors.textSoft),
          ),
          const SizedBox(height: 8),
          _StreakFigure(streak: streak),
          const SizedBox(height: 8),
          Text(
            streak == 0
                ? 'Start your streak today'
                : 'Your current training streak',
            style: const TextStyle(fontSize: 14, color: AppColors.textSoft),
          ),
          const SizedBox(height: 20),
          _TrainingWeek(
            weekStart: weekStart,
            workoutDays: workoutDays,
            todayIndex: todayIndex,
          ),
          const SizedBox(height: 20),
          GlowButton(
            label: isActive ? 'Resume workout' : 'Start workout',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _StreakFigure extends StatelessWidget {
  const _StreakFigure({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      Text(
        '$streak',
        style: const TextStyle(
          fontFamily: 'GeistMono',
          fontSize: 48,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      Text(
        streak == 1 ? 'day' : 'days',
        style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
      ),
    ],
  );
}

class _TrainingWeek extends StatelessWidget {
  const _TrainingWeek({
    required this.weekStart,
    required this.workoutDays,
    required this.todayIndex,
  });
  final DateTime weekStart;
  final List<bool> workoutDays;
  final int todayIndex;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 7; i++)
        Expanded(
          child: _TrainingDay(
            day: weekStart.add(Duration(days: i)),
            done: workoutDays[i],
            isToday: i == todayIndex,
          ),
        ),
    ],
  );
}

class _TrainingDay extends StatelessWidget {
  const _TrainingDay({
    required this.day,
    required this.done,
    required this.isToday,
  });
  final DateTime day;
  final bool done;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final dayLabel = DateFormat('EEEE, MMM d').format(day);
    return Semantics(
      label:
          '$dayLabel: ${done ? "workout logged" : "no workout logged"}${isToday ? ", today" : ""}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Text(
              letters[day.weekday - 1],
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: done ? AppColors.primary : AppColors.cardHigh,
                borderRadius: BorderRadius.circular(4),
                border: isToday ? Border.all(color: AppColors.textSoft) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeeklyMuscleVolumeCard extends StatelessWidget {
  const WeeklyMuscleVolumeCard({
    super.key,
    required this.volumes,
    required this.unitLabel,
  });
  final Map<String, double> volumes;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final maxVolume = volumes.values.fold<double>(
      0,
      (max, value) => value.isFinite && value > max ? value : max,
    );
    final entries = volumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final normalized = {
      for (final entry in entries)
        entry.key: maxVolume > 0 && entry.value.isFinite
            ? entry.value / maxVolume
            : 0.0,
    };
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text(
                'Weekly muscle volume',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                unitLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MuscleVolumeBody(
            normalized: normalized,
            entries: entries.take(5).toList(),
            maxVolume: maxVolume,
          ),
        ],
      ),
    );
  }
}

class _MuscleVolumeBody extends StatelessWidget {
  const _MuscleVolumeBody({
    required this.normalized,
    required this.entries,
    required this.maxVolume,
  });
  final Map<String, double> normalized;
  final List<MapEntry<String, double>> entries;
  final double maxVolume;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final body = BodyHeatmapWidget(muscleVolumes: normalized);
      final rows = _MuscleVolumeRows(entries: entries, maxVolume: maxVolume);
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [body, const SizedBox(height: 16), rows],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          const SizedBox(width: 16),
          Expanded(child: rows),
        ],
      );
    },
  );
}

class _MuscleVolumeRows extends StatelessWidget {
  const _MuscleVolumeRows({required this.entries, required this.maxVolume});
  final List<MapEntry<String, double>> entries;
  final double maxVolume;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (entries.isEmpty)
        const Text('No data yet', style: TextStyle(color: AppColors.textMuted)),
      for (final entry in entries)
        _MuscleVolumeRow(entry: entry, maxVolume: maxVolume),
    ],
  );
}

class _MuscleVolumeRow extends StatelessWidget {
  const _MuscleVolumeRow({required this.entry, required this.maxVolume});
  final MapEntry<String, double> entry;
  final double maxVolume;

  @override
  Widget build(BuildContext context) {
    final name = entry.key.replaceAll('_', ' ');
    final label = name.isEmpty
        ? name
        : '${name[0].toUpperCase()}${name.substring(1)}';
    final volume = entry.value >= 1000
        ? '${(entry.value / 1000).toStringAsFixed(1)}k'
        : entry.value.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
              ),
              Text(
                volume,
                style: const TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RFProgressBar(
            value: maxVolume > 0 ? entry.value / maxVolume : 0,
            color: AppColors.muscle(entry.key),
            height: 4,
          ),
        ],
      ),
    );
  }
}
