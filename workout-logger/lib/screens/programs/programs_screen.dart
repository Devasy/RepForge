// programs_screen.dart — Training programs list

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../utils/program_weekday.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/rf_widgets.dart';
import '../widgets/rf_dialogs.dart';
import 'program_workout_navigation.dart';
import 'program_detail_screen.dart';
import 'program_designer_screen.dart';
import 'import_program_screen.dart';
import '../ai_program_generator_screen.dart';

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    return ListenableBuilder(
      listenable: provider.programManager,
      builder: (context, _) {
        final programs = provider.programManager.programs;
        final followed = provider.programManager.followedProgram;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                MediaQuery.of(context).padding.bottom +
                    AppBreakpoints.navBarClearance +
                    90,
              ),
              children: [
                if (followed != null)
                  _FollowedProgramPanel(program: followed, provider: provider)
                else if (programs.isNotEmpty) ...[
                  Text(
                    'Choose a program to follow',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Your next unfinished workout will be ready here.',
                    style: TextStyle(color: AppColors.textSoft),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (programs.isEmpty)
                  _buildEmptyState(context)
                else ...[
                  _ProgramsHeading(
                    followed: followed != null,
                    onNew: () => showCreationOptions(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final program in programs)
                    _ProgramCard(program: program),
                ],
              ],
            ),
          ),
          floatingActionButton: followed != null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppBreakpoints.navBarClearance,
                  ),
                  child: FloatingActionButton.extended(
                    heroTag: 'new_program',
                    onPressed: () => showCreationOptions(context),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New program'),
                  ),
                ),
        );
      },
    );
  }

  static Future<void> showCreationOptions(BuildContext context) async {
    final action = await showRFActionSheet<String>(
      context,
      title: 'New program',
      actions: const [
        RFAction(
          label: 'Create from scratch',
          description: 'Build your own plan offline.',
          value: 'create',
          icon: Icons.edit_rounded,
        ),
        RFAction(
          label: 'Import JSON',
          description: 'Use a program you already have.',
          value: 'import',
          icon: Icons.download_rounded,
        ),
        RFAction(
          label: 'Generate with AI',
          description: 'Optional; requires a configured AI key.',
          value: 'ai',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case 'create':
        _openDesigner(context, null);
      case 'import':
        await _openImport(context);
      case 'ai':
        await _openAiGenerator(context);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: RFEmptyState(
        icon: Icons.calendar_month_rounded,
        title: 'No Training Programs',
        subtitle: 'Create a plan or import one to get started. AI is optional.',
      ),
    );
  }

  static void _openDesigner(BuildContext context, TrainingProgram? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgramDesignerScreen(existing: existing),
      ),
    );
  }

  static Future<void> _openAiGenerator(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AiProgramGeneratorScreen()),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'AI program added!',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.cardHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }
  }

  static Future<void> _openImport(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ImportProgramScreen()),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Program imported successfully!',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.cardHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }
  }
}

// ── Program Card ──────────────────────────────────────────────────────────────
class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program});
  final TrainingProgram program;

  static const _phaseColors = [
    AppColors.primary,
    AppColors.secondary,
    Colors.orange,
    Colors.pink,
    Colors.green,
  ];

  @override
  Widget build(BuildContext context) {
    final deloadCount = program.weeks.where((w) => w.isDeload).length;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProgramDetailScreen(program: program),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (program.author != null)
                        Text(
                          program.author!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (program.isImported)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.download_done_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            if (program.description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                program.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _badge('${program.totalWeeks} weeks', AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                if (program.weeks.isNotEmpty)
                  _badge(_daysPerWeek(), AppColors.secondary),
                if (deloadCount > 0) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _badge('$deloadCount deload', Colors.amber),
                ],
              ],
            ),
            if (program.phases.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildMiniTimeline(),
            ],
          ],
        ),
      ),
    );
  }

  String _daysPerWeek() {
    final counts =
        program.weeks
            .map((w) => w.days.where((d) => d.exercises.isNotEmpty).length)
            .toList()
          ..sort();
    return counts.first == counts.last
        ? '${counts.first} days/week'
        : '${counts.first}–${counts.last} days/week';
  }

  Widget _buildMiniTimeline() {
    return SizedBox(
      height: 4,
      child: Row(
        children: program.phases.asMap().entries.map((entry) {
          final phase = entry.value;
          final color = _phaseColors[entry.key % _phaseColors.length];
          final safeDenominator = program.totalWeeks <= 0
              ? 1
              : program.totalWeeks;
          final fraction =
              (phase.endWeek - phase.startWeek + 1) / safeDenominator;
          return Expanded(
            flex: ((fraction * 100).round()).clamp(1, 100),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FollowedProgramPanel extends StatelessWidget {
  const _FollowedProgramPanel({required this.program, required this.provider});
  final TrainingProgram program;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final manager = provider.programManager;
    final next = manager.nextWorkout(program, provider.sessions);
    final progress = manager.progressFor(
      program: program,
      sessions: provider.sessions,
    );
    final resume =
        provider.hasActiveWorkout && provider.activeProgramId == program.id;
    final day = resume ? provider.activeProgramDay : next?.day;
    final week = resume ? provider.activeProgramWeek : next?.week;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            program.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${progress.completed} of ${progress.total} workouts completed',
            style: const TextStyle(color: AppColors.textSoft),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (day != null && week != null)
            _NextWorkout(program: program, day: day, week: week, resume: resume)
          else
            Text(
              progress.total == 0
                  ? 'Add training days with exercises to this program to get started.'
                  : 'No unfinished workouts. View your program to review or repeat a day.',
              style: const TextStyle(color: AppColors.textSoft),
            ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProgramDetailScreen(program: program),
              ),
            ),
            child: const Text('View program'),
          ),
        ],
      ),
    );
  }
}

class _NextWorkout extends StatelessWidget {
  const _NextWorkout({
    required this.program,
    required this.day,
    required this.week,
    required this.resume,
  });
  final TrainingProgram program;
  final ProgramDay day;
  final ProgramWeek week;
  final bool resume;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        resume ? 'Workout in progress' : 'Next workout',
        style: const TextStyle(color: AppColors.textSoft),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Week ${week.weekNumber} · ${day.name}',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (programWeekday(day.dayOfWeek) case final weekday?)
        Text(
          'Scheduled $weekday',
          style: const TextStyle(color: AppColors.textSoft),
        ),
      Text(
        '${day.exercises.length} exercises',
        style: const TextStyle(color: AppColors.textSoft),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.all(AppSpacing.md),
          ),
          label: Text(
            resume ? 'Resume workout' : 'Start next workout',
            textAlign: TextAlign.center,
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          onPressed: () => startProgramWorkout(
            context,
            programId: program.id,
            day: day,
            week: week,
          ),
        ),
      ),
    ],
  );
}

class _ProgramsHeading extends StatelessWidget {
  const _ProgramsHeading({required this.followed, required this.onNew});
  final bool followed;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text(
        'Your programs',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (followed)
        TextButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New program'),
        ),
    ],
  );
}
