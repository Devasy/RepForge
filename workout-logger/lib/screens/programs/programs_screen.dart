// programs_screen.dart — Training programs list

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/rf_widgets.dart';
import 'program_detail_screen.dart';
import 'program_designer_screen.dart';
import 'import_program_screen.dart';
import '../ai_program_generator_screen.dart';

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: context.read<WorkoutProvider>().programManager,
      builder: (context, _) {
        final programs =
            context.read<WorkoutProvider>().programManager.programs;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: programs.isEmpty
                ? _buildEmptyState(context)
                : _buildList(context, programs),
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: AppBreakpoints.navBarClearance),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'import_json',
                onPressed: () => _openImport(context),
                backgroundColor: AppColors.card,
                elevation: 0,
                child: const Icon(
                  Icons.download_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FloatingActionButton.small(
                heroTag: 'ai_generate',
                onPressed: () => _openAiGenerator(context),
                backgroundColor: AppColors.card,
                elevation: 0,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FloatingActionButton.extended(
                heroTag: 'new_program',
                onPressed: () => _openDesigner(context, null),
                backgroundColor: AppColors.primary,
                elevation: 0,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'New Program',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const RFEmptyState(
            icon: Icons.calendar_month_rounded,
            title: 'No Training Programs',
            subtitle: 'Create a structured multi-week program\nor import one from JSON',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlowButton(
                label: 'Create',
                icon: Icons.add_rounded,
                fullWidth: false,
                onPressed: () => _openDesigner(context, null),
              ),
              const SizedBox(width: AppSpacing.md),
              OutlineGlowButton(
                label: 'Import JSON',
                icon: Icons.download_rounded,
                onPressed: () => _openImport(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<TrainingProgram> programs) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + 100,
      ),
      itemCount: programs.length,
      itemBuilder: (context, index) => _ProgramCard(program: programs[index]),
    );
  }

  void _openDesigner(BuildContext context, TrainingProgram? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgramDesignerScreen(existing: existing),
      ),
    );
  }

  Future<void> _openAiGenerator(BuildContext context) async {
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

  Future<void> _openImport(BuildContext context) async {
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

    return GestureDetector(
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
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
            Row(
              children: [
                _badge('${program.totalWeeks}w', AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                _badge('${program.phases.length} phases', AppColors.secondary),
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

  Widget _buildMiniTimeline() {
    return SizedBox(
      height: 4,
      child: Row(
        children: program.phases.asMap().entries.map((entry) {
          final phase = entry.value;
          final color = _phaseColors[entry.key % _phaseColors.length];
          final safeDenominator = program.totalWeeks <= 0 ? 1 : program.totalWeeks;
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
