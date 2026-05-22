// Agent Confirm Screen
//
// Surfaces a write the OS AI agent proposed (create custom exercise / create
// routine) and lets the user confirm before it touches local storage. Reached
// via deep link when an Android AppFunction write is invoked.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/exercise_database.dart';
import '../models/models.dart';
import '../services/agent_action.dart';
import '../services/agent_data_service.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';

class AgentConfirmScreen extends StatefulWidget {
  final AgentPendingAction action;

  const AgentConfirmScreen({super.key, required this.action});

  @override
  State<AgentConfirmScreen> createState() => _AgentConfirmScreenState();
}

class _AgentConfirmScreenState extends State<AgentConfirmScreen> {
  bool _submitting = false;

  AgentPendingAction get _action => widget.action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _action.isCreateExercise
                    ? _exerciseProposal(context)
                    : _action.isCreateRoutine
                        ? _routineProposal(context)
                        : _unknownProposal(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSoft),
            onPressed: _submitting ? null : () => _dismiss(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  'AI suggestion',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── create-exercise proposal ────────────────────────────────────────────────

  Widget _exerciseProposal(BuildContext context) {
    final agent = AgentDataService(context.read<WorkoutProvider>());
    final name = (_action.data['name'] as String?)?.trim() ?? '';
    final category = _normalizeCategory(_action.data['category']);

    final rawMuscle =
        (_action.data['primaryMuscle'] ?? _action.data['muscle'] ?? '')
            .toString();
    final muscleId = agent.resolveMuscleGroup(rawMuscle);
    final muscleName =
        muscleId == null ? null : MuscleGroups.names[muscleId] ?? muscleId;

    final canConfirm = name.isNotEmpty && muscleId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Create a custom exercise', Icons.fitness_center),
        const SizedBox(height: AppSpacing.md),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Name', name.isEmpty ? 'Missing' : name,
                  isError: name.isEmpty),
              const Divider(height: AppSpacing.lg),
              _field('Category', _capitalize(category)),
              const Divider(height: AppSpacing.lg),
              _field(
                'Primary muscle',
                muscleName ?? 'Unrecognized: "$rawMuscle"',
                isError: muscleId == null,
                accent: muscleId == null ? null : AppColors.muscle(muscleId),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _actions(
          context,
          canConfirm: canConfirm,
          confirmLabel: 'Create exercise',
          onConfirm: () => _confirmExercise(
            context,
            name: name,
            category: category,
            muscleId: muscleId!,
          ),
        ),
      ],
    );
  }

  // ── create-routine proposal ─────────────────────────────────────────────────

  Widget _routineProposal(BuildContext context) {
    final agent = AgentDataService(context.read<WorkoutProvider>());
    final name = (_action.data['name'] as String?)?.trim() ?? '';

    final rawList =
        _action.data['exercises'] ?? _action.data['exerciseNames'] ?? const [];
    final requested = rawList is List
        ? rawList.map((e) => e.toString()).toList()
        : <String>[];

    final resolved = <Exercise>[];
    final unresolved = <String>[];
    for (final query in requested) {
      final exercise = agent.resolveExercise(query);
      if (exercise == null) {
        unresolved.add(query);
      } else if (!resolved.any((e) => e.id == exercise.id)) {
        resolved.add(exercise);
      }
    }

    final canConfirm = name.isNotEmpty && resolved.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Create a routine', Icons.list_alt),
        const SizedBox(height: AppSpacing.md),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('Name', name.isEmpty ? 'Missing' : name,
                  isError: name.isEmpty),
              const Divider(height: AppSpacing.lg),
              Text('Exercises (${resolved.length})',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final exercise in resolved)
                _exerciseRow(exercise.name, exercise.primaryMuscle, true),
              for (final missing in unresolved)
                _exerciseRow(missing, null, false),
            ],
          ),
        ),
        if (unresolved.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${unresolved.length} exercise(s) could not be matched and will '
            'be skipped.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.warning),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _actions(
          context,
          canConfirm: canConfirm,
          confirmLabel: 'Create routine',
          onConfirm: () => _confirmRoutine(
            context,
            name: name,
            exerciseIds: resolved.map((e) => e.id).toList(),
          ),
        ),
      ],
    );
  }

  Widget _unknownProposal() => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'This AI suggestion could not be understood.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );

  // ── shared widgets ──────────────────────────────────────────────────────────

  Widget _title(String text, IconData icon) => Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.headlineSmall),
          ),
        ],
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: child,
      );

  Widget _field(String label, String value,
      {bool isError = false, Color? accent}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: Theme.of(context).textTheme.labelMedium),
        ),
        if (accent != null) ...[
          Container(
            margin: const EdgeInsets.only(top: 3, right: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ],
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isError ? AppColors.error : AppColors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }

  Widget _exerciseRow(String name, String? muscleId, bool matched) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            matched ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: matched ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        matched ? AppColors.textPrimary : AppColors.textMuted,
                    decoration:
                        matched ? null : TextDecoration.lineThrough,
                  ),
            ),
          ),
          if (matched && muscleId != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.muscle(muscleId),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context, {
    required bool canConfirm,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _submitting ? null : () => _dismiss(context),
            child: const Text('Discard'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ElevatedButton(
            onPressed: (!canConfirm || _submitting)
                ? null
                : () => _runConfirm(onConfirm),
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(confirmLabel),
          ),
        ),
      ],
    );
  }

  // ── actions ─────────────────────────────────────────────────────────────────

  Future<void> _runConfirm(Future<void> Function() action) async {
    setState(() => _submitting = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmExercise(
    BuildContext context, {
    required String name,
    required String category,
    required String muscleId,
  }) async {
    final provider = context.read<WorkoutProvider>();
    try {
      await provider.addCustomExercise(
        name: name,
        category: category,
        primaryMuscleGroupId: muscleId,
      );
      if (context.mounted) {
        _finish(context, 'Created exercise "$name"');
      }
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _confirmRoutine(
    BuildContext context, {
    required String name,
    required List<String> exerciseIds,
  }) async {
    final provider = context.read<WorkoutProvider>();
    try {
      await provider.createRoutine(name, exerciseIds);
      if (context.mounted) {
        _finish(context, 'Created routine "$name"');
      }
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  void _finish(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    _dismiss(context);
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not complete: $error'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _dismiss(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  String _normalizeCategory(Object? raw) {
    final value = raw?.toString().toLowerCase().trim();
    return value == 'isolation' ? 'isolation' : 'compound';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
