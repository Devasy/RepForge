// routine_optimization_sheet.dart — AI-driven routine optimization bottom sheet.
//
// Shows AI suggestions for reordering, replacing, or adding exercises based on
// past performance data. Each suggestion can be accepted or rejected before applying.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/ai/gemini_ai_service.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/routine_optimizer_view_model.dart';
import 'rf_widgets.dart';

/// Entry point — shows the optimizer sheet or a SnackBar if AI is not configured.
Future<void> showRoutineOptimizerSheet(
  BuildContext context,
  Routine routine,
) async {
  final ai = context.read<GeminiAiService>();
  if (!ai.isConfigured) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Add your Gemini API key in Profile → AI Features to use this feature.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final wp = context.read<WorkoutProvider>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => ChangeNotifierProvider<RoutineOptimizerViewModel>(
      create: (_) => RoutineOptimizerViewModel(ai: ai, wp: wp)
        ..analyzeRoutine(routine),
      child: _OptimizerSheetBody(routine: routine),
    ),
  );
}

// ── Sheet body ────────────────────────────────────────────────────────────────

class _OptimizerSheetBody extends StatelessWidget {
  const _OptimizerSheetBody({required this.routine});
  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoutineOptimizerViewModel>();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                const Icon(Icons.auto_fix_high_rounded,
                    color: AppColors.secondary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Optimize "${routine.name}"',
                    style: GoogleFonts.geist(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            switch (vm.state) {
              OptimizerState.idle => const SizedBox.shrink(),
              OptimizerState.loading => _LoadingView(),
              OptimizerState.error => _ErrorView(
                  message: vm.errorMessage ?? 'Unknown error',
                  onRetry: () => vm.analyzeRoutine(routine),
                ),
              OptimizerState.success => _SuccessView(
                  routine: routine,
                  vm: vm,
                ),
            },
          ],
        ),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.secondary),
            strokeWidth: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Reviewing your performance data…',
            style: GoogleFonts.geist(
              fontSize: 14,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Analysing exercise trends and muscle coverage',
            style: GoogleFonts.geist(
              fontSize: 12,
              color: AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 40),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not analyse routine',
            style: GoogleFonts.geist(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.geist(fontSize: 12, color: AppColors.textFaint),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlowButton(
            label: 'Try Again',
            icon: Icons.refresh_rounded,
            color: AppColors.secondary,
            onPressed: onRetry,
            fullWidth: false,
            small: true,
          ),
        ],
      ),
    );
  }
}

// ── Success state ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.routine, required this.vm});
  final Routine routine;
  final RoutineOptimizerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final result = vm.result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        if (result.summary.isNotEmpty) ...[
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              result.summary,
              style: GoogleFonts.geist(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSoft,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (result.suggestions.isEmpty) ...[
          Center(
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.success, size: 40),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your routine looks well-balanced!',
                  style: GoogleFonts.geist(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            'SUGGESTIONS (${result.suggestions.length})',
            style: GoogleFonts.geist(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.textFaint,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          for (var i = 0; i < result.suggestions.length; i++) ...[
            _SuggestionCard(
              index: i,
              suggestion: result.suggestions[i],
              accepted: vm.isSuggestionAccepted(i),
              routineExercises: routine.exerciseIds,
              onToggle: () => vm.toggleSuggestion(i),
            ),
            if (i < result.suggestions.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],

          const SizedBox(height: AppSpacing.xl),

          GlowButton(
            label: 'Apply Suggestions',
            icon: Icons.check_rounded,
            color: AppColors.primary,
            onPressed: vm.applied
                ? null
                : () async {
                    HapticFeedback.heavyImpact();
                    await vm.applyAccepted(routine);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Routine updated successfully.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
        ],
      ],
    );
  }
}

// ── Suggestion card ───────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.index,
    required this.suggestion,
    required this.accepted,
    required this.routineExercises,
    required this.onToggle,
  });

  final int index;
  final RoutineSuggestion suggestion;
  final bool accepted;
  final List<String> routineExercises;
  final VoidCallback onToggle;

  static const _typeConfig = {
    SuggestionType.reorder: (
      icon: Icons.swap_vert_rounded,
      color: AppColors.secondary,
      label: 'REORDER',
    ),
    SuggestionType.replace: (
      icon: Icons.change_circle_outlined,
      color: AppColors.warning,
      label: 'REPLACE',
    ),
    SuggestionType.add: (
      icon: Icons.add_circle_outline_rounded,
      color: AppColors.success,
      label: 'ADD',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[suggestion.type]!;

    return AnimatedOpacity(
      opacity: accepted ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: accepted
            ? cfg.color.withValues(alpha: 0.4)
            : AppColors.glassBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type header
            Row(
              children: [
                Icon(cfg.icon, color: cfg.color, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  cfg.label,
                  style: GoogleFonts.geist(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: cfg.color,
                  ),
                ),
                const Spacer(),
                _AcceptToggle(accepted: accepted, onToggle: onToggle),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Reasoning
            Text(
              suggestion.reasoning,
              style: GoogleFonts.geist(
                fontSize: 13,
                color: AppColors.textSoft,
                height: 1.4,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Type-specific preview
            _buildPreview(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final wp = context.read<WorkoutProvider>();

    switch (suggestion.type) {
      case SuggestionType.reorder:
        final ids = suggestion.reorderedExerciseIds ?? [];
        final shown = ids.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < shown.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${i + 1}. ${wp.getExerciseName(shown[i])}',
                  style: GoogleFonts.geistMono(
                    fontSize: 12,
                    color: AppColors.textFaint,
                  ),
                ),
              ),
            if (ids.length > 5)
              Text(
                '…and ${ids.length - 5} more',
                style: GoogleFonts.geist(
                    fontSize: 11, color: AppColors.textFaint),
              ),
          ],
        );

      case SuggestionType.replace:
        final removeName = suggestion.removeExerciseId != null
            ? wp.getExerciseName(suggestion.removeExerciseId!)
            : '—';
        final addName = suggestion.replaceWithName ?? '—';
        return Row(
          children: [
            Expanded(
              child: Text(
                removeName,
                style: GoogleFonts.geist(
                  fontSize: 12,
                  color: AppColors.error,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.error,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 14, color: AppColors.textFaint),
            ),
            Expanded(
              child: Text(
                addName,
                style: GoogleFonts.geist(
                  fontSize: 12,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

      case SuggestionType.add:
        return Text(
          '+ ${suggestion.addExerciseName ?? '—'}',
          style: GoogleFonts.geist(
            fontSize: 12,
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
        );
    }
  }
}

// ── Accept/Reject toggle ──────────────────────────────────────────────────────

class _AcceptToggle extends StatelessWidget {
  const _AcceptToggle({required this.accepted, required this.onToggle});
  final bool accepted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: accepted
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: accepted
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              accepted ? Icons.check_rounded : Icons.close_rounded,
              size: 12,
              color: accepted ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 4),
            Text(
              accepted ? 'Accept' : 'Reject',
              style: GoogleFonts.geist(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accepted ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
