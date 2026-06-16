// program_detail_screen.dart — Full training program view

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../workout_flow_screen.dart';
import '../widgets/workout_conflict_dialog.dart';
import '../widgets/program_week_tile.dart';

class ProgramDetailScreen extends StatefulWidget {
  const ProgramDetailScreen({super.key, required this.program});
  final TrainingProgram program;

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  late TrainingProgram _program;

  @override
  void initState() {
    super.initState();
    _program = widget.program;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textSoft),
        title: Text(
          _program.name,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          PopupMenuButton<String>(
            color: AppColors.cardHigh,
            onSelected: _handleMenuAction,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'export',
                child: Text(
                  'Export JSON',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (_program.phases.isNotEmpty)
            SliverToBoxAdapter(child: _buildPhaseTimeline()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: const Text(
                'WEEKS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProgramWeekTile(
                key: ValueKey('week_$index'),
                week: _program.weeks[index],
                weekIndex: index,
                program: _program,
                provider: provider,
                onStartDay: _startProgramDayWorkout,
              ),
              childCount: _program.weeks.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  Future<void> _startProgramDayWorkout(ProgramDay day, ProgramWeek week) async {
    final provider = context.read<WorkoutProvider>();
    StartWorkoutConflictAction conflictAction = StartWorkoutConflictAction.cancel;

    final started = await provider.startWorkoutSafely(
      exerciseIds: day.exercises.map((slot) => slot.exerciseId).toList(),
      programDay: day,
      programWeek: week,
      onConflict: () async {
        final action = await showWorkoutConflictDialog(
          context,
          workoutStartTime: provider.workoutStartTime ?? DateTime.now(),
        );
        conflictAction = action ?? StartWorkoutConflictAction.cancel;
        return conflictAction;
      },
    );

    if (!mounted) return;
    if (started || conflictAction == StartWorkoutConflictAction.resume) {
      final resumeDay =
          provider.hasActiveWorkout ? provider.activeProgramDay : day;
      final resumeWeek =
          provider.hasActiveWorkout ? provider.activeProgramWeek : week;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutFlowScreen(
            programDay: resumeDay,
            programWeek: resumeWeek,
          ),
        ),
      );
    }
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final deloadCount = _program.weeks.where((w) => w.isDeload).length;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_program.description != null) ...[
            Text(
              _program.description!,
              style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _statChip(
                icon: Icons.calendar_today_rounded,
                label: '${_program.totalWeeks} weeks',
                color: AppColors.primary,
              ),
              _statChip(
                icon: Icons.bolt_rounded,
                label: '${_program.phases.length} phases',
                color: AppColors.secondary,
              ),
              if (deloadCount > 0)
                _statChip(
                  icon: Icons.battery_charging_full_rounded,
                  label: '$deloadCount deload${deloadCount > 1 ? 's' : ''}',
                  color: Colors.amber,
                ),
            ],
          ),
          if (_program.author != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'by ${_program.author}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          if (_program.isImported) ...[
            const SizedBox(height: AppSpacing.xs),
            const Row(
              children: [
                Icon(Icons.download_done_rounded, size: 12, color: AppColors.textMuted),
                SizedBox(width: 4),
                Text(
                  'Imported',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase Timeline ───────────────────────────────────────────────────────────

  Widget _buildPhaseTimeline() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PHASES',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 8,
            child: Row(
              children: _program.phases.asMap().entries.map((entry) {
                final phase = entry.value;
                final fraction =
                    (phase.endWeek - phase.startWeek + 1) / _program.totalWeeks;
                final color =
                    kProgramPhaseColors[entry.key % kProgramPhaseColors.length];
                return Expanded(
                  flex: ((fraction * 100).round()).clamp(1, 100),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: _program.phases.asMap().entries.map((entry) {
              final phase = entry.value;
              final color =
                  kProgramPhaseColors[entry.key % kProgramPhaseColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${phase.name} (W${phase.startWeek}–${phase.endWeek})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSoft,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportProgram();
        break;
      case 'delete':
        _confirmDelete();
        break;
    }
  }

  void _exportProgram() {
    final provider = context.read<WorkoutProvider>();
    final json = provider.programManager.exportToJson(_program);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Export Program',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppColors.textSoft,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'JSON copied to clipboard',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  backgroundColor: AppColors.cardHigh,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              );
            },
            child: const Text(
              'Copy',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.textSoft),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Delete Program?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Delete "${_program.name}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSoft),
            ),
          ),
          TextButton(
            onPressed: () async {
              final provider = context.read<WorkoutProvider>();
              await provider.programManager.deleteProgram(_program.id);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}