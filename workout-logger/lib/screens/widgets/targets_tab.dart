// targets_tab.dart — Analytics "Targets" tab with create/manage targets

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../data/exercise_database.dart';
import 'rf_widgets.dart';
import 'rf_cards.dart';

class TargetsTab extends StatelessWidget {
  const TargetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final targets = provider.targets;
    final active = targets.where((t) => !t.isCompleted).toList();
    final completed = targets.where((t) => t.isCompleted).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: targets.isEmpty
          ? RFEmptyState(
              icon: Icons.flag_rounded,
              title: 'No Targets Set',
              subtitle: 'Set a goal to track your progress',
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (active.isNotEmpty) ...[
                    const RFSectionHeader('Active'),
                    const SizedBox(height: AppSpacing.sm),
                    ...active.map(
                      (t) => TargetCard(
                        target: t,
                        exerciseName: provider.getExerciseName(t.exerciseId),
                        onDelete: () => provider.deleteTarget(t.id),
                      ),
                    ),
                  ],
                  if (completed.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const RFSectionHeader('Completed'),
                    const SizedBox(height: AppSpacing.sm),
                    ...completed.map(
                      (t) => TargetCard(
                        target: t,
                        exerciseName: provider.getExerciseName(t.exerciseId),
                        onDelete: () => provider.deleteTarget(t.id),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: AppColors.primary,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Target',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _CreateTargetSheet(),
    );
  }
}

// ── Create target bottom sheet ─────────────────────────────────────────────────
class _CreateTargetSheet extends StatefulWidget {
  const _CreateTargetSheet();

  @override
  State<_CreateTargetSheet> createState() => _CreateTargetSheetState();
}

class _CreateTargetSheetState extends State<_CreateTargetSheet> {
  String? _selectedExerciseId;
  String _targetType = 'weight';
  final _valueController = TextEditingController();
  bool _isSubmitting = false;

  static const _types = [
    ('weight', 'Max Weight (kg)'),
    ('reps', 'Max Reps'),
    ('volume', 'Total Volume (kg)'),
  ];

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ExerciseDatabase.getAll();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'New Target',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Exercise picker
          const Text(
            'EXERCISE',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: DropdownButton<String>(
              value: _selectedExerciseId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AppColors.cardHigh,
              hint: const Text(
                'Select exercise…',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              items: exercises
                  .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedExerciseId = v),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Target type
          const Text(
            'TARGET TYPE',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _types.map((t) {
              final selected = _targetType == t.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _targetType = t.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Text(
                      t.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? AppColors.primary : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.md),

          // Value input
          const Text(
            'TARGET VALUE',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g. 100',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          GlowButton(
            label: 'Create Target',
            icon: Icons.flag_rounded,
            onPressed: _isSubmitting ? null : _submit,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selectedExerciseId == null || _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: AppColors.cardHigh,
        ),
      );
      return;
    }
    final value = double.tryParse(_valueController.text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid target value'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<WorkoutProvider>().createTarget(
            exerciseId: _selectedExerciseId!,
            type: _targetType,
            targetValue: value,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
