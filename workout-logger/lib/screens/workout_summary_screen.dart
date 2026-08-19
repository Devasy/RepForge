// workout_summary_screen.dart — Post-workout celebration & summary screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../services/managers/pr_manager.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/rf_cards.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.session,
    this.newPRs = const [],
  });

  final WorkoutSession session;
  final List<NewPRResult> newPRs;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();
    final totalSets = session.exercises.fold<int>(
      0,
      (sum, e) => sum + e.sets.length,
    );
    final volume = settings.toDisplay(session.totalVolume);
    final volStr = volume >= 1000
        ? '${(volume / 1000).toStringAsFixed(1)}k'
        : volume.toStringAsFixed(0);

    // Collect unique muscles from all exercises
    final muscles = <String>{};
    for (final log in session.exercises) {
      final exercise = provider.getExercise(log.exerciseId);
      if (exercise != null) {
        for (final activation in exercise.muscleActivations) {
          muscles.add(activation.muscleGroupId);
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    _buildTrophyHeader(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildStatGrid(
                      session.duration,
                      volStr,
                      totalSets,
                      session.exercises.length,
                      settings.unitLabel,
                    ),
                    if (newPRs.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _buildPRSection(newPRs, provider),
                    ],
                    if (muscles.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _buildMusclesSection(muscles, provider),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _buildExerciseSummary(session, provider),
                    const SizedBox(height: AppSpacing.lg),
                    _EffortChipRow(session: session),
                    const SizedBox(height: AppSpacing.xl),
                    GlowButton(
                      label: 'Done',
                      icon: Icons.check_rounded,
                      onPressed: () => Navigator.of(context)
                          .popUntil((r) => r.isFirst),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrophyHeader(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMM d').format(session.date);
    return Column(
      children: [
        // Glowing trophy icon
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.warning.withValues(alpha: 0.3),
                AppColors.warning.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: 0.4),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            size: 48,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Workout Complete!',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid(
    int duration,
    String volume,
    int sets,
    int exercises,
    String unitLabel,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatGridCard(
                icon: Icons.timer_outlined,
                value: '${duration}m',
                label: 'Duration',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatGridCard(
                icon: Icons.trending_up_rounded,
                value: volume,
                label: 'Volume ($unitLabel)',
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
                icon: Icons.repeat_rounded,
                value: '$sets',
                label: 'Sets Logged',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatGridCard(
                icon: Icons.fitness_center_rounded,
                value: '$exercises',
                label: 'Exercises',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPRSection(List<NewPRResult> prs, WorkoutProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFSectionHeader('New Personal Records'),
        const SizedBox(height: AppSpacing.sm),
        ...prs.map((pr) {
          final name = provider.getExerciseName(pr.exerciseId);
          final badges = pr.types.map((t) {
            final (label, color) = switch (t) {
              'weight' => ('Best Weight', AppColors.warning),
              'reps' => ('Best Reps', AppColors.secondary),
              _ => ('Best Volume', AppColors.success),
            };
            return RFChip(label: label, color: color);
          }).toList();

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withValues(alpha: 0.08),
                  AppColors.warning.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(spacing: 6, runSpacing: 6, children: badges),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMusclesSection(Set<String> muscles, WorkoutProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFSectionHeader('Muscles Trained'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: muscles.map((m) {
            final name = provider.getMuscleGroupName(m);
            return RFChip(
              label: name,
              color: AppColors.muscle(m),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExerciseSummary(
    WorkoutSession session,
    WorkoutProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFSectionHeader('Exercise Breakdown'),
        const SizedBox(height: AppSpacing.sm),
        ...session.exercises.map(
          (log) => _ExerciseSummaryRow(log: log, provider: provider),
        ),
      ],
    );
  }
}

class _ExerciseSummaryRow extends StatelessWidget {
  const _ExerciseSummaryRow({
    required this.log,
    required this.provider,
  });

  final ExerciseLog log;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final name = provider.getExerciseName(log.exerciseId);
    final volume = log.totalVolume;
    final volStr = volume >= 1000
        ? '${(volume / 1000).toStringAsFixed(1)}k'
        : volume.toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
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
          Text(
            '$volStr kg',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Optional once-per-workout effort chip — "how did that feel?" — used only
/// to calibrate [EffortEstimator]'s RPE anchor. Never required: skipping it
/// leaves the rolling calibration offset unchanged.
class _EffortChipRow extends StatefulWidget {
  const _EffortChipRow({required this.session});

  final WorkoutSession session;

  @override
  State<_EffortChipRow> createState() => _EffortChipRowState();
}

class _EffortChipRowState extends State<_EffortChipRow> {
  static const _options = [
    (value: 1, label: 'Easy', color: AppColors.success),
    (value: 2, label: 'Solid', color: AppColors.secondary),
    (value: 3, label: 'Brutal', color: AppColors.accent),
  ];

  late int? _selected = widget.session.sessionEffort;

  void _select(int value) {
    setState(() => _selected = value);
    context.read<WorkoutProvider>().recordSessionEffort(widget.session.id, value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFSectionHeader('How did that feel?'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final option in _options) ...[
              Expanded(child: _buildChip(option)),
              if (option != _options.last) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChip(({int value, String label, Color color}) option) {
    final isSelected = _selected == option.value;
    return GestureDetector(
      onTap: () => _select(option.value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: option.color.withValues(alpha: isSelected ? 0.2 : 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: option.color.withValues(alpha: isSelected ? 0.8 : 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          option.label,
          style: TextStyle(
            color: isSelected ? option.color : AppColors.textMuted,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
