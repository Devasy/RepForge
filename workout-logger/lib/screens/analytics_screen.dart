// analytics_screen.dart — Analytics: Overview / Exercises / Targets

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../services/managers/pr_manager.dart';
import '../services/settings_provider.dart';
import '../data/exercise_database.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/exercise_progress_view.dart';
import 'widgets/targets_tab.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _tab = 0;

  static const _tabs = ['Overview', 'Exercises', 'Targets', 'Records'];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const AmbientGlow(),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              _buildPillTabBar(),
              Expanded(child: _buildTabView()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INSIGHTS',
                  style: GoogleFonts.geist(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textFaint,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Analytics',
                  style: GoogleFonts.geist(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.glass2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final active = i == _tab;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _tabs[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.geist(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabView() {
    switch (_tab) {
      case 0:
        return const _OverviewTab();
      case 1:
        return const ExerciseProgressView();
      case 2:
        return const TargetsTab();
      case 3:
        return const _RecordsTab();
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VolumeChart(provider: provider),
          const SizedBox(height: 12),
          _MuscleVolumeChart(provider: provider),
          const SizedBox(height: 12),
          _FrequencyGrid(provider: provider),
        ],
      ),
    );
  }
}

// ── Volume progression chart ───────────────────────────────────────────────────

class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.provider});
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final sessions = provider.sessions.take(14).toList().reversed.toList();
    final settings = context.watch<SettingsProvider>();

    return _ChartCard(
      title: 'Volume Progression',
      subtitle: '${settings.unitLabel} · Last ${sessions.length} workouts',
      isEmpty: sessions.isEmpty,
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.glassBorder,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= sessions.length) return const Text('');
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('d/M').format(sessions[i].date),
                        style: GoogleFonts.geistMono(color: AppColors.textMuted, fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    settings.toDisplay(v).toStringAsFixed(0),
                    style: GoogleFonts.geistMono(color: AppColors.textMuted, fontSize: 9),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: sessions.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), settings.toDisplay(e.value.totalVolume));
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.primary,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
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
    );
  }
}

// ── Muscle volume bars ────────────────────────────────────────────────────────

class _MuscleVolumeChart extends StatelessWidget {
  const _MuscleVolumeChart({required this.provider});
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final byMuscle = provider.getWeeklyVolumeByMuscle();

    if (byMuscle.isEmpty) {
      return _ChartCard(
        title: 'Weekly Muscle Volume',
        isEmpty: true,
        child: const SizedBox.shrink(),
      );
    }

    final settings = context.watch<SettingsProvider>();
    final sorted = byMuscle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxVol = top.first.value;

    if (maxVol == 0) {
      return _ChartCard(
        title: 'Weekly Muscle Volume',
        isEmpty: true,
        child: const SizedBox.shrink(),
      );
    }

    return _ChartCard(
      title: 'Weekly Muscle Volume',
      child: Column(
        children: top.map((entry) {
          final name = MuscleGroups.names[entry.key] ?? entry.key;
          final color = AppColors.muscle(entry.key);
          final pct = entry.value / maxVol;
          final displayVal = settings.toDisplay(entry.value);
          final volStr = displayVal >= 1000
              ? '${(displayVal / 1000).toStringAsFixed(1)}k'
              : displayVal.toStringAsFixed(0);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: GoogleFonts.geist(color: AppColors.textSoft, fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('$volStr ${settings.unitLabel}', style: GoogleFonts.geistMono(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                RFProgressBar(value: pct, color: color, height: 6, showGlow: true),
              ],
            ),
          );
        }).toList(),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weeks.entries.map((e) {
          final count = e.value;
          final label = e.key == 0 ? 'This' : '-${e.key}w';
          final active = count > 0;
          return Column(
            children: [
              Container(
                width: 54,
                height: 54,
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
              Text(label, style: GoogleFonts.geist(color: AppColors.textMuted, fontSize: 10)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Records Tab ───────────────────────────────────────────────────────────────

class _RecordsTab extends StatelessWidget {
  const _RecordsTab();

  @override
  Widget build(BuildContext context) {
    final prManager = context.watch<PRManager>();
    final provider = context.read<WorkoutProvider>();
    final records = [...prManager.allRecords]
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded, size: 48, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              'No records yet',
              style: GoogleFonts.geist(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Finish a workout to set your first PRs',
              style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: records.length,
      itemBuilder: (context, i) => _PRCard(
        record: records[i],
        exerciseName: provider.getExerciseName(records[i].exerciseId),
      ),
    );
  }
}

class _PRCard extends StatelessWidget {
  const _PRCard({required this.record, required this.exerciseName});

  final PersonalRecord record;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final dateStr = DateFormat('MMM d, yyyy').format(record.achievedAt);
    final displayWeight = settings.toDisplay(record.bestWeight);
    final displayVol = settings.toDisplay(record.bestVolume);
    final unit = settings.unitLabel;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseName,
                      style: GoogleFonts.geist(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _PRStat(label: 'Best Weight', value: '${displayWeight.toStringAsFixed(displayWeight % 1 == 0 ? 0 : 1)} $unit', color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              _PRStat(label: 'Best Reps', value: '${record.bestReps}', color: AppColors.secondary),
              const SizedBox(width: AppSpacing.sm),
              _PRStat(label: 'Best Vol.', value: '${displayVol.toStringAsFixed(0)} $unit', color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _PRStat extends StatelessWidget {
  const _PRStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.geistMono(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
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
            Text(subtitle!, style: GoogleFonts.geist(color: AppColors.textMuted, fontSize: 11)),
          ],
          if (isEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.show_chart_rounded, size: 32, color: AppColors.textFaint),
                  const SizedBox(height: 8),
                  Text('No data yet', style: GoogleFonts.geist(fontSize: 13, color: AppColors.textMuted)),
                  Text('Complete workouts to see progress', style: GoogleFonts.geist(fontSize: 11, color: AppColors.textFaint)),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }
}
