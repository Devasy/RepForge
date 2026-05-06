// home_screen.dart — Main navigation shell + Dashboard tab

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import 'workout_flow_screen.dart';
import 'history_screen.dart';
import 'routines_screen.dart';
import 'analytics_screen.dart';
import 'exercise_library_screen.dart';
import 'profile_screen.dart';
import 'widgets/workout_conflict_dialog.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/dashboard_widgets.dart';

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void switchTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _DashboardTab(),
          HistoryScreen(),
          RoutinesScreen(),
          AnalyticsScreen(),
          ProfileScreen(),
        ],
      ),
      floatingActionButton: _buildFAB(context, provider),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onTap: switchTab,
      ),
    );
  }

  Widget _buildFAB(BuildContext context, WorkoutProvider provider) {
    final isActive = provider.hasActiveWorkout;
    return GestureDetector(
      onTap: () => isActive ? _resumeWorkout(context) : _startQuickWorkout(context),
      child: Container(
        width: 58,
        height: 58,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isActive
                ? [AppColors.warning, Color.lerp(AppColors.warning, Colors.white, 0.15)!]
                : [AppColors.primary, Color.lerp(AppColors.primary, Colors.white, 0.15)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? AppColors.warning : AppColors.primary)
                  .withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isActive ? Icons.play_arrow_rounded : Icons.add_rounded,
          color: Colors.white,
          size: 30,
        ),
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

  Future<void> startRoutineWorkout(
    BuildContext context,
    Routine routine,
  ) async {
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
      ),
    );
  }
}

// ── Bottom Nav Bar ─────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.history_rounded, Icons.history_outlined, 'History'),
    (null, null, ''), // centre FAB placeholder
    (Icons.analytics_rounded, Icons.analytics_outlined, 'Analytics'),
    (Icons.person_rounded, Icons.person_outlined, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < _items.length; i++)
              if (_items[i].$1 == null)
                const Spacer() // placeholder for FAB
              else
                Expanded(child: _NavItem(
                  activeIcon: _items[i].$1!,
                  inactiveIcon: _items[i].$2!,
                  label: _items[i].$3,
                  selected: currentIndex == (i < 2 ? i : i - 1),
                  onTap: () => onTap(i < 2 ? i : i - 1),
                )),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Icon(
              selected ? activeIcon : inactiveIcon,
              color: selected ? AppColors.primary : AppColors.textSoft,
              size: 22,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textMuted,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Tab ──────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, homeState),
                  const SizedBox(height: AppSpacing.lg),
                  _buildHeroCTA(context, provider, homeState),
                  const SizedBox(height: AppSpacing.lg),
                  _buildStatsSection(context, provider),
                  const SizedBox(height: AppSpacing.lg),
                  _buildWeekStrip(provider),
                  const SizedBox(height: AppSpacing.lg),
                  RecentWorkoutsSection(
                    sessions: provider.sessions.take(3).toList(),
                    getExerciseName: provider.getExerciseName,
                    onSeeAll: () => homeState?.switchTab(1),
                    onTap: (_) => homeState?.switchTab(1),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildQuickActions(context, homeState),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _HomeScreenState? homeState) {
    final dateStr = DateFormat('EEE, MMM d').format(DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: const TextStyle(
                color: AppColors.textSoft,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Let\'s get moving 💪',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        GestureDetector(
          onTap: () => homeState?.switchTab(4),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCTA(
    BuildContext context,
    WorkoutProvider provider,
    _HomeScreenState? homeState,
  ) {
    final isActive = provider.hasActiveWorkout;

    if (isActive) {
      // Resume card
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.warning.withValues(alpha: 0.2),
              AppColors.warning.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Workout in progress',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    provider.activeRoutine?.name ?? 'Quick workout',
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            GlowButton(
              label: 'Resume',
              onPressed: () => Navigator.push(
                context,
                _slide(const WorkoutFlowScreen(isQuickStart: true)),
              ),
              color: AppColors.warning,
              fullWidth: false,
              small: true,
            ),
          ],
        ),
      );
    }

    // Default start card
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, const Color(0xFF4834D4), 0.6)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start Workout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      provider.routines.isEmpty
                          ? 'Quick start or build a routine'
                          : '${provider.routines.length} routines ready',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => homeState?._startQuickWorkout(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flash_on_rounded,
                            color: AppColors.primary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Quick Start',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (provider.routines.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () => homeState?._showRoutineSelector(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'From Routine',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
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
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, WorkoutProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFSectionHeader('This Week'),
        FutureBuilder<Map<String, dynamic>>(
          future: provider.getQuickStats(),
          builder: (context, snap) {
            final stats = snap.data ?? {
              'totalWorkouts': 0,
              'weeklyWorkouts': 0,
              'weeklyVolume': 0.0,
              'exercisesThisWeek': 0,
            };
            return StatGrid(stats: stats);
          },
        ),
      ],
    );
  }

  Widget _buildWeekStrip(WorkoutProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFSectionHeader('This Week'),
        const SizedBox(height: AppSpacing.sm),
        WeekActivityStrip(sessions: provider.sessions),
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    _HomeScreenState? homeState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFSectionHeader('Quick Actions'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: QuickActionTile(
                icon: Icons.add_circle_outline_rounded,
                label: 'New Routine',
                color: AppColors.primary,
                onTap: () => homeState?.switchTab(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: QuickActionTile(
                icon: Icons.library_books_rounded,
                label: 'Exercises',
                color: AppColors.secondary,
                onTap: () => Navigator.push(
                  context,
                  _slide(const ExerciseLibraryScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: QuickActionTile(
                icon: Icons.analytics_outlined,
                label: 'Analytics',
                color: AppColors.success,
                onTap: () => homeState?.switchTab(3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Routine Selector Sheet ─────────────────────────────────────────────────────

class _RoutineSelectorSheet extends StatelessWidget {
  const _RoutineSelectorSheet({
    required this.routines,
    required this.onSelect,
  });

  final List<Routine> routines;
  final void Function(Routine) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.textMuted,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: RFSectionHeader('Select Routine'),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            itemCount: routines.length,
            itemBuilder: (_, i) {
              final r = routines[i];
              return ListTile(
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${r.exerciseIds.length} exercises',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                trailing: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.primary,
                ),
                onTap: () => onSelect(r),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Route helper ──────────────────────────────────────────────────────────────

PageRouteBuilder<T> _slide<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 300),
  );
}
