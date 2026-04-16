// Add Custom Exercise Screen - Form for creating user-defined exercises

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/workout_provider.dart';
import '../data/exercise_database.dart';
import '../theme/app_theme.dart';

class AddCustomExerciseScreen extends StatefulWidget {
  const AddCustomExerciseScreen({super.key});

  @override
  State<AddCustomExerciseScreen> createState() =>
      _AddCustomExerciseScreenState();
}

class _AddCustomExerciseScreenState extends State<AddCustomExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedCategory = 'compound';
  String? _selectedMuscleGroup;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMuscleGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a primary muscle group'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<WorkoutProvider>();
      await provider.addCustomExercise(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        primaryMuscleGroupId: _selectedMuscleGroup!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success),
                const SizedBox(width: 8),
                Text('${_nameController.text.trim()} added successfully!'),
              ],
            ),
            backgroundColor: AppTheme.cardColor,
          ),
        );
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      debugPrint('Failed to save custom exercise: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save exercise. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Custom Exercise'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _saveExercise,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Create a custom exercise to track workouts not in the built-in library.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Exercise Name
              Text(
                'Exercise Name',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Cable Lateral Raise',
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an exercise name';
                  }
                  if (value.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              // Category Selection
              Text(
                'Exercise Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'compound',
                    label: Text('Compound'),
                    icon: Icon(Icons.fitness_center),
                  ),
                  ButtonSegment(
                    value: 'isolation',
                    label: Text('Isolation'),
                    icon: Icon(Icons.accessibility_new),
                  ),
                ],
                selected: {_selectedCategory},
                onSelectionChanged: (Set<String> selection) {
                  setState(() => _selectedCategory = selection.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.primaryColor.withValues(alpha: 0.2);
                    }
                    return AppTheme.surfaceColor;
                  }),
                ),
              ),

              const SizedBox(height: AppSpacing.xs),
              Text(
                _selectedCategory == 'compound'
                    ? 'Works multiple muscle groups (e.g., squats, bench press)'
                    : 'Targets a single muscle group (e.g., bicep curls)',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Primary Muscle Group
              Text(
                'Primary Muscle Group',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Muscle Group Grid
              Builder(
                builder: (context) {
                  // Materialize keys once to avoid O(n²) lookup
                  final muscleKeys = MuscleGroups.names.keys.toList();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                        ),
                    itemCount: muscleKeys.length,
                    itemBuilder: (context, index) {
                      final muscleId = muscleKeys[index];
                      final muscleName = MuscleGroups.names[muscleId]!;
                      final muscleColor = AppTheme.getMuscleColor(muscleId);
                      final isSelected = _selectedMuscleGroup == muscleId;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedMuscleGroup = muscleId),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? muscleColor.withValues(alpha: 0.3)
                                  : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: isSelected
                                    ? muscleColor
                                    : AppTheme.cardColor,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSelected) ...[
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: muscleColor,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      muscleName,
                                      style: TextStyle(
                                        color: isSelected
                                            ? muscleColor
                                            : AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
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
                },
              ),

              if (_selectedMuscleGroup != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppTheme.getMuscleColor(
                      _selectedMuscleGroup!,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.getMuscleColor(_selectedMuscleGroup!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Primary: ${MuscleGroups.names[_selectedMuscleGroup]}',
                        style: TextStyle(
                          color: AppTheme.getMuscleColor(_selectedMuscleGroup!),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _saveExercise,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(_isSubmitting ? 'Saving...' : 'Add Exercise'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
