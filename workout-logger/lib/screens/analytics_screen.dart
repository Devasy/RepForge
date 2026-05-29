// analytics_screen.dart — Analytics: Overview / Exercises / Targets / Records

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../services/managers/pr_manager.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/analytics_overview.dart';
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
        return const AnalyticsOverviewTab();
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

// ── Records Tab ────────────────────────────────────────────────────────────────

enum _RecordsFilter { all, thisMonth, byExercise }
enum _RecordsSort { recent, heaviest }

class _RecordsTab extends StatefulWidget {
  const _RecordsTab();

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  _RecordsFilter _filter = _RecordsFilter.all;
  _RecordsSort _sort = _RecordsSort.recent;

  @override
  Widget build(BuildContext context) {
    final prManager = context.watch<PRManager>();
    final provider = context.read<WorkoutProvider>();
    final allRecords = prManager.allRecords;

    if (allRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 48, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              'No records yet',
              style: GoogleFonts.geist(
                color: AppColors.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Finish a workout to set your first PRs',
              style: GoogleFonts.geist(
                  color: AppColors.textFaint, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Filter
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    List<PersonalRecord> filtered = switch (_filter) {
      _RecordsFilter.all => [...allRecords],
      _RecordsFilter.thisMonth => allRecords
          .where((r) => !r.achievedAt.isBefore(startOfMonth))
          .toList(),
      _RecordsFilter.byExercise => [...allRecords],
    };

    // Sort
    switch (_sort) {
      case _RecordsSort.recent:
        filtered.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
      case _RecordsSort.heaviest:
        filtered.sort((a, b) => b.bestWeight.compareTo(a.bestWeight));
    }

    // Stats for summary
    final thisMonthCount = allRecords
        .where((r) => !r.achievedAt.isBefore(startOfMonth))
        .length;
    final newest = allRecords.isEmpty
        ? null
        : ([...allRecords]
              ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt)))
            .first;

    // Group by exercise if needed
    Map<String, List<PersonalRecord>>? grouped;
    if (_filter == _RecordsFilter.byExercise) {
      grouped = {};
      for (final r in filtered) {
        grouped.putIfAbsent(r.exerciseId, () => []).add(r);
      }
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary header
                Row(
                  children: [
                    Text(
                      '${allRecords.length} PRs',
                      style: GoogleFonts.geist(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (thisMonthCount > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                              color:
                                  AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '$thisMonthCount this month',
                          style: GoogleFonts.geistMono(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Newest PR hero
                if (newest != null) ...[
                  const SizedBox(height: 12),
                  _NewestPRHero(
                    record: newest,
                    exerciseName:
                        provider.getExerciseName(newest.exerciseId),
                  ),
                ],

                // Filter + sort bar
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected:
                                  _filter == _RecordsFilter.all,
                              onTap: () => setState(
                                  () => _filter = _RecordsFilter.all),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'This month',
                              selected: _filter ==
                                  _RecordsFilter.thisMonth,
                              onTap: () => setState(() =>
                                  _filter = _RecordsFilter.thisMonth),
                            ),
                            const SizedBox(width: 6),
                            _FilterChip(
                              label: 'By exercise',
                              selected: _filter ==
                                  _RecordsFilter.byExercise,
                              onTap: () => setState(() =>
                                  _filter = _RecordsFilter.byExercise),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _sort = _sort ==
                              _RecordsSort.recent
                          ? _RecordsSort.heaviest
                          : _RecordsSort.recent),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.glass2,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          border:
                              Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _sort == _RecordsSort.recent
                                  ? Icons.access_time_rounded
                                  : Icons.fitness_center_rounded,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sort == _RecordsSort.recent
                                  ? 'Recent'
                                  : 'Heaviest',
                              style: GoogleFonts.geistMono(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        if (grouped != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final entry = grouped!.entries.elementAt(i);
                  return _ExercisePRGroup(
                    exerciseName: provider.getExerciseName(entry.key),
                    records: entry.value,
                  );
                },
                childCount: grouped.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _PRCard(
                  record: filtered[i],
                  exerciseName:
                      provider.getExerciseName(filtered[i].exerciseId),
                ),
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _NewestPRHero extends StatelessWidget {
  const _NewestPRHero({required this.record, required this.exerciseName});
  final PersonalRecord record;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final dateStr = DateFormat('MMM d, yyyy').format(record.achievedAt);
    final w = settings.toDisplay(record.bestWeight);

    return GlassCard(
      glowColor: AppColors.warning,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.warning, Color(0xFFFF9500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest PR',
                  style: GoogleFonts.geist(
                    color: AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  exerciseName,
                  style: GoogleFonts.geist(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  dateStr,
                  style: GoogleFonts.geist(
                    color: AppColors.textFaint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1)} ${settings.unitLabel}',
                style: GoogleFonts.geistMono(
                  color: AppColors.warning,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${record.bestReps} reps',
                style: GoogleFonts.geistMono(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExercisePRGroup extends StatelessWidget {
  const _ExercisePRGroup(
      {required this.exerciseName, required this.records});
  final String exerciseName;
  final List<PersonalRecord> records;

  @override
  Widget build(BuildContext context) {
    final best = records.reduce(
        (a, b) => a.bestWeight >= b.bestWeight ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Text(
            exerciseName,
            style: GoogleFonts.geist(
              color: AppColors.textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        _PRCard(record: best, exerciseName: exerciseName),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.glass2,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.geistMono(
            color: selected ? AppColors.primary : AppColors.textMuted,
            fontSize: 11,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
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
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.warning, size: 18),
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
                      style: GoogleFonts.geist(
                          color: AppColors.textFaint, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _PRStat(
                label: 'Best Weight',
                value:
                    '${displayWeight.toStringAsFixed(displayWeight % 1 == 0 ? 0 : 1)} $unit',
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              _PRStat(
                label: 'Best Reps',
                value: '${record.bestReps}',
                color: AppColors.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              _PRStat(
                label: 'Best Vol.',
                value: '${displayVol.toStringAsFixed(0)} $unit',
                color: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PRStat extends StatelessWidget {
  const _PRStat(
      {required this.label,
      required this.value,
      required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.geist(
                    color: AppColors.textFaint, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.geistMono(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
