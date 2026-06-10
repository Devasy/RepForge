// exercise_progress_view.dart — Analytics "Exercises" tab

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../services/settings_provider.dart';
import '../../services/ai/gemini_ai_service.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';
import '../ai_coach_screen.dart';

enum _ChartMode { volume, sets }

class ExerciseProgressView extends StatefulWidget {
  const ExerciseProgressView({super.key});

  @override
  State<ExerciseProgressView> createState() => _ExerciseProgressViewState();
}

class _ExerciseProgressViewState extends State<ExerciseProgressView> {
  String? _selectedId;
  _ChartMode _chartMode = _ChartMode.volume;

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

    final effectiveId = performed.contains(_selectedId) ? _selectedId : null;

    return Column(
      children: [
        _ExerciseDropdown(
          ids: performed,
          selected: effectiveId,
          getExerciseName: provider.getExerciseName,
          onChanged: (id) => setState(() {
            _selectedId = id;
            _chartMode = _ChartMode.volume;
          }),
        ),
        if (effectiveId != null)
          Expanded(
            child: _ExerciseStats(
              exerciseId: effectiveId,
              provider: provider,
              chartMode: _chartMode,
              onChartModeChanged: (m) => setState(() => _chartMode = m),
            ),
          )
        else
          Expanded(
            child: Center(
              child: Text(
                'Select an exercise above',
                style: GoogleFonts.geist(
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

// ── Exercise picker — modern sheet with search ────────────────────────────────

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

  void _openSheet(BuildContext context) {
    final sorted = ids.toList()
      ..sort((a, b) => getExerciseName(a).compareTo(getExerciseName(b)));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _ExercisePickerSheet(
        ids: sorted,
        selected: selected,
        getExerciseName: getExerciseName,
        onPicked: (id) {
          Navigator.pop(context);
          onChanged(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null && ids.contains(selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: GestureDetector(
        onTap: () => _openSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: hasSelection
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: hasSelection
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.glass2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 15,
                  color: hasSelection
                      ? AppColors.primary
                      : AppColors.textFaint,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hasSelection
                      ? getExerciseName(selected!)
                      : 'Pick an exercise…',
                  style: GoogleFonts.geist(
                    color: hasSelection
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: hasSelection
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: hasSelection
                    ? AppColors.primary
                    : AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({
    required this.ids,
    required this.selected,
    required this.getExerciseName,
    required this.onPicked,
  });
  final List<String> ids;
  final String? selected;
  final String Function(String) getExerciseName;
  final ValueChanged<String> onPicked;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _search = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.ids;
    _search.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.ids
          : widget.ids
              .where((id) =>
                  widget.getExerciseName(id).toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      // 75% of screen height
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title + count
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(
              children: [
                Text(
                  'Select Exercise',
                  style: GoogleFonts.geist(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.ids.length} logged',
                  style: GoogleFonts.geist(
                    color: AppColors.textFaint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _search,
                autofocus: true,
                style: GoogleFonts.geist(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  hintStyle: GoogleFonts.geist(
                    color: AppColors.textFaint,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textFaint, size: 18),
                  suffixIcon: _search.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _search.clear(),
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.textFaint, size: 16),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: AppSpacing.sm,
                  ),
                ),
              ),
            ),
          ),
          // Divider
          Divider(
              height: 1,
              color: AppColors.glassBorder,
              indent: AppSpacing.lg,
              endIndent: AppSpacing.lg),
          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No exercises match',
                      style: GoogleFonts.geist(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final id = _filtered[i];
                      final name = widget.getExerciseName(id);
                      final isSelected = id == widget.selected;
                      return InkWell(
                        onTap: () => widget.onPicked(id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.10)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.glassBorder,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.geist(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSoft,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_rounded,
                                    color: AppColors.primary, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Stats view for a selected exercise ────────────────────────────────────────

class _ExerciseStats extends StatelessWidget {
  const _ExerciseStats({
    required this.exerciseId,
    required this.provider,
    required this.chartMode,
    required this.onChartModeChanged,
  });

  final String exerciseId;
  final WorkoutProvider provider;
  final _ChartMode chartMode;
  final ValueChanged<_ChartMode> onChartModeChanged;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final progression = provider.getVolumeProgression(exerciseId);
    final setProgression = provider.getSetProgression(exerciseId);
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
          _ChartSection(
            exerciseId: exerciseId,
            progression: progression,
            setProgression: setProgression,
            growthModel: growthModel,
            chartMode: chartMode,
            onChartModeChanged: onChartModeChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SessionHistory(progression: progression, settings: settings),
          const SizedBox(height: AppSpacing.md),
          _AskCoachButton(
            exerciseName: provider.getExerciseName(exerciseId),
            growthModel: growthModel,
          ),
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
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      glowColor: AppColors.primary,
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
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated 1RM',
                  style: GoogleFonts.geist(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  settings.formatWeight(oneRM),
                  style: GoogleFonts.geistMono(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Epley formula',
                style: GoogleFonts.geist(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
              Text(
                'Best across sets',
                style: GoogleFonts.geist(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
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

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      glowColor: color,
      child: Row(
        children: [
          Icon(
            isGrowing
                ? Icons.trending_up_rounded
                : Icons.trending_flat_rounded,
            color: color,
            size: 38,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGrowing ? 'Growing!' : 'Plateau',
                  style: GoogleFonts.geist(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isGrowing
                      ? '+${settings.toDisplay(model.slope.abs() * 7).toStringAsFixed(1)} ${settings.unitLabel}/week'
                      : 'Volume trend is flat',
                  style: GoogleFonts.geist(
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
                style: GoogleFonts.geistMono(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'model fit',
                style: GoogleFonts.geist(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Chart section (Volume line ↔ Set-progression bars) ───────────────────────

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.exerciseId,
    required this.progression,
    required this.setProgression,
    required this.growthModel,
    required this.chartMode,
    required this.onChartModeChanged,
  });

  final String exerciseId;
  final List<({DateTime date, double volume})> progression;
  final List<({DateTime date, List<WorkoutSet> sets})> setProgression;
  final GrowthModel? growthModel;
  final _ChartMode chartMode;
  final ValueChanged<_ChartMode> onChartModeChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chartMode == _ChartMode.volume
                      ? 'Volume Progression'
                      : 'Set Progression',
                  style: GoogleFonts.geist(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _ChartModeToggle(
                value: chartMode,
                onChanged: onChartModeChanged,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (chartMode == _ChartMode.volume)
            _VolumeChart(progression: progression, growthModel: growthModel)
          else
            _SetProgressionChart(setProgression: setProgression),
        ],
      ),
    );
  }
}

class _ChartModeToggle extends StatelessWidget {
  const _ChartModeToggle({required this.value, required this.onChanged});
  final _ChartMode value;
  final ValueChanged<_ChartMode> onChanged;

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
        children: [
          for (final mode in _ChartMode.values)
            GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: mode == value ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  mode == _ChartMode.volume ? 'Volume' : 'Sets',
                  style: GoogleFonts.geistMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mode == value ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
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

    // Chart x is the session index, but the model is trained on days since
    // the first session — map each index to its day offset before predicting.
    double dayAt(int i) => progression[i]
        .date
        .difference(progression.first.date)
        .inDays
        .toDouble();
    final avgGapDays = n > 1 ? dayAt(n - 1) / (n - 1) : 7.0;

    double rse = 0.0;
    if (growthModel != null && n >= 3) {
      double ssRes = 0.0;
      for (int i = 0; i < n; i++) {
        final r = progression[i].volume - growthModel!.predict(dayAt(i));
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
    final trendSpots = (growthModel != null && n >= 2)
        ? List<FlSpot>.generate(
            n + 2,
            (i) => FlSpot(
              i.toDouble(),
              settings.toDisplay(growthModel!
                  .predict(i < n ? dayAt(i) : dayAt(n - 1) + avgGapDays * (i - n + 1))
                  .clamp(0.0, double.infinity)),
            ),
          )
        : <FlSpot>[];
    final upperSpots = (ci95 > 0 && trendSpots.isNotEmpty)
        ? trendSpots.map((s) => FlSpot(s.x, s.y + ci95)).toList()
        : <FlSpot>[];
    final lowerSpots = (ci95 > 0 && trendSpots.isNotEmpty)
        ? trendSpots.map((s) => FlSpot(s.x, max(0.0, s.y - ci95))).toList()
        : <FlSpot>[];

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

    final hasTrend = trendSpots.isNotEmpty;
    final hasCi = upperSpots.isNotEmpty;
    final betweenBars = (hasTrend && hasCi)
        ? [
            BetweenBarsData(
              fromIndex: 2,
              toIndex: 3,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ]
        : <BetweenBarsData>[];

    if (progression.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text('No data',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    return SizedBox(
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
                  GoogleFonts.geistMono(
                    color: AppColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: '\n$dateStr',
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
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                    style: GoogleFonts.geistMono(
                      color: AppColors.textMuted,
                      fontSize: 9,
                    ),
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
                    padding: const EdgeInsets.only(right: 4, bottom: 2),
                    style: GoogleFonts.geistMono(
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
    );
  }
}

// ── Set progression — grouped dual-colour bars (weight + reps per set) ───────
//
// Layout per session group: [w₁ r₁ | w₂ r₂ | w₃ r₃ …] — purple = weight,
// cyan = reps (scaled to same axis via factor = maxWeight / maxReps).
// Left axis labels show weight (kg/lbs), right axis shows reps.

// ── Set progression — grouped dual-colour bars, interactive legend + auto-fit ─

enum _SetViewMode { recent, weekly }

class _SetProgressionChart extends StatefulWidget {
  const _SetProgressionChart({required this.setProgression});
  final List<({DateTime date, List<WorkoutSet> sets})> setProgression;

  static const _maxSetsPerSession = 4;
  static const _weightColor = AppColors.primary;
  static const _repsColor = AppColors.secondary;

  @override
  State<_SetProgressionChart> createState() => _SetProgressionChartState();
}

class _SetProgressionChartState extends State<_SetProgressionChart> {
  bool _showWeight = true;
  bool _showReps = true;
  _SetViewMode _mode = _SetViewMode.recent;

  static const _wc = _SetProgressionChart._weightColor;
  static const _rc = _SetProgressionChart._repsColor;
  static const _maxSets = _SetProgressionChart._maxSetsPerSession;

  // ── Data helpers ─────────────────────────────────────────────────────────────

  static DateTime _weekStart(DateTime d) {
    final n = DateTime(d.year, d.month, d.day);
    return n.subtract(Duration(days: n.weekday - 1));
  }

  /// How many session groups fit given available chart pixel width.
  int _maxFit(double chartWidth) {
    final setsPerGroup = _mode == _SetViewMode.weekly ? 1 : _maxSets;
    final visTypes = (_showWeight ? 1 : 0) + (_showReps ? 1 : 0);
    final rodsPerGroup = setsPerGroup * max(1, visTypes);
    const rodW = 6.0, gap = 2.0, groupGap = 12.0;
    final groupW = rodsPerGroup * rodW + (rodsPerGroup - 1) * gap + groupGap;
    return max(3, (chartWidth / groupW).floor());
  }

  List<({DateTime date, List<WorkoutSet> sets})> _buildSessions(
      SettingsProvider settings, int maxFit) {
    final raw = widget.setProgression;

    if (_mode == _SetViewMode.recent) {
      final slice = raw.length > maxFit
          ? raw.sublist(raw.length - maxFit)
          : raw;
      return slice.map((e) => (
            date: e.date,
            sets: e.sets.take(_maxSets).toList(),
          )).toList();
    }

    // Weekly aggregation — one synthetic set (avg weight, avg reps) per week.
    final byWeek = <DateTime, List<WorkoutSet>>{};
    for (final s in raw) {
      byWeek.putIfAbsent(_weekStart(s.date), () => []).addAll(s.sets);
    }
    final sorted = byWeek.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final visible = sorted.length > maxFit
        ? sorted.sublist(sorted.length - maxFit)
        : sorted;
    return visible.map((e) {
      final sets = e.value;
      final avgW = sets.fold(0.0, (s, x) => s + x.weight) / sets.length;
      final avgR = (sets.fold(0.0, (s, x) => s + x.reps) / sets.length).round();
      return (date: e.key, sets: [WorkoutSet(weight: avgW, reps: avgR)]);
    }).toList();
  }

  // ── Bar group builder ─────────────────────────────────────────────────────────

  List<BarChartGroupData> _buildGroups(
    List<({DateTime date, List<WorkoutSet> sets})> sessions,
    SettingsProvider settings,
    double scale,
  ) {
    return [
      for (int si = 0; si < sessions.length; si++)
        () {
          final rods = <BarChartRodData>[];
          for (final set in sessions[si].sets) {
            final w = settings.toDisplay(set.weight);
            if (_showWeight) {
              rods.add(BarChartRodData(
                toY: w,
                width: 6,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(3)),
                gradient: LinearGradient(
                  colors: [_wc, _wc.withValues(alpha: 0.55)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ));
            }
            if (_showReps) {
              rods.add(BarChartRodData(
                toY: set.reps * scale,
                width: 6,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(3)),
                gradient: LinearGradient(
                  colors: [_rc, _rc.withValues(alpha: 0.50)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ));
            }
          }
          // Always emit at least an invisible rod so x-axis label stays.
          if (rods.isEmpty) {
            rods.add(BarChartRodData(
                toY: 0, width: 0, color: Colors.transparent));
          }
          return BarChartGroupData(x: si, barRods: rods, barsSpace: 2);
        }(),
    ];
  }

  // ── Tooltip ───────────────────────────────────────────────────────────────────

  BarTooltipItem? _tooltip(
    int groupIndex,
    int rodIndex,
    List<({DateTime date, List<WorkoutSet> sets})> sessions,
    SettingsProvider settings,
  ) {
    if (groupIndex < 0 || groupIndex >= sessions.length) return null;
    final session = sessions[groupIndex];

    // Map rodIndex back to (setIndex, isWeight) based on visible toggles.
    int setIndex;
    bool isWeight;
    if (_showWeight && _showReps) {
      setIndex = rodIndex ~/ 2;
      isWeight = rodIndex.isEven;
    } else if (_showWeight) {
      setIndex = rodIndex;
      isWeight = true;
    } else {
      setIndex = rodIndex;
      isWeight = false;
    }
    if (setIndex >= session.sets.length) return null;
    final set = session.sets[setIndex];

    final dateLabel = _mode == _SetViewMode.weekly
        ? 'wk of ${DateFormat('MMM d').format(session.date)}'
        : DateFormat('MMM d').format(session.date);
    final setLabel =
        _mode == _SetViewMode.weekly ? 'Avg' : 'Set ${setIndex + 1}';

    if (isWeight) {
      final w = settings.toDisplay(set.weight);
      final wStr =
          w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
      return BarTooltipItem(
        '$setLabel  $wStr ${settings.unitLabel}',
        GoogleFonts.geistMono(
            color: _wc, fontSize: 12, fontWeight: FontWeight.w700),
        children: [
          TextSpan(
            text: '\n$dateLabel',
            style: GoogleFonts.geist(
                color: AppColors.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.normal),
          )
        ],
      );
    } else {
      return BarTooltipItem(
        '$setLabel  ${set.reps} reps',
        GoogleFonts.geistMono(
            color: _rc, fontSize: 12, fontWeight: FontWeight.w700),
        children: [
          TextSpan(
            text: '\n$dateLabel',
            style: GoogleFonts.geist(
                color: AppColors.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.normal),
          )
        ],
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final raw = widget.setProgression;

    if (raw.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child:
              Text('No data', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    // Compute global maxes from full history so axes don't jump on toggle.
    double maxW = 0, maxR = 0;
    for (final s in raw) {
      for (final set in s.sets) {
        final w = settings.toDisplay(set.weight);
        if (w > maxW) maxW = w;
        if (set.reps > maxR) maxR = set.reps.toDouble();
      }
    }
    if (maxW == 0) maxW = 1;
    if (maxR == 0) maxR = 1;
    final scale = maxW / maxR;
    final chartMaxY = maxW * 1.15;

    return LayoutBuilder(builder: (context, constraints) {
      // Reserve left(36) + right(28) axis widths from total.
      final chartWidth = (constraints.maxWidth - 64).clamp(60.0, double.infinity);
      final maxFit = _maxFit(chartWidth);
      final sessions = _buildSessions(settings, maxFit);
      final barGroups = _buildGroups(sessions, settings, scale);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Controls row: tappable legend + mode toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _ToggleLegend(
                    color: _wc,
                    label: 'Weight',
                    active: _showWeight,
                    onTap: () => setState(() => _showWeight = !_showWeight),
                  ),
                  const SizedBox(width: 14),
                  _ToggleLegend(
                    color: _rc,
                    label: 'Reps',
                    active: _showReps,
                    onTap: () => setState(() => _showReps = !_showReps),
                  ),
                ],
              ),
              _SetModeToggle(
                value: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: chartMaxY,
                groupsSpace: 12,
                backgroundColor: Colors.transparent,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.glassBorder, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.cardHigh,
                    getTooltipItem: (group, gi, rod, ri) =>
                        _tooltip(gi, ri, sessions, settings),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(
                      settings.unitLabel,
                      style: GoogleFonts.geistMono(
                          color: _wc,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                    axisNameSize: 16,
                    sideTitles: SideTitles(
                      showTitles: _showWeight,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v >= 1000
                            ? '${(v / 1000).toStringAsFixed(1)}k'
                            : v.toStringAsFixed(0),
                        style: GoogleFonts.geistMono(
                            color: _wc.withValues(alpha: 0.7),
                            fontSize: 9),
                      ),
                    ),
                  ),
                  rightTitles: AxisTitles(
                    axisNameWidget: Text(
                      'reps',
                      style: GoogleFonts.geistMono(
                          color: _rc,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                    axisNameSize: 16,
                    sideTitles: SideTitles(
                      showTitles: _showReps,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final r = (v / scale).round();
                        if (r <= 0) return const Text('');
                        return Text('$r',
                            style: GoogleFonts.geistMono(
                                color: _rc.withValues(alpha: 0.7),
                                fontSize: 9));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= sessions.length) {
                          return const Text('');
                        }
                        final label = _mode == _SetViewMode.weekly
                            ? DateFormat('d/M')
                                .format(sessions[i].date)
                            : DateFormat('d/M').format(sessions[i].date);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label,
                              style: GoogleFonts.geistMono(
                                  color: AppColors.textMuted,
                                  fontSize: 9)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      );
    });
  }
}

// ── Interactive legend dot ────────────────────────────────────────────────────

class _ToggleLegend extends StatelessWidget {
  const _ToggleLegend({
    required this.color,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final Color color;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: active ? 1.0 : 0.32,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: active ? color : AppColors.textFaint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.geistMono(
                color: active ? AppColors.textSoft : AppColors.textFaint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent / Weekly mode toggle ───────────────────────────────────────────────

class _SetModeToggle extends StatelessWidget {
  const _SetModeToggle({required this.value, required this.onChanged});
  final _SetViewMode value;
  final ValueChanged<_SetViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in _SetViewMode.values)
            GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: mode == value ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  mode == _SetViewMode.recent ? 'Recent' : 'Weekly',
                  style: GoogleFonts.geistMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: mode == value ? Colors.white : AppColors.textMuted,
                  ),
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

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session History',
            style: GoogleFonts.geist(
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
                    style: GoogleFonts.geist(
                      color: AppColors.textSoft,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${displayVol.toStringAsFixed(0)} ${settings.unitLabel}',
                    style: GoogleFonts.geistMono(
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

// ── Ask Coach button ──────────────────────────────────────────────────────────

class _AskCoachButton extends StatelessWidget {
  const _AskCoachButton({
    required this.exerciseName,
    required this.growthModel,
  });

  final String exerciseName;
  final GrowthModel? growthModel;

  @override
  Widget build(BuildContext context) {
    final gemini = context.watch<GeminiAiService>();
    if (!gemini.isConfigured) return const SizedBox.shrink();

    final isPlateauing =
        growthModel != null && growthModel!.weeklyGrowthPercent < 0.5;
    final seed = isPlateauing
        ? 'I\'ve been plateauing on $exerciseName. How can I break through and start progressing again?'
        : 'How can I continue to progress on $exerciseName and make the most of my current momentum?';

    return OutlineGlowButton(
      label: 'Ask Coach about $exerciseName',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.primary,
      fullWidth: true,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiCoachScreen(seedPrompt: seed),
        ),
      ),
    );
  }
}
