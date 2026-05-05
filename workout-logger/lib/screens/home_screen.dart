// Home Screen — soft-futurist dashboard + glass pill nav

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import 'workout_flow_screen.dart';
import 'history_screen.dart';
import 'routines_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'widgets/workout_conflict_dialog.dart';
import 'widgets/rf_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _switchTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _DashboardTab(onSwitchTab: _switchTab),
          const HistoryScreen(),
          const RoutinesScreen(),
          const AnalyticsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _GlassPillNav(
        currentIndex: _currentIndex,
        // index 2 is intercepted by _HomeScreenState.build → _launchWorkout
        onTap: (i) => i == 2 ? _launchWorkout() : _switchTab(i),
      ),
    );
  }

  Future<StartWorkoutConflictAction> _resolveConflict(
    WorkoutProvider provider,
  ) async {
    final action = await showWorkoutConflictDialog(
      context,
      workoutStartTime: provider.workoutStartTime ?? DateTime.now(),
    );
    return action ?? StartWorkoutConflictAction.cancel;
  }

  Future<void> _launchWorkout() async {
    final provider = context.read<WorkoutProvider>();
    StartWorkoutConflictAction conflictAction =
        StartWorkoutConflictAction.cancel;

    final started = await provider.startWorkoutSafely(
      exerciseIds: const <String>[],
      onConflict: () async {
        conflictAction = await _resolveConflict(provider);
        return conflictAction;
      },
    );

    if (!mounted) return;
    if (started || conflictAction == StartWorkoutConflictAction.resume) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const WorkoutFlowScreen(isQuickStart: true),
        ),
      );
    }
  }
}

// ─── Glass pill nav ───────────────────────────────────────────────────────────

class _GlassPillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlassPillNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: AppColors.bg1,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'History',
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              // Centre FAB — tap routes through onTap(2) → _launchWorkout()
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => onTap(2),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, Color(0xFF6D28D9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.40),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Analytics',
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                active: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.fg3;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.geist(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final ValueChanged<int> onSwitchTab;

  const _DashboardTab({required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final sessions = provider.sessions;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateHeader(),
                  const SizedBox(height: 20),
                  _buildStreakHero(sessions),
                  const SizedBox(height: 20),
                  _buildStatGrid(sessions),
                  const SizedBox(height: 20),
                  const RFSectionHeader(
                    title: 'Activity',
                    subtitle: '14 WEEKS',
                  ),
                  const SizedBox(height: 12),
                  ActivityHeatmap(
                    workoutDates: sessions.map((s) => s.date).toList(),
                    weeks: 14,
                  ),
                  const SizedBox(height: 20),
                  _buildMuscleSection(context, provider, sessions),
                  const SizedBox(height: 20),
                  RFSectionHeader(
                    title: 'Recent Workouts',
                    action: 'See all',
                    onAction: () => onSwitchTab(1),
                  ),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    _buildEmptyWorkouts()
                  else
                    ...sessions
                        .take(3)
                        .map((s) => _RecentSessionCard(session: s)),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    final dateStr = DateFormat('EEE, MMM d').format(now);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr.toUpperCase(),
              style: GoogleFonts.geist(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.fg3,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              greeting,
              style: GoogleFonts.geist(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
                letterSpacing: -0.04,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => onSwitchTab(4),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 20,
              color: AppColors.fg3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakHero(List sessions) {
    int streak = 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final workoutDays =
        sessions
            .map((s) {
              final d = s.date as DateTime;
              return DateTime(d.year, d.month, d.day);
            })
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (workoutDays.isNotEmpty) {
      DateTime expected = workoutDays.contains(todayDate)
          ? todayDate
          : todayDate.subtract(const Duration(days: 1));
      for (final day in workoutDays) {
        if (day == expected) {
          streak++;
          expected = expected.subtract(const Duration(days: 1));
        } else if (day.isBefore(expected)) {
          break;
        }
      }
    }

    final last7 = List.generate(7, (i) {
      final d = todayDate.subtract(Duration(days: 6 - i));
      return workoutDays.contains(d);
    });

    return GlassCard(
      ambientColor: AppColors.accent,
      ambientRadius: 60,
      ambientAlignment: Alignment.topRight,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT STREAK',
                  style: GoogleFonts.geist(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg4,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$streak',
                      style: GoogleFonts.geistMono(
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                        letterSpacing: -0.04,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'days',
                      style: GoogleFonts.geist(
                        fontSize: 16,
                        color: AppColors.fg3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(7, (i) {
                    final active = last7[i];
                    final isToday = i == 6;
                    return Padding(
                      padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? AppColors.accent : AppColors.surface3,
                          border: isToday
                              ? Border.all(color: AppColors.accent, width: 1.5)
                              : null,
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: AppColors.accentSoft,
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              Icon(
                streak > 0
                    ? Icons.local_fire_department_rounded
                    : Icons.fitness_center_rounded,
                size: 40,
                color: streak > 0 ? AppColors.warn : AppColors.fg4,
              ),
              const SizedBox(height: 4),
              Text(
                streak > 0 ? 'On fire!' : 'Start!',
                style: GoogleFonts.geist(
                  fontSize: 11,
                  color: streak > 0 ? AppColors.warn : AppColors.fg4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(List sessions) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekSessions = sessions
        .where((s) => (s.date as DateTime).isAfter(weekAgo))
        .toList();
    final weekVolume = weekSessions.fold<double>(
      0,
      (sum, s) => sum + (s.totalVolume as double),
    );
    final weekCount = weekSessions.length;
    final weekExercises = weekSessions.fold<int>(
      0,
      (sum, s) => sum + (s.exercises as List).length,
    );

    final last8 = sessions.take(8).toList().reversed.toList();
    final sparkData = last8
        .map((s) => (s.totalVolume as double) / 1000)
        .toList();

    final avgDuration = sessions.isEmpty
        ? 0
        : sessions
                  .take(5)
                  .map((s) => s.duration as int)
                  .fold(0, (a, b) => a + b) ~/
              sessions.take(5).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RFStatBox(
                label: 'This Week',
                value: '$weekCount',
                unit: weekCount == 1 ? 'session' : 'sessions',
                color: AppColors.accent,
                sub: '$weekExercises exercises',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEKLY VOLUME',
                      style: GoogleFonts.geist(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.fg4,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            weekVolume >= 1000
                                ? '${(weekVolume / 1000).toStringAsFixed(1)}k'
                                : weekVolume.toStringAsFixed(0),
                            style: GoogleFonts.geistMono(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.data,
                              letterSpacing: -0.04,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        if (sparkData.length >= 2)
                          RFSparkline(
                            data: sparkData,
                            color: AppColors.data,
                            width: 52,
                            height: 24,
                          ),
                      ],
                    ),
                    Text(
                      'kg total',
                      style: GoogleFonts.geist(
                        fontSize: 11,
                        color: AppColors.fg3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RFStatBox(
                label: 'All Time',
                value: '${sessions.length}',
                unit: sessions.length == 1 ? 'session' : 'sessions',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RFStatBox(
                label: 'Avg Duration',
                value: sessions.isEmpty ? '—' : '$avgDuration',
                unit: sessions.isEmpty ? '' : 'min',
                color: AppColors.warn,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMuscleSection(
    BuildContext context,
    WorkoutProvider provider,
    List sessions,
  ) {
    final Map<String, double> muscleVolume = {};
    for (final session in sessions.take(5)) {
      for (final exerciseLog in (session.exercises as List)) {
        final exVolume = exerciseLog.totalVolume as double;
        final exercise = provider.getExercise(exerciseLog.exerciseId as String);
        if (exercise == null) continue;
        for (final activation in exercise.muscleActivations) {
          final contribution =
              exVolume * (activation.activationPercentage / 100.0);
          muscleVolume[activation.muscleGroupId] =
              (muscleVolume[activation.muscleGroupId] ?? 0) + contribution;
        }
      }
    }

    if (muscleVolume.isEmpty) return const SizedBox.shrink();

    final maxVol = muscleVolume.values.reduce((a, b) => a > b ? a : b);
    final sorted = muscleVolume.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final intensityMap = {
      for (final e in sorted) e.key: (e.value / maxVol).clamp(0.0, 1.0),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFSectionHeader(title: 'Muscles Trained', subtitle: 'RECENT'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodyHeatmap(muscleIntensity: intensityMap),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: top5.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MuscleVolumeBar(
                      name: _muscleName(entry.key),
                      pct: entry.value / maxVol,
                      color: AppColors.getMuscleColor(entry.key),
                      value: '${(entry.value / 1000).toStringAsFixed(1)}k kg',
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyWorkouts() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          const Icon(
            Icons.fitness_center_rounded,
            size: 40,
            color: AppColors.fg4,
          ),
          const SizedBox(height: 12),
          Text(
            'No workouts yet',
            style: GoogleFonts.geist(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.fg2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the play button below to start',
            style: GoogleFonts.geist(fontSize: 13, color: AppColors.fg4),
          ),
        ],
      ),
    );
  }

  static String _muscleName(String id) {
    const names = {
      'chest': 'Chest',
      'upper_chest': 'Upper Chest',
      'back': 'Back',
      'lats': 'Lats',
      'lower_back': 'Lower Back',
      'shoulders': 'Shoulders',
      'front_delts': 'Front Delts',
      'side_delts': 'Side Delts',
      'rear_delts': 'Rear Delts',
      'biceps': 'Biceps',
      'triceps': 'Triceps',
      'forearms': 'Forearms',
      'quads': 'Quads',
      'hamstrings': 'Hamstrings',
      'glutes': 'Glutes',
      'calves': 'Calves',
      'core': 'Core',
      'traps': 'Traps',
    };
    return names[id] ?? id;
  }
}

// ─── Recent session card ──────────────────────────────────────────────────────

class _RecentSessionCard extends StatelessWidget {
  final dynamic session;

  const _RecentSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = session.date as DateTime;
    final dayStr = DateFormat('EEE').format(date);
    final dateNum = DateFormat('d').format(date);
    final monthStr = DateFormat('MMM').format(date);
    final volume = session.totalVolume as double;
    final exercises = session.exercises as List;
    final duration = session.duration as int;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Date column
            Column(
              children: [
                Text(
                  dayStr.toUpperCase(),
                  style: GoogleFonts.geist(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg4,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateNum,
                  style: GoogleFonts.geistMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                    letterSpacing: -0.04,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  monthStr,
                  style: GoogleFonts.geist(fontSize: 9, color: AppColors.fg3),
                ),
              ],
            ),
            Container(
              width: 1,
              height: 44,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: 14),
            ),
            // Workout info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${exercises.length} ${exercises.length == 1 ? 'exercise' : 'exercises'}',
                    style: GoogleFonts.geist(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.fg,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$duration min',
                    style: GoogleFonts.geist(
                      fontSize: 11,
                      color: AppColors.fg3,
                    ),
                  ),
                ],
              ),
            ),
            // Volume
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  volume >= 1000
                      ? '${(volume / 1000).toStringAsFixed(1)}k'
                      : volume.toStringAsFixed(0),
                  style: GoogleFonts.geistMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                    letterSpacing: -0.02,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'kg vol',
                  style: GoogleFonts.geist(fontSize: 10, color: AppColors.fg4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
