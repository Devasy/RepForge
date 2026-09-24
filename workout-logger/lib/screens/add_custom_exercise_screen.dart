// add_custom_exercise_screen.dart — Form for creating or editing an exercise

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../data/exercise_database.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';

class AddCustomExerciseScreen extends StatefulWidget {
  final Exercise? initialExercise;

  const AddCustomExerciseScreen({super.key, this.initialExercise});

  @override
  State<AddCustomExerciseScreen> createState() =>
      _AddCustomExerciseScreenState();
}

class _AddCustomExerciseScreenState extends State<AddCustomExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final TextEditingController _handleInputController = TextEditingController();

  late String _category;
  late String? _muscleId;
  late ExerciseType _exerciseType;
  late List<String> _availableHandles;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialExercise != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initialExercise;
    _nameController = TextEditingController(text: init?.name ?? '');
    _category = init?.category ?? 'compound';
    _muscleId = (init != null && init.muscleActivations.isNotEmpty)
        ? init.primaryMuscle
        : null;
    _exerciseType = init?.exerciseType ?? ExerciseType.weightAndReps;
    _availableHandles = List<String>.from(init?.availableHandles ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleInputController.dispose();
    super.dispose();
  }

  void _addHandle() {
    final text = _handleInputController.text.trim();
    if (text.isEmpty) return;
    if (_availableHandles.any((h) => h.toLowerCase() == text.toLowerCase())) {
      _handleInputController.clear();
      return;
    }
    setState(() {
      _availableHandles.add(text);
      _handleInputController.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_muscleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a primary muscle group'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final provider = context.read<WorkoutProvider>();
    final exerciseName = _nameController.text.trim();
    final handles = _isEditing
        ? _availableHandles
        : (_availableHandles.isEmpty ? null : _availableHandles);

    try {
      if (_isEditing) {
        await provider.updateExercise(
          id: widget.initialExercise!.id,
          name: exerciseName,
          category: _category,
          primaryMuscleGroupId: _muscleId!,
          exerciseType: _exerciseType,
          availableHandles: handles,
        );
      } else {
        await provider.addCustomExercise(
          name: exerciseName,
          category: _category,
          primaryMuscleGroupId: _muscleId!,
          exerciseType: _exerciseType,
          availableHandles: handles,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? '$exerciseName updated!' : '$exerciseName added!',
            ),
            backgroundColor: AppColors.cardHigh,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Failed to save exercise: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _isEditing ? 'Edit Exercise' : 'New Exercise',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textSoft),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _save,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _isEditing
                            ? 'Update exercise tracking type, attachments, category, or muscle group.'
                            : 'Create a custom exercise to track workouts not in the built-in library.',
                        style: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Name
              _label('EXERCISE NAME'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: TextFormField(
                  controller: _nameController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  decoration: const InputDecoration(
                    hintText: 'e.g., Cable Lateral Raise',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    prefixIcon: Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter an exercise name';
                    }
                    if (v.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Tracking Mode
              _label('TRACKING TYPE'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _CategoryTile(
                    label: 'Reps & Weight',
                    icon: Icons.repeat_rounded,
                    description: 'Sets & repetitions',
                    selected: _exerciseType == ExerciseType.weightAndReps,
                    onTap: () => setState(
                      () => _exerciseType = ExerciseType.weightAndReps,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryTile(
                    label: 'Time-Based',
                    icon: Icons.timer_rounded,
                    description: 'Holds & duration (s)',
                    selected: _exerciseType == ExerciseType.timeBased,
                    onTap: () => setState(
                      () => _exerciseType = ExerciseType.timeBased,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Category toggle
              _label('EXERCISE CATEGORY'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _CategoryTile(
                    label: 'Compound',
                    icon: Icons.fitness_center_rounded,
                    description: 'Multiple muscle groups',
                    selected: _category == 'compound',
                    onTap: () => setState(() => _category = 'compound'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryTile(
                    label: 'Isolation',
                    icon: Icons.accessibility_new_rounded,
                    description: 'Single muscle group',
                    selected: _category == 'isolation',
                    onTap: () => setState(() => _category = 'isolation'),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Attachments & Handles section
              _label('ATTACHMENTS / HANDLES (OPTIONAL)'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _handleInputController,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Rope, V-Bar, Straight Bar',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        onSubmitted: (_) => _addHandle(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      tooltip: 'Add attachment',
                      onPressed: _addHandle,
                    ),
                  ],
                ),
              ),
              if (_availableHandles.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: _availableHandles.map((handle) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            handle,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(
                              () => _availableHandles.remove(handle),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Muscle group grid
              _label('PRIMARY MUSCLE GROUP'),
              const SizedBox(height: AppSpacing.sm),
              _MuscleGrid(
                selected: _muscleId,
                onSelect: (id) => setState(() => _muscleId = id),
              ),

              if (_muscleId != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.muscle(_muscleId!)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.muscle(_muscleId!)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.muscle(_muscleId!),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Primary: ${MuscleGroups.names[_muscleId]}',
                        style: TextStyle(
                          color: AppColors.muscle(_muscleId!),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              GlowButton(
                label: _isSubmitting
                    ? 'Saving…'
                    : (_isEditing ? 'Save Changes' : 'Add Exercise'),
                icon: _isEditing ? Icons.check_rounded : Icons.add_rounded,
                onPressed: _isSubmitting ? null : _save,
                fullWidth: true,
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.glassBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Muscle group grid ─────────────────────────────────────────────────────────
class _MuscleGrid extends StatelessWidget {
  const _MuscleGrid({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final keys = MuscleGroups.names.keys.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final id = keys[i];
        final name = MuscleGroups.names[id]!;
        final color = AppColors.muscle(id);
        final isSelected = selected == id;

        return GestureDetector(
          onTap: () => onSelect(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.2)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.6)
                    : AppColors.glassBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      Icon(Icons.check_rounded, size: 12, color: color),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? color : AppColors.textSoft,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
