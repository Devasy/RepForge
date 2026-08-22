// home_screen.dart — Navigation shell + Dashboard tab (soft-futurist redesign)

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
import 'widgets/floating_nav_bar.dart';
import 'widgets/sparkline_painter.dart';
import 'widgets/activity_heatmap.dart';
import 'widgets/body_heatmap.dart';

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _navItems = [
    FloatingNavItem(icon: Icons.home_rounded,      label: 'Home'),
    FloatingNavItem(icon: Icons.layers_rounded,    label: 'Routines'),
    FloatingNavItem(icon: Icons.history_rounded,   label: 'History'),
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
        selectedChipColor: AppColors.glass3,
        selectedChipBorderColor: AppColors.primary.withValues(alpha: 0.25),
        selectedChipShadowColor: AppColors.primary.withValues(alpha: 0.15),
        selectedContentColor: AppColors.textPrimary,
        inactiveIconColor: AppColors.textMuted,
        outerGlowColor: AppColors.primary.withValues(alpha: 0.08),
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
    Navigator.push(context, _slide(const WorkoutFlowScreen(isQuickStart: true)));
  }

  Future<void> _startQuickWorkout(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    StartWorkoutConflictAction conflictAction = StartWorkoutConflictAction.cancel;

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
      Navigator.push(context, _slide(const WorkoutFlowScreen(isQuickStart: true)));
    }
  }

  Future<void> startRoutineWorkout(BuildContext context, Routine routine) async {
    final provider = context.read<WorkoutProvider>();
    StartWorkoutConflictAction conflictAction = StartWorkoutConflictAction.cancel;

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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

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
                          padding: EdgeInsets.fromLTRB(hp, 14, hp, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(context, homeState),
                              const SizedBox(height: 24),
                              _buildStreakHero(context: context, provider: provider, homeState: homeState),
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
                              _buildRecentWorkouts(context: context, provider: provider, homeState: homeState),
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
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE · MMM d').format(now);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr.toUpperCase(),
              style: TextStyle(fontFamily: 'Geist', 
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.12,
                  height: 1.05,
                ),
                children: [
                  TextSpan(text: '${_greeting()}\n'),
                  TextSpan(
                    text: '${context.watch<SettingsProvider>().userName ?? 'You'}.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiCoachScreen()),
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF5B21B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGlow(0.35),
                      blurRadius: 12,
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.glass2,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: AppColors.textSoft,
                ),
              ),
            ),
          ],
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
      final hasWorkout = sessions.any((s) =>
          s.date.year == d.year &&
          s.date.month == d.month &&
          s.date.day == d.day);
      if (hasWorkout) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    // Week dots (Mon–Sun)
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final hasWorkoutDays = List.generate(7, (i) {
      final d = weekStart.add(Duration(days: i));
      return sessions.any((s) =>
          s.date.year == d.year &&
          s.date.month == d.month &&
          s.date.day == d.day);
    });
    final todayWeekday = today.weekday - 1; // 0=Mon

    final isActive = provider.hasActiveWorkout;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient blob top-right
          Positioned(
            top: -40,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'STREAK',
                              style: TextStyle(fontFamily: 'Geist', 
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$streak',
                              style: TextStyle(fontFamily: 'GeistMono', 
                                fontSize: 56,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: -2.24,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'days',
                              style: TextStyle(fontFamily: 'Geist', 
                                fontSize: 16,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          streak == 0
                              ? 'Start your streak today'
                              : 'Keep it going — you\'re on a roll',
                          style: TextStyle(fontFamily: 'Geist', 
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: isActive
                        ? () => homeState?._resumeWorkout(context)
                        : () => homeState?._showRoutineSelector(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.warning : AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isActive ? AppColors.warning : AppColors.primary)
                                .withValues(alpha: 0.35),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive
                                ? Icons.play_arrow_rounded
                                : Icons.flash_on_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Resume' : 'Start',
                            style: TextStyle(fontFamily: 'Geist', 
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Week dots
              Row(
                children: List.generate(7, (i) {
                  final done = hasWorkoutDays[i];
                  final isToday = i == todayWeekday;
                  final isFuture = i > todayWeekday;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        children: [
                          Text(
                            weekDays[i],
                            style: TextStyle(fontFamily: 'Geist', 
                              fontSize: 10,
                              color: AppColors.textFaint,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: AppDurations.medium,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: done
                                  ? AppColors.primary
                                  : isToday
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : isFuture
                                          ? const Color(0x00000000)
                                          : const Color(0x0FFFFFFF),
                              border: isToday
                                  ? Border.all(
                                      color: AppColors.primary,
                                      width: 1,
                                    )
                                  : null,
                              boxShadow: done
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
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
    final weekSets =
        weekSessions.fold<int>(0, (s, e) => s + e.exercises.fold(0, (a, ex) => a + ex.sets.length));
    final avgDuration = sessions.isEmpty
        ? 0
        : sessions.take(7).fold<int>(0, (s, e) => s + e.duration) ~/
            sessions.take(7).length;

    // Sparkline data (last 7 weeks), anchored to midnight boundaries
    List<double> weeklyWorkouts = List.generate(7, (i) {
      final wStart = today.subtract(Duration(days: (6 - i) * 7 + today.weekday - 1));
      final wEnd = wStart.add(const Duration(days: 7));
      return sessions.where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd)).length.toDouble();
    });
    List<double> weeklyVolumes = List.generate(7, (i) {
      final wStart = today.subtract(Duration(days: (6 - i) * 7 + today.weekday - 1));
      final wEnd = wStart.add(const Duration(days: 7));
      final rawVol = sessions
          .where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd))
          .fold<double>(0, (s, e) => s + e.totalVolume);
      return settings.toDisplay(rawVol);
    });
    List<double> weeklySets = List.generate(7, (i) {
      final wStart = today.subtract(Duration(days: (6 - i) * 7 + today.weekday - 1));
      final wEnd = wStart.add(const Duration(days: 7));
      return sessions
          .where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd))
          .fold<double>(0, (s, e) => s + e.exercises.fold(0, (a, ex) => a + ex.sets.length));
    });
    List<double> weeklyAvgDurations = List.generate(7, (i) {
      final wStart = today.subtract(Duration(days: (6 - i) * 7 + today.weekday - 1));
      final wEnd = wStart.add(const Duration(days: 7));
      final ws = sessions.where((s) => !s.date.isBefore(wStart) && s.date.isBefore(wEnd)).toList();
      if (ws.isEmpty) return 0;
      return ws.fold<double>(0, (s, e) => s + e.duration) / ws.length;
    });

    final stats = [
      _StatItem(
        label: 'This week',
        value: '${weekSessions.length}',
        unit: '/ 5 goal',
        color: AppColors.primary,
        spark: weeklyWorkouts,
      ),
      _StatItem(
        label: 'Volume',
        value: displayVol >= 1000
            ? '${(displayVol / 1000).toStringAsFixed(1)}k'
            : displayVol.toStringAsFixed(0),
        unit: settings.unitLabel,
        color: AppColors.secondary,
        spark: weeklyVolumes,
      ),
      _StatItem(
        label: 'Sets',
        value: '$weekSets',
        unit: 'this week',
        color: AppColors.success,
        spark: weeklySets,
      ),
      _StatItem(
        label: 'Avg time',
        value: '$avgDuration',
        unit: 'min',
        color: AppColors.warning,
        spark: weeklyAvgDurations,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = AppBreakpoints.gridColumns(constraints.maxWidth);
        final ratio = cols == 4 ? 1.8 : 1.4;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: ratio,
          ),
          itemCount: stats.length,
          itemBuilder: (_, i) => _StatCard(item: stats[i]),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity',
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Last 14 weeks',
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 11,
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

  Widget _buildMuscleVolumeCard(BuildContext context, WorkoutProvider provider) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekSessions = provider.sessions
        .where((s) => s.date.isAfter(weekStart.subtract(const Duration(days: 1))))
        .toList();

    final muscleVols = <String, double>{};
    for (final s in weekSessions) {
      for (final el in s.exercises) {
        final ex = provider.getExercise(el.exerciseId);
        if (ex == null) continue;
        final vol = settings.toDisplay(el.totalVolume);
        for (final ma in ex.muscleActivations) {
          muscleVols[ma.muscleGroupId] =
              (muscleVols[ma.muscleGroupId] ?? 0) + vol * ma.activationPercentage / 100;
        }
      }
    }

    final maxVol = muscleVols.values.isEmpty ? 1.0 : muscleVols.values.reduce((a, b) => a > b ? a : b);
    final muscleList = muscleVols.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMuscles = muscleList.take(5).toList();

    final normalizedVols = {
      for (final e in muscleVols.entries) e.key: e.value / maxVol
    };

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly muscle volume',
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                settings.unitLabel,
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyHeatmapWidget(muscleVolumes: normalizedVols),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: topMuscles.isEmpty
                      ? [
                          Text(
                            'No data yet',
                            style: TextStyle(fontFamily: 'Geist', 
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ]
                      : topMuscles.map((e) {
                          final color = AppColors.muscle(e.key);
                          final pct = (e.value / maxVol).clamp(0.0, 1.0);
                          final volStr = e.value >= 1000
                              ? '${(e.value / 1000).toStringAsFixed(1)}k'
                              : e.value.toStringAsFixed(0);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _capitalize(e.key.replaceAll('_', ' ')),
                                      style: TextStyle(fontFamily: 'Geist', 
                                        fontSize: 11,
                                        color: AppColors.textSoft,
                                      ),
                                    ),
                                    Text(
                                      volStr,
                                      style: TextStyle(fontFamily: 'GeistMono', 
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: AppColors.glass2,
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor: pct,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        color: color,
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.4),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent workouts',
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => homeState?.switchTab(2),
                child: Text(
                  'See all',
                  style: TextStyle(fontFamily: 'Geist', 
                    fontSize: 12,
                    color: AppColors.primary,
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
                'No workouts yet — start one!',
                style: TextStyle(fontFamily: 'Geist', 
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
            final setCount = s.exercises.fold<int>(0, (a, e) => a + e.sets.length);
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
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.routineId != null
                                ? (provider.routines.cast<Routine?>().firstWhere((r) => r?.id == s.routineId, orElse: () => null)?.name ?? 'Workout')
                                : 'Quick Workout',
                            style: TextStyle(fontFamily: 'Geist', 
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dateStr · $exCount exercises · $setCount sets',
                            style: TextStyle(fontFamily: 'Geist', 
                              fontSize: 11,
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
                          style: TextStyle(fontFamily: 'GeistMono', 
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                        Text(
                          '${settings.unitLabel} vol',
                          style: TextStyle(fontFamily: 'Geist', 
                            fontSize: 10,
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Stat helpers ──────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              Sparkline(
                data: item.spark,
                color: item.color,
                width: 42,
                height: 16,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                style: TextStyle(fontFamily: 'GeistMono', 
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.52,
                ),
              ),
              Text(
                item.unit,
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
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
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Quick Start',
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Empty workout, no routine',
                  style: TextStyle(fontFamily: 'Geist', color: AppColors.textMuted),
                ),
                trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.primary),
                onTap: onQuickStart,
              ),
              ...routines.map((r) => ListTile(
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
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  r.name,
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${r.exerciseIds.length} exercises',
                  style: TextStyle(fontFamily: 'Geist', color: AppColors.textMuted),
                ),
                trailing: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.primary,
                ),
                onTap: () => onSelect(r),
              )),
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
        .where((s) => !s.date.isBefore(startOfWeek) && s.date.isBefore(startOfWeek.add(const Duration(days: 7))))
        .toList();
    final lastWeek = wp.sessions
        .where(
          (s) => !s.date.isBefore(startOfLastWeek) && s.date.isBefore(startOfWeek),
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
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF5B21B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGlow(0.4),
                      blurRadius: 10,
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This Week\'s Insights',
                  style: TextStyle(fontFamily: 'Geist', 
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _loading ? null : _refresh,
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        )
                      : Text(
                          hasInsights ? 'Refresh' : 'Generate',
                          style: TextStyle(fontFamily: 'Geist', 
                            color: AppColors.primary,
                            fontSize: 11,
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
                style: TextStyle(fontFamily: 'Geist', 
                  color: AppColors.textSoft,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            if (updatedAt != null && !_loading) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Updated ${DateFormat('MMM d, h:mm a').format(updatedAt)}',
                style: TextStyle(fontFamily: 'GeistMono', 
                  color: AppColors.textFaint,
                  fontSize: 10,
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap Generate to get a personalised coaching summary for this week.',
              style: TextStyle(fontFamily: 'Geist', 
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
