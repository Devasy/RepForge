// analytics_screen.dart — Analytics screen with Overview, Exercises, Targets tabs

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import '../data/exercise_database.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/exercise_progress_view.dart';
import 'widgets/targets_tab.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _AnalyticsHeader(tabController: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _OverviewTab(),
                  ExerciseProgressView(),
                  TargetsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header with title + tab bar ───────────────────────────────────────────────
class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({required this.tabController});
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Analytics',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          TabBar(
            controller: tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Exercises'),
              Tab(text: 'Targets'),
            ],
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VolumeChart(provider: provider),
          const SizedBox(height: AppSpacing.md),
          _MuscleVolumeChart(provider: provider),
          const SizedBox(height: AppSpacing.md),
          _FrequencyGrid(provider: provider),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ── Volume progression line chart ─────────────────────────────────────────────
class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.provider});
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final sessions = provider.sessions.take(14).toList().reversed.toList();

    return _ChartCard(
      title: 'Volume Progression',
      subtitle: 'Last ${sessions.length} workouts (tonnes)',
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
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
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
                    '${v.toStringAsFixed(0)}t',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: sessions.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), e.value.totalVolume / 1000);
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

// ── Muscle volume horizontal bars ─────────────────────────────────────────────
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

    final sorted = byMuscle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxVol = top.first.value;

    return _ChartCard(
      title: 'Weekly Muscle Volume',
      child: Column(
        children: top.map((entry) {
          final name = MuscleGroups.names[entry.key] ?? entry.key;
          final color = AppColors.muscle(entry.key);
          final pct = entry.value / maxVol;
          final volStr = entry.value >= 1000
              ? '${(entry.value / 1000).toStringAsFixed(1)}k'
              : entry.value.toStringAsFixed(0);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$volStr kg',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RFProgressBar(value: pct, color: color, height: 6, showGlow: false),
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
      if (w < 4) weeks[w] = (weeks[w] ?? 0) + 1;
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
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.glassBorder,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: active ? AppColors.primary : AppColors.textMuted,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Reusable chart card wrapper ───────────────────────────────────────────────
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
          if (isEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: RFEmptyState(
                icon: Icons.show_chart_rounded,
                title: 'No data yet',
                subtitle: 'Complete workouts to see progress',
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ],
      ),
    );
  }
}
