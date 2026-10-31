// home_screen.dart — Navigation shell and training dashboard

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../services/settings_provider.dart';
import '../services/ai/gemini_ai_service.dart';
import '../services/gemini_context_builder.dart';
import '../theme/app_theme.dart';
import 'workout_flow_screen.dart';
import 'history_screen.dart';
import 'routines_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'widgets/workout_conflict_dialog.dart';
import 'ai_coach_screen.dart';
import 'widgets/readiness_card.dart';
import 'widgets/sleep_hr_card.dart';
import 'widgets/heart_rate_card.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/rf_shell.dart';
import 'widgets/floating_nav_bar.dart';
import 'widgets/sparkline_painter.dart';
import 'widgets/activity_heatmap.dart';
import 'widgets/home_training_cards.dart';

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _navItems = [
    FloatingNavItem(icon: Icons.home_rounded, label: 'Home'),
    FloatingNavItem(icon: Icons.layers_rounded, label: 'Routines'),
    FloatingNavItem(icon: Icons.history_rounded, label: 'History'),
    FloatingNavItem(icon: Icons.bar_chart_rounded, label: 'Stats'),
  ];

  void switchTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return FloatingNavBarScaffold(
      scaffoldBackgroundColor: AppColors.background,
      // App-specific colour overrides — all other values use the
      // FloatingNavBarTheme defaults which adapt to ThemeData.colorScheme.
      theme: FloatingNavBarTheme(
        backgroundColor: AppColors.surface,
        borderColor: AppColors.glassBorderStrong,
        // Chip colours (replaces old pill API)
        selectedChipColor: AppColors.primary.withValues(alpha: 0.16),
        selectedChipBorderColor: AppColors.accentInk.withValues(alpha: 0.25),
        selectedChipShadowColor: Colors.transparent,
        selectedContentColor: AppColors.textPrimary,
        inactiveIconColor: AppColors.textMuted,
        outerGlowColor: Colors.transparent,
        outerShadowColor: Colors.transparent,
        springDampingRatio: 1,
        blurSigma: 0,
      ),
      items: _navItems,
      currentIndex: _currentIndex,
      onTabChanged: switchTab,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardTab(),
          RoutinesScreen(),
          HistoryScreen(),
          AnalyticsScreen(),
        ],
      ),
    );
  }

  Future<StartWorkoutConflictAction> _resolveConflict(
    BuildContext context,
    WorkoutProvider provider,
  ) async {
    final action = await showWorkoutConflictDialog(
      context,
      workoutStartTime: provider.workoutStartTime ?? DateTime.now(),
    );
    return action ?? StartWorkoutConflictAction.cancel;
  }

  void _resumeWorkout(BuildContext context) {
    Navigator.push(
      context,
      _slide(const WorkoutFlowScreen(isQuickStart: true)),
    );
  }

  Future<void> _startQuickWorkout(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    StartWorkoutConflictAction conflictAction =
        StartWorkoutConflictAction.cancel;

    final started = await provider.startWorkoutSafely(
      exerciseIds: const <String>[],
      onConflict: () async {
        conflictAction = await _resolveConflict(context, provider);
        return conflictAction;
      },
    );

    if (!context.mounted) return;
    if (started || conflictAction == StartWorkoutConflictAction.resume) {
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        _slide(const WorkoutFlowScreen(isQuickStart: true)),
      );
    }
  }

  Future<void> startRoutineWorkout(
    BuildContext context,
    Routine routine,
  ) async {
    final provider = context.read<WorkoutProvider>();
    StartWorkoutConflictAction conflictAction =
        StartWorkoutConflictAction.cancel;

    final started = await provider.startWorkoutSafely(
      routine: routine,
      onConflict: () async {
        conflictAction = await _resolveConflict(context, provider);
        return conflictAction;
      },
    );

    if (!context.mounted) return;
    if (started || conflictAction == StartWorkoutConflictAction.resume) {
      HapticFeedback.mediumImpact();
      Navigator.push(context, _slide(WorkoutFlowScreen(routine: routine)));
    }
  }

  void _showRoutineSelector(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetCtx) => _RoutineSelectorSheet(
        routines: provider.routines,
        onSelect: (r) {
          Navigator.pop(sheetCtx);
          startRoutineWorkout(context, r);
        },
        onQuickStart: () {
          Navigator.pop(sheetCtx);
          _startQuickWorkout(context);
        },
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  // Generate deterministic 14-week heatmap (98 cells, col-major)
  List<int> _buildHeatmapData(List<WorkoutSession> sessions) {
    final nowRaw = DateTime.now();
    final now = DateTime(nowRaw.year, nowRaw.month, nowRaw.day);
    final data = List<int>.filled(98, 0);
    for (final s in sessions) {
      final sessionDate = DateTime(s.date.year, s.date.month, s.date.day);
      final diff = now.difference(sessionDate).inDays;
      if (diff < 0 || diff >= 98) continue;
      final col = (97 - diff) ~/ 7;
      final row = (97 - diff) % 7;
      final idx = col * 7 + row;
      if (idx >= 0 && idx < 98) {
        data[idx] = (data[idx] + 1).clamp(0, 4);
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();

    return Stack(
      children: [
        const AmbientGlow(),
        SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hp = AppBreakpoints.hPadding(constraints.maxWidth);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.contentMaxWidth,
                  ),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hp, 16, hp, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(context, homeState),
                              const SizedBox(height: 24),
                              _buildStreakHero(
                                context: context,
                                provider: provider,
                                homeState: homeState,
                              ),
                              const SizedBox(height: 16),
                              const ReadinessCard(),
                              const SleepHrCard(),
                              const HeartRateCard(),
                              _buildStatsGrid(context, provider),
                              const SizedBox(height: 16),
                              _buildHeatmapCard(context, provider),
                              const SizedBox(height: 16),
                              _buildMuscleVolumeCard(context, provider),
                              const SizedBox(height: 16),
                              const _WeeklyInsightsCard(),
                              const SizedBox(height: 16),
                              _buildRecentWorkouts(
                                context: context,
                                provider: provider,
                                homeState: homeState,
                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, _HomeScreenState? homeState) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(child: _PersonalGreeting()),
        RFIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'AI coach',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiCoachScreen()),
          ),
        ),
        const SizedBox(width: 8),
        RFIconButton(
          icon: Icons.person_outline_rounded,
          tooltip: 'Profile',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakHero({
    required BuildContext context,
    required WorkoutProvider provider,
    _HomeScreenState? homeState,
  }) {
    final sessions = provider.sessions;
    // Calculate current streak
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final d = today.subtract(Duration(days: i));
      final hasWorkout = sessions.any(
        (s) =>
            s.date.year == d.year &&
            s.date.month == d.month &&
            s.date.day == d.day,
      );
      if (hasWorkout) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final hasWorkoutDays = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return sessions.any(
        (session) =>
            session.date.year == day.year &&
            session.date.month == day.month &&
            session.date.day == day.day,
      );
    });
    final isActive = provider.hasActiveWorkout;
    return TrainingStreakCard(
      streak: streak,
      weekStart: weekStart,
      workoutDays: hasWorkoutDays,
      todayIndex: today.weekday - 1,
      isActive: isActive,
      onStart: isActive
          ? () => homeState?._resumeWorkout(context)
          : () => homeState?._showRoutineSelector(context),
    );
  }

  Widget _buildStatsGrid(BuildContext context, WorkoutProvider provider) {
    final sessions = provider.sessions;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekSessions = sessions
        .where((s) => !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd))
        .toList();

    final settings = context.read<SettingsProvider>();
    final weekVol = weekSessions.fold<double>(0, (s, e) => s + e.totalVolume);
    final displayVol = settings.toDisplay(weekVol);
    final weekSets = weekSessions.fold<int>(
      0,
      (s, e) => s + e.exercises.fold(0, (a, ex) => a + ex.sets.length),
    );
    final avgDuration = sessions.isEmpty
        ? 0
        : sessions.take(7).fold<int>(0, (s, e) => s + e.duration) ~/
              sessions.take(7).length;

    // Sparkline data (last 7 weeks), anchored to midnight boundaries
    List<double> weeklyWorkouts = List.generate(7, (i) {
      final wStart = today.subtract(
        Duration(days: (6 - i) * 7 + today.weekday - 1),
      );
      final wEnd = wStart.add(const Duration(days: 7));
      return sessions
          .where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd))
          .length
          .toDouble();
    });
    List<double> weeklyVolumes = List.generate(7, (i) {
      final wStart = today.subtract(
        Duration(days: (6 - i) * 7 + today.weekday - 1),
      );
      final wEnd = wStart.add(const Duration(days: 7));
      final rawVol = sessions
          .where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd))
          .fold<double>(0, (s, e) => s + e.totalVolume);
      return settings.toDisplay(rawVol);
    });
    List<double> weeklySets = List.generate(7, (i) {
      final wStart = today.subtract(
        Duration(days: (6 - i) * 7 + today.weekday - 1),
      );
      final wEnd = wStart.add(const Duration(days: 7));
      return sessions
          .where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd))
          .fold<double>(
            0,
            (s, e) => s + e.exercises.fold(0, (a, ex) => a + ex.sets.length),
          );
    });
    List<double> weeklyAvgDurations = List.generate(7, (i) {
      final wStart = today.subtract(
        Duration(days: (6 - i) * 7 + today.weekday - 1),
      );
      final wEnd = wStart.add(const Duration(days: 7));
      final ws = sessions
          .where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd))
          .toList();
      if (ws.isEmpty) return 0;
      return ws.fold<double>(0, (s, e) => s + e.duration) / ws.length;
    });

    final stats = [
      _StatItem(
        label: 'This week',
        value: '${weekSessions.length}',
        unit: 'workouts',
        color: AppColors.accentInk,
        spark: weeklyWorkouts,
      ),
      _StatItem(
        label: 'Volume',
        value: displayVol >= 1000
            ? '${(displayVol / 1000).toStringAsFixed(1)}k'
            : displayVol.toStringAsFixed(0),
        unit: settings.unitLabel,
        color: AppColors.textMuted,
        spark: weeklyVolumes,
      ),
      _StatItem(
        label: 'Sets',
        value: '$weekSets',
        unit: 'this week',
        color: AppColors.textMuted,
        spark: weeklySets,
      ),
      _StatItem(
        label: 'Avg time',
        value: '$avgDuration',
        unit: sessions.isEmpty
            ? 'min · no workouts yet'
            : 'min · last ${sessions.take(7).length} ${sessions.length == 1 ? 'workout' : 'workouts'}',
        color: AppColors.textMuted,
        spark: weeklyAvgDurations,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = MediaQuery.textScalerOf(context).scale(14) > 21
            ? 1
            : AppBreakpoints.gridColumns(constraints.maxWidth);
        return Column(
          children: [
            for (var start = 0; start < stats.length; start += cols) ...[
              if (start > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var col = 0;
                      col < cols && start + col < stats.length;
                      col++
                    ) ...[
                      if (col > 0) const SizedBox(width: 12),
                      Expanded(child: _StatCard(item: stats[start + col])),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeatmapCard(BuildContext context, WorkoutProvider provider) {
    final data = _buildHeatmapData(provider.sessions);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Activity',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Last 14 weeks',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ActivityHeatmap(data: data),
        ],
      ),
    );
  }

  Widget _buildMuscleVolumeCard(
    BuildContext context,
    WorkoutProvider provider,
  ) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekSessions = provider.sessions
        .where(
          (s) => s.date.isAfter(weekStart.subtract(const Duration(days: 1))),
        )
        .toList();

    final muscleVols = <String, double>{};
    for (final s in weekSessions) {
      for (final el in s.exercises) {
        final ex = provider.getExercise(el.exerciseId);
        if (ex == null) continue;
        final vol = settings.toDisplay(el.totalVolume);
        for (final ma in ex.muscleActivations) {
          muscleVols[ma.muscleGroupId] =
              (muscleVols[ma.muscleGroupId] ?? 0) +
              vol * ma.activationPercentage / 100;
        }
      }
    }

    return WeeklyMuscleVolumeCard(
      volumes: muscleVols,
      unitLabel: settings.unitLabel,
    );
  }

  Widget _buildRecentWorkouts({
    required BuildContext context,
    required WorkoutProvider provider,
    _HomeScreenState? homeState,
  }) {
    final settings = context.read<SettingsProvider>();
    final recentSessions = provider.sessions.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Recent workouts',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => homeState?.switchTab(2),
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12,
                    color: AppColors.accentInk,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (recentSessions.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No workouts yet',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          )
        else
          ...recentSessions.map((s) {
            final dateStr = _formatSessionDate(s.date);
            final displayVol = settings.toDisplay(s.totalVolume);
            final volStr = displayVol >= 1000
                ? '${(displayVol / 1000).toStringAsFixed(1)}k'
                : displayVol.toStringAsFixed(0);
            final exCount = s.exercises.length;
            final setCount = s.exercises.fold<int>(
              0,
              (a, e) => a + e.sets.length,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: AppColors.accentInk,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.routineId != null
                                ? (provider.routines
                                          .cast<Routine?>()
                                          .firstWhere(
                                            (r) => r?.id == s.routineId,
                                            orElse: () => null,
                                          )
                                          ?.name ??
                                      'Workout')
                                : 'Quick Workout',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dateStr · $exCount exercises · $setCount sets',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          volStr,
                          style: TextStyle(
                            fontFamily: 'GeistMono',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                        Text(
                          '${settings.unitLabel} vol',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 12,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _formatSessionDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return DateFormat('MMM d').format(d);
  }
}

// ── Stat helpers ──────────────────────────────────────────────────────────────

class _PersonalGreeting extends StatelessWidget {
  const _PersonalGreeting();

  @override
  Widget build(BuildContext context) {
    final name = context
        .select<SettingsProvider, String?>((settings) => settings.userName)
        ?.trim();
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final hasName = name != null && name.isNotEmpty;
    final style = Theme.of(context).textTheme.headlineMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE · MMM d').format(now),
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(hasName ? '$greeting,' : greeting, style: style),
        if (hasName)
          Text(name, style: style?.copyWith(color: AppColors.textSoft)),
      ],
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.spark,
  });
  final String label;
  final String value;
  final String unit;
  final Color color;
  final List<double> spark;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});
  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
          ),
          const SizedBox(height: 12),
          Text(
            item.value,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            item.unit,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                '${item.label} over the last 7 weeks: ${item.spark.map((v) => v.toStringAsFixed(1)).join(", ")}',
            child: Sparkline(
              data: item.spark,
              color: item.color,
              width: 64,
              height: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Last 7 weeks',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Routine Selector Sheet ────────────────────────────────────────────────────

class _RoutineSelectorSheet extends StatelessWidget {
  const _RoutineSelectorSheet({
    required this.routines,
    required this.onSelect,
    required this.onQuickStart,
  });

  final List<Routine> routines;
  final void Function(Routine) onSelect;
  final VoidCallback onQuickStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.textMuted,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: RFSectionHeader('Select Routine'),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: AppColors.accentInk,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Quick Start',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Empty workout, no routine',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    color: AppColors.textMuted,
                  ),
                ),
                trailing: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.accentInk,
                ),
                onTap: onQuickStart,
              ),
              ...routines.map(
                (r) => ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.accentInk,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    r.name,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${r.exerciseIds.length} exercises',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      color: AppColors.textMuted,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.accentInk,
                  ),
                  onTap: () => onSelect(r),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Route helper ──────────────────────────────────────────────────────────────

// Thin alias to the shared slideRoute helper in rf_widgets.dart.
PageRouteBuilder<T> _slide<T>(Widget page) => slideRoute<T>(page);

// ── Weekly Insights Card ──────────────────────────────────────────────────────

class _WeeklyInsightsCard extends StatefulWidget {
  const _WeeklyInsightsCard();

  @override
  State<_WeeklyInsightsCard> createState() => _WeeklyInsightsCardState();
}

class _WeeklyInsightsCardState extends State<_WeeklyInsightsCard> {
  bool _loading = false;

  Future<void> _refresh() async {
    final gemini = context.read<GeminiAiService>();
    if (!gemini.isConfigured) return;

    setState(() => _loading = true);

    final wp = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();

    final exerciseMap = {for (final e in wp.allExercises) e.id: e};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));

    final thisWeek = wp.sessions
        .where(
          (s) =>
              !s.date.isBefore(startOfWeek) &&
              s.date.isBefore(startOfWeek.add(const Duration(days: 7))),
        )
        .toList();
    final lastWeek = wp.sessions
        .where(
          (s) =>
              !s.date.isBefore(startOfLastWeek) && s.date.isBefore(startOfWeek),
        )
        .toList();

    final context_ = GeminiContextBuilder.buildWeeklyInsightsContext(
      thisWeek: thisWeek,
      lastWeek: lastWeek,
      exerciseMap: exerciseMap,
      unitLabel: settings.unitLabel,
    );

    try {
      final insights = await gemini.generateWeeklyInsights(context_);
      if (mounted) await settings.saveWeeklyInsights(insights);
    } catch (_) {
      // silently ignore network/API errors
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gemini = context.watch<GeminiAiService>();
    final settings = context.watch<SettingsProvider>();

    if (!gemini.isConfigured) return const SizedBox.shrink();

    final insights = settings.weeklyInsights;
    final updatedAt = settings.weeklyInsightsDate;
    final hasInsights = insights.isNotEmpty;

    return GlassCard(
      glowColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.cardHigh,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.textSoft,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Weekly insights',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _loading ? null : _refresh,
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.30),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        )
                      : Text(
                          hasInsights ? 'Refresh' : 'Generate',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            color: AppColors.accentInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (hasInsights || _loading) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.glassBorder, height: 1),
            const SizedBox(height: AppSpacing.md),
            if (_loading && !hasInsights)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: RFLoadingDots(),
              )
            else
              Text(
                insights,
                style: TextStyle(
                  fontFamily: 'Geist',
                  color: AppColors.textSoft,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            if (updatedAt != null && !_loading) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Updated ${DateFormat('MMM d, h:mm a').format(updatedAt)}',
                style: TextStyle(
                  fontFamily: 'GeistMono',
                  color: AppColors.textFaint,
                  fontSize: 12,
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap Generate to get a personalised coaching summary for this week.',
              style: TextStyle(
                fontFamily: 'Geist',
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
