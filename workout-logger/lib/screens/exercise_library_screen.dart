// Exercise Library Screen - Browse and search exercises

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import '../data/exercise_database.dart';
import 'add_custom_exercise_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _searchQuery = '';
  String? _selectedMuscleGroup;

  @override
  Widget build(BuildContext context) {
    // Use Provider's exercise list (includes custom exercises)
    final allExercises = context.watch<WorkoutProvider>().allExercises;

    // Filter exercises
    var filteredExercises = allExercises.where((e) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          e.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesMuscle =
          _selectedMuscleGroup == null ||
          e.muscleActivations.any(
            (m) => m.muscleGroupId == _selectedMuscleGroup,
          );
      return matchesSearch && matchesMuscle;
    }).toList();

    // Sort: custom exercises first within each group for visibility
    filteredExercises.sort((a, b) {
      // First by custom status (custom first)
      if (a.isCustom && !b.isCustom) return -1;
      if (!a.isCustom && b.isCustom) return 1;
      // Then alphabetically
      return a.name.compareTo(b.name);
    });

    // Group by primary muscle
    final grouped = <String, List<Exercise>>{};
    for (var exercise in filteredExercises) {
      final primary = exercise.primaryMuscle;
      grouped.putIfAbsent(primary, () => []).add(exercise);
    }

    // Count custom exercises for display
    final customCount = allExercises.where((e) => e.isCustom).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        actions: [
          if (customCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$customCount custom',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => const AddCustomExerciseScreen(),
            ),
          );
          // No need to manually refresh - Provider will notify listeners
          if (result == true && mounted) {
            // Optional: Show a subtle confirmation
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Muscle group filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedMuscleGroup == null,
                  onSelected: (_) =>
                      setState(() => _selectedMuscleGroup = null),
                ),
                const SizedBox(width: 8),
                ...MuscleGroups.names.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: _selectedMuscleGroup == entry.key,
                      selectedColor: AppTheme.getMuscleColor(
                        entry.key,
                      ).withValues(alpha: 0.3),
                      onSelected: (selected) => setState(() {
                        _selectedMuscleGroup = selected ? entry.key : null;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Exercise list
          Expanded(
            child: grouped.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      top: AppSpacing.md,
                      bottom: 80, // Space for FAB
                    ),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final muscleId = grouped.keys.elementAt(index);
                      final exercises = grouped[muscleId]!;
                      final muscleName =
                          MuscleGroups.names[muscleId] ?? muscleId;
                      final muscleColor = AppTheme.getMuscleColor(muscleId);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: muscleColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  muscleName,
                                  style: TextStyle(
                                    color: muscleColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${exercises.length})',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...exercises.map(
                            (exercise) => _ExerciseCard(exercise: exercise),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No exercises found',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _showExerciseDetails(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Icon with custom badge
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: exercise.isCustom
                          ? AppTheme.warning.withValues(alpha: 0.2)
                          : AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      exercise.category == 'compound'
                          ? Icons.fitness_center
                          : Icons.accessibility_new,
                      color: exercise.isCustom
                          ? AppTheme.warning
                          : AppTheme.primaryColor,
                    ),
                  ),
                  if (exercise.isCustom)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.warning,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: exercise.category == 'compound'
                                ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                : AppTheme.secondaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            exercise.category.toUpperCase(),
                            style: TextStyle(
                              color: exercise.category == 'compound'
                                  ? AppTheme.primaryColor
                                  : AppTheme.secondaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (exercise.isCustom) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CUSTOM',
                              style: TextStyle(
                                color: AppTheme.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          '${exercise.muscleActivations.length} muscle${exercise.muscleActivations.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showExerciseDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ExerciseDetailsSheet(exercise: exercise),
    );
  }
}

class _ExerciseDetailsSheet extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseDetailsSheet({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final lastSession = provider.getLastSessionForExercise(exercise.id);
    final growthModel = provider.getGrowthModel(exercise.id);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Header
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: exercise.isCustom
                          ? AppTheme.warning.withValues(alpha: 0.2)
                          : AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      exercise.category == 'compound'
                          ? Icons.fitness_center
                          : Icons.accessibility_new,
                      color: exercise.isCustom
                          ? AppTheme.warning
                          : AppTheme.primaryColor,
                    ),
                  ),
                  if (exercise.isCustom)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppTheme.warning,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 10,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        Text(
                          exercise.category == 'compound'
                              ? 'Compound Exercise'
                              : 'Isolation Exercise',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        if (exercise.isCustom) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CUSTOM',
                              style: TextStyle(
                                color: AppTheme.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Delete button for custom exercises
              if (exercise.isCustom)
                IconButton(
                  onPressed: () => _confirmDelete(context, provider),
                  icon: const Icon(Icons.delete_outline),
                  color: AppTheme.error,
                  tooltip: 'Delete custom exercise',
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Muscle activations
          Text(
            'Muscle Activation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...exercise.muscleActivations.map((activation) {
            final muscleName =
                MuscleGroups.names[activation.muscleGroupId] ??
                activation.muscleGroupId;
            final color = AppTheme.getMuscleColor(activation.muscleGroupId);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(muscleName)),
                  Text(
                    '${activation.activationPercentage}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),

          if (lastSession != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Last Session',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: lastSession.sets.asMap().entries.map((entry) {
                final set = entry.value;
                return Chip(
                  label: Text('${set.weight}kg × ${set.reps}'),
                  backgroundColor: AppTheme.surfaceColor,
                );
              }).toList(),
            ),
          ],

          if (growthModel != null && growthModel.r2 > 0.2) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Growing at +${growthModel.slope.toStringAsFixed(1)} kg volume/session',
                      style: const TextStyle(color: AppTheme.success),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WorkoutProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Custom Exercise?'),
        content: Text(
          'Are you sure you want to delete "${exercise.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await provider.deleteCustomExercise(exercise.id);
      if (success && context.mounted) {
        // Capture messenger before pop to avoid deactivated context
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(); // Close the bottom sheet
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success),
                const SizedBox(width: 8),
                Text('"${exercise.name}" deleted'),
              ],
            ),
            backgroundColor: AppTheme.cardColor,
          ),
        );
      }
    }
  }
}

// ==================== Exercise Selector Screen ====================

class ExerciseSelectorScreen extends StatefulWidget {
  final bool selectionMode;
  final Function(List<String>)? onExercisesSelected;

  const ExerciseSelectorScreen({
    super.key,
    this.selectionMode = false,
    this.onExercisesSelected,
  });

  @override
  State<ExerciseSelectorScreen> createState() => _ExerciseSelectorScreenState();
}

class _ExerciseSelectorScreenState extends State<ExerciseSelectorScreen> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Use Provider's exercise list (includes custom exercises)
    final allExercises = context.watch<WorkoutProvider>().allExercises;

    var filteredExercises = allExercises.where((e) {
      return _searchQuery.isEmpty ||
          e.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort alphabetically within groups
    filteredExercises.sort((a, b) => a.name.compareTo(b.name));

    // Group by primary muscle
    final grouped = <String, List<Exercise>>{};
    for (var exercise in filteredExercises) {
      final primary = exercise.primaryMuscle;
      grouped.putIfAbsent(primary, () => []).add(exercise);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search exercises...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        if (widget.selectionMode && _selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedIds.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final muscleId = grouped.keys.elementAt(index);
              final exercises = grouped[muscleId]!;
              final muscleName = MuscleGroups.names[muscleId] ?? muscleId;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      muscleName,
                      style: TextStyle(
                        color: AppTheme.getMuscleColor(muscleId),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...exercises.map((exercise) {
                    final isSelected = _selectedIds.contains(exercise.id);
                    return ListTile(
                      leading: widget.selectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(exercise.id);
                                  } else {
                                    _selectedIds.remove(exercise.id);
                                  }
                                });
                              },
                            )
                          : null,
                      title: Text(exercise.name),
                      subtitle: Text(exercise.category),
                      trailing: widget.selectionMode && isSelected
                          ? Text(
                              '${_selectedIds.toList().indexOf(exercise.id) + 1}',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                      onTap: widget.selectionMode
                          ? () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(exercise.id);
                                } else {
                                  _selectedIds.add(exercise.id);
                                }
                              });
                            }
                          : null,
                    );
                  }),
                ],
              );
            },
          ),
        ),

        if (widget.selectionMode)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () {
                        widget.onExercisesSelected?.call(_selectedIds.toList());
                      },
                child: Text('Start with ${_selectedIds.length} exercises'),
              ),
            ),
          ),
      ],
    );
  }
}
