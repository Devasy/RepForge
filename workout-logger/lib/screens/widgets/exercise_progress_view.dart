// exercise_progress_view.dart — Analytics "Exercises" tab

import 'dart:math';

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
    final performed = context.select<WorkoutProvider, Set<String>>(
      (p) => {for (final s in p.sessions) for (final e in s.exercises) e.exerciseId},
    );
    final provider = context.read<WorkoutProvider>();

    if (performed.isEmpty) {
      return RFEmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'No Exercise Data',
        subtitle: 'Complete workouts to track exercises',
      );
    }

    final effectiveSelectedId = performed.contains(_selectedId) ? _selectedId : null;

    return Column(
      children: [
        _ExerciseDropdown(
          ids: performed,
          selected: effectiveSelectedId,
          getExerciseName: provider.getExerciseName,
          onChanged: (id) => setState(() => _selectedId = id),
        ),
        if (effectiveSelectedId != null)
          Expanded(
            child: _ExerciseStats(
              exerciseId: effectiveSelectedId,
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
          _VolumeChart(progression: progression, growthModel: growthModel),
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
    final settings = context.read<SettingsProvider>();
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
                      ? '+${settings.toDisplay(model.slope.abs()).toStringAsFixed(1)} ${settings.unitLabel}/session'
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
  const _VolumeChart({required this.progression, this.growthModel});
  final List<({DateTime date, double volume})> progression;
  final GrowthModel? growthModel;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final n = progression.length;

    // Residual standard error for 95% confidence interval width
    double rse = 0.0;
    if (growthModel != null && n >= 3) {
      double ssRes = 0.0;
      for (int i = 0; i < n; i++) {
        final r = progression[i].volume - growthModel!.predict(i);
        ssRes += r * r;
      }
      rse = sqrt(ssRes / (n - 2));
    }
    final ci95 = settings.toDisplay(rse * 1.96);

    final bestVol = n > 0
        ? settings.toDisplay(progression.map((e) => e.volume).reduce(max))
        : 0.0;

    final actualSpots = List<FlSpot>.generate(
      n,
      (i) => FlSpot(i.toDouble(), settings.toDisplay(progression[i].volume)),
    );

    // Trend line extends 2 sessions beyond actual data
    final trendSpots = (growthModel != null && n >= 2)
        ? List<FlSpot>.generate(
            n + 2,
            (i) => FlSpot(
              i.toDouble(),
              settings.toDisplay(growthModel!.predict(i).clamp(0.0, double.infinity)),
            ),
          )
        : <FlSpot>[];

    // Upper / lower CI bounds rendered as invisible lines;
    // BetweenBarsData fills the band between them.
    final upperSpots = (ci95 > 0 && trendSpots.isNotEmpty)
        ? trendSpots.map((s) => FlSpot(s.x, s.y + ci95)).toList()
        : <FlSpot>[];
    final lowerSpots = (ci95 > 0 && trendSpots.isNotEmpty)
        ? trendSpots.map((s) => FlSpot(s.x, max(0.0, s.y - ci95))).toList()
        : <FlSpot>[];

    // bar indices: 0 = actual, 1 = trend, 2 = upper CI, 3 = lower CI
    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots: actualSpots,
        isCurved: true,
        curveSmoothness: 0.3,
        color: AppColors.secondary,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 3,
            color: AppColors.secondary,
            strokeWidth: 1.5,
            strokeColor: AppColors.surface,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              AppColors.secondary.withValues(alpha: 0.22),
              AppColors.secondary.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      if (trendSpots.isNotEmpty)
        LineChartBarData(
          spots: trendSpots,
          isCurved: false,
          color: AppColors.primary.withValues(alpha: 0.5),
          barWidth: 1.5,
          dashArray: [8, 5],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (upperSpots.isNotEmpty)
        LineChartBarData(
          spots: upperSpots,
          color: Colors.transparent,
          barWidth: 0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (lowerSpots.isNotEmpty)
        LineChartBarData(
          spots: lowerSpots,
          color: Colors.transparent,
          barWidth: 0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
    ];

    // BetweenBarsData indices depend on how many bars are present
    final hasTrend = trendSpots.isNotEmpty;
    final hasCi = upperSpots.isNotEmpty;
    final betweenBars = (hasTrend && hasCi)
        ? [
            BetweenBarsData(
              fromIndex: 2, // upper CI
              toIndex: 3,   // lower CI
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ]
        : <BetweenBarsData>[];

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Volume Progression',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trendSpots.isNotEmpty) ...[
                Container(
                  width: 16,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Trend',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ],
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
                  backgroundColor: Colors.transparent,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: AppColors.glassBorder, strokeWidth: 1),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.cardHigh,
                      getTooltipItems: (spots) => spots.map((spot) {
                        if (spot.barIndex != 0) return null;
                        final v = spot.y;
                        final volStr = v >= 1000
                            ? '${(v / 1000).toStringAsFixed(1)}k'
                            : v.toStringAsFixed(0);
                        final i = spot.x.toInt();
                        final dateStr = (i >= 0 && i < n)
                            ? DateFormat('MMM d').format(progression[i].date)
                            : '';
                        return LineTooltipItem(
                          '$volStr ${settings.unitLabel}',
                          const TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w700),
                          children: [
                            TextSpan(
                              text: '\n$dateStr',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.normal),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (v, _) {
                          final label = v >= 1000
                              ? '${(v / 1000).toStringAsFixed(1)}k'
                              : v.toStringAsFixed(0);
                          return Text(
                            label,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (bestVol > 0)
                        HorizontalLine(
                          y: bestVol,
                          color: AppColors.warning.withValues(alpha: 0.5),
                          strokeWidth: 1,
                          dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            direction: LabelDirection.horizontal,
                            alignment: Alignment.topRight,
                            padding:
                                const EdgeInsets.only(right: 4, bottom: 2),
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                            labelResolver: (line) =>
                                'BEST ${bestVol.toStringAsFixed(0)}',
                          ),
                        ),
                    ],
                  ),
                  betweenBarsData: betweenBars,
                  lineBarsData: lineBars,
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
