// exercise_progress_view.dart — Analytics "Exercises" tab

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../services/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

class ExerciseProgressView extends StatefulWidget {
  const ExerciseProgressView({super.key});

  @override
  State<ExerciseProgressView> createState() => _ExerciseProgressViewState();
}

class _ExerciseProgressViewState extends State<ExerciseProgressView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final performed = <String>{
      for (final s in provider.sessions)
        for (final e in s.exercises) e.exerciseId,
    };

    if (performed.isEmpty) {
      return RFEmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'No Exercise Data',
        subtitle: 'Complete workouts to track exercises',
      );
    }

    return Column(
      children: [
        _ExerciseDropdown(
          ids: performed,
          selected: _selectedId,
          getExerciseName: provider.getExerciseName,
          onChanged: (id) => setState(() => _selectedId = id),
        ),
        if (_selectedId != null)
          Expanded(
            child: _ExerciseStats(
              exerciseId: _selectedId!,
              provider: provider,
            ),
          )
        else
          Expanded(
            child: Center(
              child: Text(
                'Select an exercise above',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Exercise dropdown selector ─────────────────────────────────────────────────
class _ExerciseDropdown extends StatelessWidget {
  const _ExerciseDropdown({
    required this.ids,
    required this.selected,
    required this.getExerciseName,
    required this.onChanged,
  });

  final Set<String> ids;
  final String? selected;
  final String Function(String) getExerciseName;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: DropdownButton<String>(
          value: ids.contains(selected) ? selected : null,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: AppColors.cardHigh,
          hint: const Text(
            'Select exercise…',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          items: ids.map((id) {
            return DropdownMenuItem(
              value: id,
              child: Text(getExerciseName(id)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Stats view for a selected exercise ───────────────────────────────────────
class _ExerciseStats extends StatelessWidget {
  const _ExerciseStats({
    required this.exerciseId,
    required this.provider,
  });

  final String exerciseId;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final progression = provider.getVolumeProgression(exerciseId);
    final growthModel = provider.getGrowthModel(exerciseId);
    final bestOneRM = provider.getBestOneRM(exerciseId);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bestOneRM != null) ...[
            _OneRMCard(oneRM: bestOneRM, settings: settings),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (growthModel != null) ...[
            _GrowthCard(model: growthModel),
            const SizedBox(height: AppSpacing.sm),
          ],
          _VolumeChart(progression: progression),
          const SizedBox(height: AppSpacing.sm),
          _SessionHistory(progression: progression, settings: settings),
        ],
      ),
    );
  }
}

// ── 1RM card ──────────────────────────────────────────────────────────────────
class _OneRMCard extends StatelessWidget {
  const _OneRMCard({required this.oneRM, required this.settings});
  final double oneRM;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated 1RM',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                Text(
                  settings.formatWeight(oneRM),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Epley formula',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
              Text(
                'Best across sets',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Growth trend card ─────────────────────────────────────────────────────────
class _GrowthCard extends StatelessWidget {
  const _GrowthCard({required this.model});
  final GrowthModel model;

  @override
  Widget build(BuildContext context) {
    final isGrowing = model.slope > 0;
    final color = isGrowing ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isGrowing ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
            color: color,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGrowing ? 'Growing!' : 'Plateau',
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isGrowing
                      ? '+${model.slope.abs().toStringAsFixed(1)} kg/session'
                      : 'Volume trend is flat',
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R² ${(model.r2 * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'model fit',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Volume progression line chart ─────────────────────────────────────────────
class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.progression});
  final List<({DateTime date, double volume})> progression;

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Volume Progression',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (progression.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No data',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: AppColors.glassBorder, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(0),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: progression.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.volume);
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppColors.secondary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondary.withValues(alpha: 0.25),
                            AppColors.secondary.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Session history list ───────────────────────────────────────────────────────
class _SessionHistory extends StatelessWidget {
  const _SessionHistory({
    required this.progression,
    required this.settings,
  });

  final List<({DateTime date, double volume})> progression;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    if (progression.isEmpty) return const SizedBox.shrink();

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
          const Text(
            'Session History',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...progression.take(10).map((entry) {
            final displayVol = settings.toDisplay(entry.volume);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy').format(entry.date),
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${displayVol.toStringAsFixed(0)} ${settings.unitLabel}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
