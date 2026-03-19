// Program Detail Screen
//
// Tabbed view of a training program: Overview, Schedule, Milestones, Overload.
// Shows per-phase exercise tables with sets, reps, tempo, rest, and notes.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/managers/program_manager.dart';
import '../theme/app_theme.dart';

class ProgramDetailScreen extends StatefulWidget {
  final TrainingProgram program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ProgramManager>();
    final isActive = manager.activeEnrollment?.programId == widget.program.id &&
        (manager.activeEnrollment?.isActive ?? false);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: AppTheme.surfaceColor,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProgramHero(
                program: widget.program,
                isActive: isActive,
              ),
            ),
            actions: [
              if (!isActive)
                TextButton.icon(
                  onPressed: () async {
                    await manager.enrollInProgram(widget.program.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Started "${widget.program.name}"'),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  label: const Text(
                    'Start',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radio_button_checked, color: AppTheme.primaryColor, size: 12),
                        SizedBox(width: 4),
                        Text('Active', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'SCHEDULE'),
                Tab(text: 'MILESTONES'),
                Tab(text: 'OVERLOAD'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(program: widget.program),
            _ScheduleTab(program: widget.program),
            _MilestonesTab(program: widget.program),
            _OverloadTab(program: widget.program),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Hero ───────────────────────────

class _ProgramHero extends StatelessWidget {
  final TrainingProgram program;
  final bool isActive;

  const _ProgramHero({required this.program, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceColor,
            AppTheme.primaryColor.withOpacity(0.15),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            program.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (program.author != null) ...[
            const SizedBox(height: 4),
            Text(
              'by ${program.author}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _HeroStat(value: '${program.durationWeeks}w', label: 'Duration'),
              const SizedBox(width: 20),
              _HeroStat(
                value: '${program.trainingDaysPerWeek}×',
                label: 'Per Week',
              ),
              const SizedBox(width: 20),
              _HeroStat(
                value: '${program.phases.length}',
                label: 'Phases',
              ),
              const SizedBox(width: 20),
              _HeroStat(
                value: '${program.milestones.length}',
                label: 'Milestones',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Overview Tab ───────────────────────────

class _OverviewTab extends StatelessWidget {
  final TrainingProgram program;

  const _OverviewTab({required this.program});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Description
        if (program.description.isNotEmpty) ...[
          Text(
            program.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Phases
        Text(
          'Training Phases',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...program.phases.asMap().entries.map((entry) {
          final i = entry.key;
          final phase = entry.value;
          final color = _phaseColor(i);
          return _PhaseCard(phase: phase, color: color);
        }),

        // Deload weeks
        if (program.deloadWeeks.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Deload Weeks',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: const Color(0xFFC87C1A).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFC87C1A),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Programmed Deloads — Do Not Skip',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFC87C1A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...program.deloadWeeks.map((d) {
                  final reduction = (d.weightReductionPercent * 100).round();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC87C1A).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'W${d.weekNumber}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFC87C1A),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '–$reduction% weight · max ${d.maxSets} sets'
                            '${d.notes != null ? " · ${d.notes}" : ""}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _phaseColor(int index) {
    const colors = [
      Color(0xFFC8491A),
      Color(0xFF1A6BC8),
      Color(0xFF1A8C4E),
    ];
    return colors[index % colors.length];
  }
}

class _PhaseCard extends StatelessWidget {
  final ProgramPhase phase;
  final Color color;

  const _PhaseCard({required this.phase, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'W${phase.startWeek}–${phase.endWeek}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  phase.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            phase.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _PhaseStat(label: 'Sets×Reps', value: phase.defaultSetsDisplay),
              const SizedBox(width: 16),
              _PhaseStat(
                label: 'Rest',
                value: '${phase.defaultRestSeconds}s',
              ),
              const SizedBox(width: 16),
              _PhaseStat(label: 'RPE', value: '${phase.rpeTarget}'),
              if (phase.isDeloadWeek) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC87C1A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DELOAD',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFC87C1A),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
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
}

class _PhaseStat extends StatelessWidget {
  final String label;
  final String value;

  const _PhaseStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Schedule Tab ───────────────────────────

class _ScheduleTab extends StatefulWidget {
  final TrainingProgram program;

  const _ScheduleTab({required this.program});

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  int _selectedDayIndex = 0;

  static const _dayOrder = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const _dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  List<ProgramWorkoutDay> get _sortedDays {
    final days = List<ProgramWorkoutDay>.from(
      widget.program.weeklySchedule,
    );
    days.sort(
      (a, b) =>
          _dayOrder.indexOf(a.dayOfWeek).compareTo(
            _dayOrder.indexOf(b.dayOfWeek),
          ),
    );
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _sortedDays;
    if (days.isEmpty) {
      return const Center(child: Text('No weekly schedule defined.'));
    }

    final selectedDay = days[_selectedDayIndex.clamp(0, days.length - 1)];

    return Column(
      children: [
        // Day selector strip
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: days.length,
            itemBuilder: (context, i) {
              final day = days[i];
              final isSelected = i == _selectedDayIndex;
              final dayLabel = _dayLabels[
                  _dayOrder.indexOf(day.dayOfWeek).clamp(0, 6)];
              final color = _dayTypeColor(day.dayType);
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.2)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : AppTheme.textSecondary.withOpacity(0.15),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? color : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color.withOpacity(day.isRestDay ? 0.3 : 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Day detail
        Expanded(
          child: _DayDetail(
            day: selectedDay,
            phases: widget.program.phases,
          ),
        ),
      ],
    );
  }

  Color _dayTypeColor(String type) {
    switch (type) {
      case 'push':
        return const Color(0xFFC8491A);
      case 'pull':
        return const Color(0xFF1A6BC8);
      case 'legs':
        return const Color(0xFF6B1A8C);
      case 'core':
        return const Color(0xFF1A7A8C);
      case 'shoulders':
        return const Color(0xFF8C6B1A);
      case 'arms':
        return const Color(0xFF1A8C4E);
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _DayDetail extends StatelessWidget {
  final ProgramWorkoutDay day;
  final List<ProgramPhase> phases;

  const _DayDetail({required this.day, required this.phases});

  @override
  Widget build(BuildContext context) {
    if (day.isRestDay) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.self_improvement_rounded,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              day.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            if (day.description != null) ...[
              const SizedBox(height: 6),
              Text(
                day.description!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Day header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (day.description != null)
                    Text(
                      day.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (day.estimatedDurationMinutes > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_rounded, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '~${day.estimatedDurationMinutes} min',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Exercise table
        if (day.exercises.isEmpty)
          Text(
            'No exercises defined.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          )
        else
          ...day.exercises.map(
            (ex) => _ExerciseRow(exercise: ex, phases: phases),
          ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ProgramExercise exercise;
  final List<ProgramPhase> phases;

  const _ExerciseRow({required this.exercise, required this.phases});

  @override
  Widget build(BuildContext context) {
    final isSuperset = exercise.supersetGroup != null;
    final supersetColor = _supersetColor(exercise.supersetGroup);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: isSuperset
            ? Border.all(color: supersetColor.withOpacity(0.3))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise name + superset badge
            Row(
              children: [
                if (isSuperset) ...[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: supersetColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        exercise.supersetGroup!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: supersetColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Per-phase set schemes
            if (phases.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: phases.asMap().entries.map((entry) {
                  final i = entry.key;
                  final phase = entry.value;
                  final scheme = exercise.schemeForPhase(phase.id);
                  if (scheme == null) return const SizedBox.shrink();
                  final color = _phaseColor(i);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Text(
                      'P${i + 1}: ${scheme.display}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                }).toList(),
              )
            else if (exercise.setSchemes.isNotEmpty)
              Text(
                exercise.setSchemes.first.display,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            // Tempo / Rest / Superset info
            Row(
              children: [
                _ExTag(icon: Icons.speed_rounded, label: exercise.tempo),
                const SizedBox(width: 10),
                _ExTag(
                  icon: Icons.timer_outlined,
                  label: exercise.restSeconds > 0
                      ? '${exercise.restSeconds}s rest'
                      : 'no rest',
                ),
                if (isSuperset) ...[
                  const SizedBox(width: 10),
                  _ExTag(
                    icon: Icons.link_rounded,
                    label: 'Superset ${exercise.supersetGroup}',
                  ),
                ],
              ],
            ),
            // Notes
            if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                exercise.notes!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _supersetColor(String? group) {
    switch (group) {
      case 'A':
        return const Color(0xFFC8491A);
      case 'B':
        return const Color(0xFF1A6BC8);
      case 'C':
        return const Color(0xFF1A8C4E);
      default:
        return AppTheme.primaryColor;
    }
  }

  Color _phaseColor(int index) {
    const colors = [
      Color(0xFFC8491A),
      Color(0xFF1A6BC8),
      Color(0xFF1A8C4E),
    ];
    return colors[index % colors.length];
  }
}

class _ExTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ExTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Milestones Tab ───────────────────────────

class _MilestonesTab extends StatelessWidget {
  final TrainingProgram program;

  const _MilestonesTab({required this.program});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ProgramManager>();
    final enrollment = manager.activeEnrollment?.programId == program.id
        ? manager.activeEnrollment
        : null;

    if (program.milestones.isEmpty) {
      return const Center(child: Text('No milestones defined.'));
    }

    final sorted = List<ProgramMilestone>.from(program.milestones)
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final milestone = sorted[i];
        final isCompleted =
            enrollment?.completedMilestoneIds.contains(milestone.id) ?? false;
        final phase = program.phases.firstWhere(
          (p) => p.id == milestone.phaseId,
          orElse: () => program.phases.first,
        );
        final phaseIndex = program.phases.indexOf(phase);
        final color = _phaseColor(phaseIndex);

        return _MilestoneCard(
          milestone: milestone,
          color: color,
          isCompleted: isCompleted,
          canComplete: enrollment != null,
          onComplete: () async {
            await manager.completeMilestone(milestone.id);
          },
        );
      },
    );
  }

  Color _phaseColor(int index) {
    const colors = [
      Color(0xFFC8491A),
      Color(0xFF1A6BC8),
      Color(0xFF1A8C4E),
      AppTheme.textPrimary,
    ];
    return colors[index.clamp(0, colors.length - 1)];
  }
}

class _MilestoneCard extends StatelessWidget {
  final ProgramMilestone milestone;
  final Color color;
  final bool isCompleted;
  final bool canComplete;
  final VoidCallback onComplete;

  const _MilestoneCard({
    required this.milestone,
    required this.color,
    required this.isCompleted,
    required this.canComplete,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? color : AppTheme.cardColor,
                  border: Border.all(color: color, width: 2),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              Container(
                width: 2,
                height: 20,
                color: color.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isCompleted
                      ? color.withOpacity(0.4)
                      : color.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '// WEEK ${milestone.weekNumber}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    milestone.title.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    milestone.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (milestone.targets.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: milestone.targets.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Text(
                            t.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (canComplete && !isCompleted) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onComplete,
                        style: TextButton.styleFrom(
                          foregroundColor: color,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: const Text('Mark Complete ✓'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Overload Tab ───────────────────────────

class _OverloadTab extends StatelessWidget {
  final TrainingProgram program;

  const _OverloadTab({required this.program});

  @override
  Widget build(BuildContext context) {
    if (program.progressionRules.isEmpty) {
      return const Center(child: Text('No overload schedule defined.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Overload rules summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progressive Overload Rules',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _OverloadRule(
                color: const Color(0xFFC8491A),
                title: 'Compound Lifts',
                rule: 'Add +2.5kg when all sets at top of rep range.',
              ),
              const SizedBox(height: 8),
              _OverloadRule(
                color: const Color(0xFF1A6BC8),
                title: 'Isolation Lifts',
                rule: 'Add +1.25kg or +1 rep. Strict form required.',
              ),
              const SizedBox(height: 8),
              _OverloadRule(
                color: const Color(0xFF1A8C4E),
                title: 'Bodyweight / Timed',
                rule: '+1 rep/week for pull-ups, +5s/week for holds.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Per-Exercise Schedule',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...program.progressionRules.map(
          (rule) => _ProgressionCard(rule: rule, phases: program.phases),
        ),
      ],
    );
  }
}

class _OverloadRule extends StatelessWidget {
  final Color color;
  final String title;
  final String rule;

  const _OverloadRule({
    required this.color,
    required this.title,
    required this.rule,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                rule,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressionCard extends StatelessWidget {
  final ProgressionRule rule;
  final List<ProgramPhase> phases;

  const _ProgressionCard({required this.rule, required this.phases});

  @override
  Widget build(BuildContext context) {
    final liftColor = rule.liftType == 'compound'
        ? const Color(0xFFC8491A)
        : rule.liftType == 'isolation'
            ? const Color(0xFF1A6BC8)
            : const Color(0xFF1A8C4E);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: liftColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: liftColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rule.exerciseName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: liftColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rule.liftType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: liftColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Week targets table
          if (rule.weekTargets.isNotEmpty) ...[
            Divider(height: 1, color: AppTheme.textSecondary.withOpacity(0.1)),
            _WeightTable(
              currentWeight: rule.currentWeightKg,
              increment: rule.incrementKg,
              targets: rule.weekTargets,
              keyNote: rule.keyNote,
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightTable extends StatelessWidget {
  final double currentWeight;
  final double increment;
  final List<WeekTarget> targets;
  final String? keyNote;

  const _WeightTable({
    required this.currentWeight,
    required this.increment,
    required this.targets,
    this.keyNote,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _TableRow(label: 'Starting', value: '${currentWeight}kg', isHeader: false),
          ...targets.map(
            (t) => _TableRow(
              label: 'W${t.weekNumber} target',
              value: '${t.targetWeightKg}kg × ${t.targetReps}',
              isHeader: false,
            ),
          ),
          _TableRow(
            label: 'Increment',
            value: '+${increment}kg/session',
            isHeader: false,
          ),
          if (keyNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    size: 14,
                    color: AppTheme.secondaryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      keyNote!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHeader;

  const _TableRow({
    required this.label,
    required this.value,
    required this.isHeader,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
