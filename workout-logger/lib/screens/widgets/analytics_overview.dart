// analytics_overview.dart — Analytics "Overview" tab
//
// Top-down hierarchy: weekly Volume Trend (with range toggle) → unified
// Muscle Focus (body map + per-muscle rows, tappable drill-down) → Frequency.

import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../services/settings_provider.dart';
import '../../services/ml_service.dart' show MuscleRecoveryStatus;
import '../../data/exercise_database.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';
import 'body_heatmap.dart';
import 'muscle_detail_sheet.dart';

class AnalyticsOverviewTab extends StatelessWidget {
  const AnalyticsOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final hp = AppBreakpoints.hPadding(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.contentMaxWidth,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hp, 0, hp, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _VolumeTrendCard(),
                  const SizedBox(height: 12),
                  _MuscleFocusCard(provider: provider),
                  const SizedBox(height: 12),
                  _FrequencyGrid(provider: provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Volume trend (weekly aggregate + range toggle) ─────────────────────────────

enum _Range { w4, w12, all }

extension on _Range {
  String get label => switch (this) {
        _Range.w4 => '4W',
        _Range.w12 => '12W',
        _Range.all => 'All',
      };
  int? get weeks => switch (this) {
        _Range.w4 => 4,
        _Range.w12 => 12,
        _Range.all => null, // computed from history (capped)
      };
}

class _VolumeTrendCard extends StatefulWidget {
  const _VolumeTrendCard();

  @override
  State<_VolumeTrendCard> createState() => _VolumeTrendCardState();
}

class _VolumeTrendCardState extends State<_VolumeTrendCard> {
  _Range _range = _Range.w12;

  static const int _allCap = 26; // keep the chart readable for long histories

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final settings = context.watch<SettingsProvider>();
    final sessions = provider.sessions;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));

    // Resolve number of weeks to display.
    int weeks;
    if (_range.weeks != null) {
      weeks = _range.weeks!;
    } else if (sessions.isEmpty) {
      weeks = 0;
    } else {
      final earliest = sessions
          .map((s) => s.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final earliestWeekStart = DateTime(earliest.year, earliest.month, earliest.day)
          .subtract(Duration(days: earliest.weekday - 1));
      final span = currentWeekStart.difference(earliestWeekStart).inDays ~/ 7 + 1;
      weeks = span.clamp(1, _allCap);
    }

    double weeklyVolume(int weekIndex) {
      // weekIndex 0 == oldest week shown, weeks-1 == current week.
      final wStart =
          currentWeekStart.subtract(Duration(days: (weeks - 1 - weekIndex) * 7));
      final wEnd = wStart.add(const Duration(days: 7));
      final raw = sessions
          .where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd))
          .fold<double>(0, (sum, s) => sum + s.totalVolume);
      return settings.toDisplay(raw);
    }

    final spots = <FlSpot>[
      for (int i = 0; i < weeks; i++) FlSpot(i.toDouble(), weeklyVolume(i)),
    ];
    final hasData = spots.any((s) => s.y > 0);
    final bestVol = spots.isEmpty ? 0.0 : spots.map((s) => s.y).reduce(max);

    // Period delta: current shown period vs equal-length previous period.
    final curSum = spots.fold<double>(0, (sum, s) => sum + s.y);
    double prevSum = 0;
    for (int i = 0; i < weeks; i++) {
      final wStart =
          currentWeekStart.subtract(Duration(days: (weeks + i) * 7));
      final wEnd = wStart.add(const Duration(days: 7));
      prevSum += settings.toDisplay(sessions
          .where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd))
          .fold<double>(0, (sum, s) => sum + s.totalVolume));
    }
    final double? deltaPct =
        prevSum > 0 ? ((curSum - prevSum) / prevSum * 100) : null;

    DateTime weekStartFor(int i) =>
        currentWeekStart.subtract(Duration(days: (weeks - 1 - i) * 7));
    final labelInterval = weeks <= 1 ? 1.0 : (weeks / 6).ceilToDouble();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volume Trend',
                      style: GoogleFonts.geist(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${settings.unitLabel} · per week',
                      style: GoogleFonts.geist(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _RangeToggle(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ],
          ),
          if (deltaPct != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  deltaPct >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 13,
                  color: deltaPct >= 0 ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 2),
                Text(
                  '${deltaPct.abs().toStringAsFixed(0)}% vs prev ${weeks}w',
                  style: GoogleFonts.geistMono(
                    color: deltaPct >= 0 ? AppColors.success : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (!hasData) ...[
            const SizedBox(height: 24),
            const _EmptyChart(),
            const SizedBox(height: 8),
          ] else ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: AppBreakpoints.chartHeight(constraints.maxWidth),
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
                        getTooltipItems: (touched) => touched.map((spot) {
                          final i = spot.x.toInt();
                          final volStr = _fmtK(spot.y);
                          final ws = weekStartFor(i);
                          return LineTooltipItem(
                            '$volStr ${settings.unitLabel}',
                            GoogleFonts.geistMono(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    '\nwk of ${DateFormat('MMM d').format(ws)}',
                                style: GoogleFonts.geist(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.normal,
                                ),
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
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: labelInterval,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= weeks) return const Text('');
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat('d/M').format(weekStartFor(i)),
                                style: GoogleFonts.geistMono(
                                  color: AppColors.textMuted,
                                  fontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (v, _) => Text(
                            _fmtK(v),
                            style: GoogleFonts.geistMono(
                              color: AppColors.textMuted,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        if (bestVol > 0)
                          HorizontalLine(
                            y: bestVol,
                            color: AppColors.warning.withValues(alpha: 0.55),
                            strokeWidth: 1,
                            dashArray: [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              direction: LabelDirection.horizontal,
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(right: 6, bottom: 2),
                              style: GoogleFonts.geistMono(
                                color: AppColors.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                              labelResolver: (_) => 'BEST ${_fmtK(bestVol)}',
                            ),
                          ),
                      ],
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: AppColors.primary,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: weeks <= 12,
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
                            radius: 3.5,
                            color: AppColors.primary,
                            strokeWidth: 1.5,
                            strokeColor: AppColors.surface,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.25),
                              AppColors.primary.withValues(alpha: 0.0),
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
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.value, required this.onChanged});
  final _Range value;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _Range.values.map((r) {
          final active = r == value;
          return GestureDetector(
            onTap: () => onChanged(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                r.label,
                style: GoogleFonts.geistMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Muscle Focus (unified volume + recovery + growth, drill-down) ──────────────

class _MuscleFocusCard extends StatelessWidget {
  const _MuscleFocusCard({required this.provider});
  final WorkoutProvider provider;

  static const _muscleOrder = [
    'chest', 'back', 'shoulders', 'quads', 'hamstrings',
    'glutes', 'biceps', 'triceps', 'abs', 'calves',
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final byMuscle = provider.getWeeklyVolumeByMuscle();
    final recovery = provider.getMuscleRecoveryScores();
    final growth = provider.getMuscleGrowthModels();

    if (byMuscle.isEmpty && recovery.isEmpty) {
      return _ChartCard(
        title: 'Muscle Focus',
        isEmpty: true,
        child: const SizedBox.shrink(),
      );
    }

    // Union of muscles with volume or recovery data, ordered by volume desc.
    final ids = <String>{...byMuscle.keys, ...recovery.keys}.toList()
      ..sort((a, b) {
        final cmp = (byMuscle[b] ?? 0).compareTo(byMuscle[a] ?? 0);
        if (cmp != 0) return cmp;
        return _muscleOrder.indexOf(a).compareTo(_muscleOrder.indexOf(b));
      });
    final top = ids.take(8).toList();
    final maxVol = byMuscle.values.isEmpty
        ? 0.0
        : byMuscle.values.reduce(max);

    final normalized = <String, double>{
      if (maxVol > 0)
        for (final e in byMuscle.entries) e.key: e.value / maxVol,
    };

    return _ChartCard(
      title: 'Muscle Focus',
      subtitle: 'Weekly volume · recovery · trend — tap a muscle',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyHeatmapWidget(muscleVolumes: normalized),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                for (final id in top)
                  _MuscleFocusRow(
                    muscleId: id,
                    weeklyVolume: byMuscle[id] ?? 0,
                    fraction: maxVol > 0 ? (byMuscle[id] ?? 0) / maxVol : 0,
                    recovery: recovery[id],
                    growth: growth[id],
                    settings: settings,
                    onTap: () => _openDrillDown(context, id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openDrillDown(BuildContext context, String muscleId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => MuscleDetailSheet(
        muscleId: muscleId,
        provider: provider,
      ),
    );
  }
}

class _MuscleFocusRow extends StatelessWidget {
  const _MuscleFocusRow({
    required this.muscleId,
    required this.weeklyVolume,
    required this.fraction,
    required this.recovery,
    required this.growth,
    required this.settings,
    required this.onTap,
  });

  final String muscleId;
  final double weeklyVolume;
  final double fraction;
  final MuscleRecoveryStatus? recovery;
  final GrowthModel? growth;
  final SettingsProvider settings;
  final VoidCallback onTap;

  ({Color color, IconData icon}) get _trend {
    final model = growth;
    if (model == null) {
      return (color: AppColors.textFaint, icon: Icons.remove_rounded);
    }
    // Relative weekly growth so small muscles (low effective volume) use the
    // same bar as large ones — +2 %/week is strong progress on any muscle.
    final weekly = model.weeklyGrowthPercent;
    if (weekly > 2) {
      return (color: AppColors.success, icon: Icons.trending_up_rounded);
    }
    if (weekly > 0.5) {
      return (color: AppColors.secondary, icon: Icons.trending_up_rounded);
    }
    if (weekly < -2) {
      return (color: AppColors.error, icon: Icons.trending_down_rounded);
    }
    return (color: AppColors.warning, icon: Icons.trending_flat_rounded);
  }

  Color get _recoveryColor {
    final r = recovery;
    if (r == null) return AppColors.textFaint;
    if (r.recoveryFraction >= 0.90) return AppColors.success;
    if (r.recoveryFraction >= 0.70) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final name = MuscleGroups.names[muscleId] ?? muscleId;
    final color = AppColors.muscle(muscleId);
    final trend = _trend;
    final displayVol = settings.toDisplay(weeklyVolume);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.geist(
                      color: AppColors.textSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${_fmtK(displayVol)} ${settings.unitLabel}',
                  style: GoogleFonts.geistMono(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 14, color: AppColors.textFaint),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: RFProgressBar(
                    value: fraction,
                    color: color,
                    height: 5,
                    showGlow: false,
                  ),
                ),
                if (recovery != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${recovery!.recoveryPercent}%',
                    style: GoogleFonts.geistMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _recoveryColor,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(trend.icon, size: 13, color: trend.color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weekly frequency grid ──────────────────────────────────────────────────────

class _FrequencyGrid extends StatelessWidget {
  const _FrequencyGrid({required this.provider});
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weeks = {0: 0, 1: 0, 2: 0, 3: 0};
    for (final s in provider.sessions) {
      final w = now.difference(s.date).inDays ~/ 7;
      if (w >= 0 && w < 4) weeks[w] = (weeks[w] ?? 0) + 1;
    }

    return _ChartCard(
      title: 'Workout Frequency',
      subtitle: 'Sessions per week',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxSize = ((constraints.maxWidth - 48) / 4).clamp(40.0, 64.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weeks.entries.map((e) {
              final count = e.value;
              final label = e.key == 0 ? 'This wk' : '${e.key} wk';
              final active = count > 0;
              return Column(
                children: [
                  Container(
                    width: boxSize,
                    height: boxSize,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary.withValues(alpha: 0.12 + count * 0.06)
                          : AppColors.glass2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.glassBorder,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 12,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: GoogleFonts.geistMono(
                          color: active ? AppColors.primary : AppColors.textMuted,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: GoogleFonts.geist(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ── Reusable chart card ────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.isEmpty = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.geist(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.geist(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
          if (isEmpty) ...[
            const SizedBox(height: 24),
            const _EmptyChart(),
          ] else ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.show_chart_rounded, size: 32, color: AppColors.textFaint),
          const SizedBox(height: 8),
          Text('No data yet',
              style: GoogleFonts.geist(fontSize: 13, color: AppColors.textMuted)),
          Text('Complete workouts to see progress',
              style: GoogleFonts.geist(fontSize: 11, color: AppColors.textFaint)),
        ],
      ),
    );
  }
}

String _fmtK(double v) =>
    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);
