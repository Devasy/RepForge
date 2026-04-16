// Programs Screen
//
// Shows the list of training programs and provides entry points for:
//   - Viewing program details
//   - Creating a new program
//   - Importing a program from JSON (full-screen ImportProgramScreen)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import 'program_detail_screen.dart';
import 'program_designer_screen.dart';
import 'import_program_screen.dart';

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
          backgroundColor: AppTheme.backgroundColor,
          body: programs.isEmpty
              ? _buildEmptyState(context)
              : _buildList(context, programs),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'import_json',
                onPressed: () => _openImport(context),
                backgroundColor: AppTheme.surfaceColor,
                child: const Icon(Icons.download, color: AppTheme.secondaryColor),
              ),
              const SizedBox(height: AppSpacing.sm),
              FloatingActionButton.extended(
                heroTag: 'new_program',
                onPressed: () => _openDesigner(context, null),
                icon: const Icon(Icons.add),
                label: const Text('New Program'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            'No Training Programs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a structured multi-week program\nor import one from JSON',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openDesigner(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _openImport(context),
                icon: const Icon(Icons.download),
                label: const Text('Import JSON'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Program List ─────────────────────────────────────────────────────

  Widget _buildList(BuildContext context, List<TrainingProgram> programs) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        100, // FAB clearance
      ),
      itemCount: programs.length,
      itemBuilder: (context, index) =>
          _ProgramCard(program: programs[index]),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  void _openDesigner(BuildContext context, TrainingProgram? existing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgramDesignerScreen(existing: existing),
      ),
    );
  }

  Future<void> _openImport(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ImportProgramScreen()),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program imported successfully!')),
      );
    }
  }
}

// ── Program Card ──────────────────────────────────────────────────────────

class _ProgramCard extends StatelessWidget {
  final TrainingProgram program;

  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final deloadCount = program.weeks.where((w) => w.isDeload).length;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProgramDetailScreen(program: program),
          ),
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.calendar_month,
                      color: AppTheme.primaryColor,
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
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (program.author != null)
                          Text(
                            program.author!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (program.isImported)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.download_done,
                        size: 16,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (program.description != null) ...[
                Text(
                  program.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              // Stats row
              Row(
                children: [
                  _badge(
                    '${program.totalWeeks}w',
                    AppTheme.primaryColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _badge(
                    '${program.phases.length} phases',
                    AppTheme.secondaryColor,
                  ),
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
      ),
    );
  }

  static const _phaseColors = [
    AppTheme.primaryColor,
    AppTheme.secondaryColor,
    Colors.orange,
    Colors.pink,
    Colors.green,
  ];

  Widget _buildMiniTimeline() {
    return SizedBox(
      height: 4,
      child: Row(
        children: program.phases.asMap().entries.map((entry) {
          final phase = entry.value;
          final color = _phaseColors[entry.key % _phaseColors.length];
          final fraction =
              (phase.endWeek - phase.startWeek + 1) / program.totalWeeks;
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
        color: color.withOpacity(0.15),
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
