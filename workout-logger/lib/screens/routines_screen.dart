import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import 'programs/programs_screen.dart';
import 'programs/program_detail_screen.dart';
import 'programs/program_designer_screen.dart';
import 'programs/program_workout_navigation.dart';
import 'routine_optimizer_screen.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/routine_creator.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    return ListenableBuilder(
      listenable: provider.programManager,
      builder: (context, _) {
        final manager = provider.programManager;
        final followed = manager.followedProgram;
        final programs = [
          if (followed != null) followed,
          ...manager.programs.where((p) => p.id != followed?.id),
        ];
        final routines = provider.routines;
        final cards = <Widget>[];
        for (var i = 0; i < programs.length || i < routines.length; i++) {
          if (i < programs.length) {
            cards.add(
              _programCard(
                context: context,
                program: programs[i],
                provider: provider,
              ),
            );
          }
          if (i < routines.length) {
            cards.add(
              _routineCard(
                context: context,
                routine: routines[i],
                provider: provider,
              ),
            );
          }
        }
        return Material(
          color: AppColors.background,
          child: Stack(
            children: [
              const AmbientGlow(),
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth - AppSpacing.md * 2;
                    final columns =
                        width >= MediaQuery.textScalerOf(context).scale(160) * 2
                        ? 2
                        : 1;
                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _header(context)),
                        if (cards.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: RFEmptyState(
                                icon: Icons.fitness_center_rounded,
                                title: 'No training plans yet',
                                subtitle:
                                    'Add a routine or program to get started.',
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            sliver: SliverList.separated(
                              itemCount: (cards.length / columns).ceil(),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (_, row) => IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var column = 0;
                                      column < columns;
                                      column++
                                    ) ...[
                                      if (column > 0)
                                        const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child:
                                            row * columns + column <
                                                cards.length
                                            ? cards[row * columns + column]
                                            : const SizedBox(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 110),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        const Text(
          'Training',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.6,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'New training plan',
          onSelected: (value) {
            if (value == 'routine') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRoutineScreen()),
              );
            } else {
              ProgramsScreen.showCreationOptions(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'routine', child: Text('New routine')),
            PopupMenuItem(value: 'program', child: Text('New program')),
          ],
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: AppColors.primary),
                SizedBox(width: 4),
                Text(
                  'New',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _programCard({
    required BuildContext context,
    required TrainingProgram program,
    required WorkoutProvider provider,
  }) {
    final manager = provider.programManager;
    final followed = manager.followedProgram?.id == program.id;
    final resume =
        provider.hasActiveWorkout && provider.activeProgramId == program.id;
    final next = manager.nextWorkout(program, provider.sessions);
    final day = resume ? provider.activeProgramDay : next?.day;
    final week = resume ? provider.activeProgramWeek : next?.week;
    final progress = manager.progressFor(
      program: program,
      sessions: provider.sessions,
    );
    void open() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProgramDetailScreen(program: program)),
    );
    final canStart = (followed || resume) && day != null && week != null;
    return _TrainingCard(
      key: ValueKey('training-program-${program.id}'),
      title: program.name,
      kind: followed ? 'Program · Following' : 'Program',
      icon: Icons.calendar_month_rounded,
      highlighted: followed,
      subtitle:
          '${program.totalWeeks} weeks · ${progress.completed}/${progress.total} workouts',
      detail: day != null && week != null
          ? 'Week ${week.weekNumber} · ${day.name}'
          : progress.total == 0
          ? 'Add exercises to get started.'
          : 'All workouts completed.',
      action: canStart
          ? resume
                ? 'Resume workout'
                : 'Start next workout'
          : 'View program',
      onStart: canStart
          ? () => startProgramWorkout(
              context,
              programId: program.id,
              day: day,
              week: week,
            )
          : open,
      onOpen: open,
      onEdit: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProgramDesignerScreen(existing: program),
        ),
      ),
    );
  }

  Widget _routineCard({
    required BuildContext context,
    required Routine routine,
    required WorkoutProvider provider,
  }) => _TrainingCard(
    key: ValueKey('training-routine-${routine.id}'),
    title: routine.name,
    kind: 'Routine',
    icon: Icons.fitness_center_rounded,
    subtitle:
        '${routine.exerciseIds.length} exercise${routine.exerciseIds.length == 1 ? '' : 's'}',
    detail: routine.exerciseIds.isEmpty
        ? 'Add exercises to get started.'
        : routine.exerciseIds.take(2).map(provider.getExerciseName).join(', '),
    action: routine.exerciseIds.isEmpty ? 'Edit routine' : 'Start workout',
    onStart: routine.exerciseIds.isEmpty
        ? () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateRoutineScreen(routine: routine),
            ),
          )
        : () => startRoutineWorkoutFlow(context, routine),
    onOpen: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoutineDetailScreen(routine: routine)),
    ),
    onEdit: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateRoutineScreen(routine: routine)),
    ),
    onOptimize: () {
      final count = provider.sessions
          .where((s) => s.routineId == routine.id)
          .length;
      if (count < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Log "${routine.name}" at least 3 times so the optimizer has enough data to work with.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoutineOptimizerScreen(routine: routine),
        ),
      );
    },
  );
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({
    super.key,
    required this.title,
    required this.kind,
    required this.icon,
    required this.subtitle,
    required this.detail,
    required this.action,
    required this.onStart,
    required this.onOpen,
    required this.onEdit,
    this.onOptimize,
    this.highlighted = false,
  });
  final String title, kind, subtitle, detail, action;
  final IconData icon;
  final VoidCallback onStart, onOpen, onEdit;
  final VoidCallback? onOptimize;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(14),
    accentBorder: highlighted,
    onTap: onOpen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Options for $title',
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textSoft,
              ),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    onOpen();
                  case 'edit':
                    onEdit();
                  case 'optimize':
                    onOptimize?.call();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Text('View details')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (onOptimize != null)
                  const PopupMenuItem(
                    value: 'optimize',
                    child: Text('Optimize'),
                  ),
              ],
            ),
          ],
        ),
        Text(
          kind,
          style: const TextStyle(color: AppColors.textSoft, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const Spacer(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              minimumSize: const Size(48, 48),
            ),
            child: Text(action, textAlign: TextAlign.center),
          ),
        ),
      ],
    ),
  );
}
