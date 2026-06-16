// muscle_detail_sheet.dart — Drill-down sheet for a muscle group.
// Shows weekly contributing exercises (volume + growth trend) and an
// on-demand AI insight via GeminiService.generateInsight.

import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../services/workout_provider.dart';
import '../../services/settings_provider.dart';
import '../../services/ai/gemini_ai_service.dart';
import '../../services/interfaces/ml_service_interface.dart';
import '../../data/exercise_database.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';
import '../ai_coach_screen.dart';

class MuscleDetailSheet extends StatelessWidget {
  const MuscleDetailSheet({
    super.key,
    required this.muscleId,
    required this.provider,
  });

  final String muscleId;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final recovery = provider.getMuscleRecoveryScores()[muscleId];
    final name = MuscleGroups.names[muscleId] ?? muscleId;
    final color = AppColors.muscle(muscleId);
    final exercises = provider.getMuscleExerciseBreakdown(muscleId);

    Color recoveryColor = AppColors.textFaint;
    String recoveryLabel = '—';
    if (recovery != null) {
      recoveryLabel = '${recovery.recoveryPercent}%';
      if (recovery.recoveryFraction >= 0.90) {
        recoveryColor = AppColors.success;
      } else if (recovery.recoveryFraction >= 0.70) {
        recoveryColor = AppColors.warning;
      } else {
        recoveryColor = AppColors.error;
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row: muscle name + recovery badge
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: recoveryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: recoveryColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: recoveryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      recoveryLabel,
                      style: TextStyle(fontFamily: 'GeistMono', 
                        color: recoveryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (recovery != null) ...[
            const SizedBox(height: 4),
            Text(
              recovery.isRecovered
                  ? 'Ready to train'
                  : recovery.isUnderRecovered
                      ? 'Still fatigued — consider rest'
                      : 'Recovering',
              style: TextStyle(fontFamily: 'Geist', 
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          RFSectionHeader('Contributing this week', bottomPad: false),
          const SizedBox(height: AppSpacing.sm),

          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'No sessions logged for this muscle in the last 7 days.',
                style: TextStyle(fontFamily: 'Geist', 
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            )
          else
            ...exercises.map((ex) {
              final displayVol = settings.toDisplay(ex.volume);
              final volStr = displayVol >= 1000
                  ? '${(displayVol / 1000).toStringAsFixed(1)}k'
                  : displayVol.toStringAsFixed(0);
              final growth = ex.growth;
              Color trendColor = AppColors.textFaint;
              IconData trendIcon = Icons.remove_rounded;
              if (growth != null) {
                if (growth.slope > 2) {
                  trendColor = AppColors.success;
                  trendIcon = Icons.trending_up_rounded;
                } else if (growth.slope > 0) {
                  trendColor = AppColors.secondary;
                  trendIcon = Icons.trending_up_rounded;
                } else if (growth.slope < -2) {
                  trendColor = AppColors.error;
                  trendIcon = Icons.trending_down_rounded;
                } else {
                  trendColor = AppColors.warning;
                  trendIcon = Icons.trending_flat_rounded;
                }
              }

              return Container(
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
                    Expanded(
                      child: Text(
                        ex.name,
                        style: TextStyle(fontFamily: 'Geist', 
                          color: AppColors.textSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$volStr ${settings.unitLabel}',
                      style: TextStyle(fontFamily: 'GeistMono', 
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(trendIcon, size: 16, color: trendColor),
                  ],
                ),
              );
            }),

          const SizedBox(height: AppSpacing.lg),
          _MuscleVolumeTrendChart(
            muscleId: muscleId,
            provider: provider,
          ),

          const SizedBox(height: AppSpacing.lg),
          _RecentMuscleSessionsSection(
            muscleId: muscleId,
            provider: provider,
          ),

          const SizedBox(height: AppSpacing.md),
          _AiInsightSection(
            muscleId: muscleId,
            muscleName: name,
            provider: provider,
          ),
        ],
      ),
    );
  }
}

// ── Volume trend chart ────────────────────────────────────────────────────────

// Provider-aware shell — fetches data, delegates rendering to _VolumeTrendChartView.
class _MuscleVolumeTrendChart extends StatelessWidget {
  const _MuscleVolumeTrendChart({
    required this.muscleId,
    required this.provider,
  });

  final String muscleId;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return _VolumeTrendChartView(
      muscleId: muscleId,
      series: provider.getMuscleWeeklyVolumeSeries(muscleId, weeks: 8),
      toDisplay: settings.toDisplay,
      unitLabel: settings.unitLabel,
    );
  }
}

// Pure presentation widget — no provider dependencies; previewable.
class _VolumeTrendChartView extends StatelessWidget {
  const _VolumeTrendChartView({
    required this.muscleId,
    required this.series,
    required this.toDisplay,
    required this.unitLabel,
  });

  final String muscleId;
  final List<({DateTime weekStart, double volume})> series;
  final double Function(double) toDisplay;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.muscle(muscleId);
    final hasData = series.any((p) => p.volume > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RFSectionHeader('Volume trend (8 wk)', bottomPad: false),
        const SizedBox(height: AppSpacing.sm),
        if (!hasData)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Not enough data yet.',
              style: TextStyle(fontFamily: 'Geist', 
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          )
        else
          SizedBox(
            height: 96,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: series.map((p) => toDisplay(p.volume)).fold(0.0, max) * 1.25,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= series.length) return const SizedBox.shrink();
                        if (i != 0 && i != series.length - 1) return const SizedBox.shrink();
                        return Text(
                          DateFormat('MMM d').format(series[i].weekStart),
                          style: TextStyle(fontFamily: 'GeistMono', 
                            color: AppColors.textFaint,
                            fontSize: 9,
                          ),
                        );
                      },
                      reservedSize: 16,
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: series.asMap().entries.map((entry) {
                  final vol = toDisplay(entry.value.volume);
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: vol,
                        color: vol > 0
                            ? color.withValues(alpha: 0.85)
                            : AppColors.glass2,
                        width: 10,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Recent sessions for this muscle ───────────────────────────────────────────

// Provider-aware shell — fetches data, delegates rendering to _RecentSessionsView.
class _RecentMuscleSessionsSection extends StatelessWidget {
  const _RecentMuscleSessionsSection({
    required this.muscleId,
    required this.provider,
  });

  final String muscleId;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return _RecentSessionsView(
      sessions: provider.getRecentMuscleSessionSummaries(muscleId),
      toDisplay: settings.toDisplay,
      unitLabel: settings.unitLabel,
    );
  }
}

// Pure presentation widget — no provider dependencies; previewable.
class _RecentSessionsView extends StatelessWidget {
  const _RecentSessionsView({
    required this.sessions,
    required this.toDisplay,
    required this.unitLabel,
  });

  final List<({DateTime date, List<String> exerciseNames, double volume})> sessions;
  final double Function(double) toDisplay;
  final String unitLabel;

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 14) return '1 week ago';
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RFSectionHeader('Recent sessions', bottomPad: false),
        const SizedBox(height: AppSpacing.sm),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'No sessions recorded for this muscle yet.',
              style: TextStyle(fontFamily: 'Geist', 
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          )
        else
          ...sessions.map((s) {
            final displayVol = toDisplay(s.volume);
            final volStr = displayVol >= 1000
                ? '${(displayVol / 1000).toStringAsFixed(1)}k'
                : displayVol.toStringAsFixed(0);
            return Container(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _relativeDate(s.date),
                          style: TextStyle(fontFamily: 'GeistMono', 
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.exerciseNames.join(' · '),
                          style: TextStyle(fontFamily: 'Geist', 
                            color: AppColors.textSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$volStr $unitLabel',
                    style: TextStyle(fontFamily: 'GeistMono', 
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ── Widget previews ───────────────────────────────────────────────────────────

Widget _previewScaffold(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

List<({DateTime weekStart, double volume})> _stubSeries() {
  final now = DateTime.now();
  const vols = [1200.0, 1450.0, 980.0, 1600.0, 1750.0, 1400.0, 1900.0, 2100.0];
  return List.generate(
    8,
    (i) => (
      weekStart: now.subtract(Duration(days: (8 - i) * 7)),
      volume: vols[i],
    ),
  );
}

List<({DateTime date, List<String> exerciseNames, double volume})>
    _stubSessions() {
  final now = DateTime.now();
  return [
    (date: now, exerciseNames: ['Bench Press', 'Incline Dumbbell Press'], volume: 4200),
    (date: now.subtract(const Duration(days: 3)), exerciseNames: ['Cable Fly'], volume: 1800),
    (date: now.subtract(const Duration(days: 7)), exerciseNames: ['Bench Press', 'Push-Up'], volume: 3900),
    (date: now.subtract(const Duration(days: 14)), exerciseNames: ['Bench Press'], volume: 3600),
  ];
}

@Preview(name: 'Volume Trend – growing', group: 'MuscleDetailSheet')
Widget previewVolumeTrend() => _previewScaffold(
      _VolumeTrendChartView(
        muscleId: 'chest',
        series: _stubSeries(),
        toDisplay: (v) => v,
        unitLabel: 'kg',
      ),
    );

@Preview(name: 'Volume Trend – empty', group: 'MuscleDetailSheet')
Widget previewVolumeTrendEmpty() => _previewScaffold(
      _VolumeTrendChartView(
        muscleId: 'chest',
        series: List.generate(
          8,
          (i) => (weekStart: DateTime.now().subtract(Duration(days: (8 - i) * 7)), volume: 0.0),
        ),
        toDisplay: (v) => v,
        unitLabel: 'kg',
      ),
    );

@Preview(name: 'Recent Sessions – with data', group: 'MuscleDetailSheet')
Widget previewRecentSessions() => _previewScaffold(
      _RecentSessionsView(
        sessions: _stubSessions(),
        toDisplay: (v) => v,
        unitLabel: 'kg',
      ),
    );

@Preview(name: 'Recent Sessions – empty', group: 'MuscleDetailSheet')
Widget previewRecentSessionsEmpty() => _previewScaffold(
      _RecentSessionsView(
        sessions: const [],
        toDisplay: (v) => v,
        unitLabel: 'kg',
      ),
    );

// ── AI insight section ─────────────────────────────────────────────────────────

class _AiInsightSection extends StatefulWidget {
  const _AiInsightSection({
    required this.muscleId,
    required this.muscleName,
    required this.provider,
  });

  final String muscleId;
  final String muscleName;
  final WorkoutProvider provider;

  @override
  State<_AiInsightSection> createState() => _AiInsightSectionState();
}

class _AiInsightSectionState extends State<_AiInsightSection> {
  String? _insight;
  bool _loading = false;

  Future<void> _fetchInsight() async {
    setState(() => _loading = true);
    final gemini = context.read<GeminiAiService>();
    final settings = context.read<SettingsProvider>();
    final mlService = context.read<IMLService>();
    final provider = widget.provider;

    final exerciseMap = {for (final e in provider.allExercises) e.id: e};
    final recovery = mlService.computeMuscleRecoveryScores(
      provider.sessions,
      exerciseMap,
    );
    final exercises = provider.getMuscleExerciseBreakdown(widget.muscleId);
    final recoveryScore = recovery[widget.muscleId];

    final contextText = StringBuffer()
      ..writeln('Muscle: ${widget.muscleName}')
      ..writeln(
          'Recovery: ${recoveryScore != null ? "${recoveryScore.recoveryPercent}% (${recoveryScore.isRecovered ? "ready" : recoveryScore.isUnderRecovered ? "fatigued" : "recovering"})" : "no data"}')
      ..writeln('Weekly contributing exercises:');
    for (final ex in exercises) {
      final vol = settings.toDisplay(ex.volume);
      contextText.writeln(
          '  ${ex.name}: ${vol.toStringAsFixed(0)} ${settings.unitLabel}');
    }

    const system =
        'You are an expert personal trainer. Give a specific, actionable 2–3 sentence insight about this muscle group — cover training readiness, volume, and one practical tip. Be concise and direct.';

    final insight =
        await gemini.generateInsight(system, contextText.toString());
    if (mounted) setState(() { _insight = insight; _loading = false; });
  }

  void _openCoach(BuildContext context) {
    final seed =
        'Give me advice on training my ${widget.muscleName}. '
        'What should I focus on in my next session?';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiCoachScreen(seedPrompt: seed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gemini = context.watch<GeminiAiService>();
    if (!gemini.isConfigured) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_insight == null && !_loading) ...[
          Row(
            children: [
              Expanded(
                child: OutlineGlowButton(
                  label: 'Get AI Insight',
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  fullWidth: true,
                  small: true,
                  onPressed: _fetchInsight,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlineGlowButton(
                label: 'Ask Coach',
                icon: Icons.chat_bubble_outline_rounded,
                color: AppColors.secondary,
                small: true,
                onPressed: () => _openCoach(context),
              ),
            ],
          ),
        ] else if (_loading) ...[
          const Center(child: RFLoadingDots()),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'AI Insight',
                      style: TextStyle(fontFamily: 'Geist', 
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _insight!,
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textSoft,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () => _openCoach(context),
                  child: Text(
                    'Continue in Coach →',
                    style: TextStyle(fontFamily: 'Geist', 
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
