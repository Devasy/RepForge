// Routines Screen - Manage workout routines

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import '../data/exercise_database.dart';
import 'workout_flow_screen.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final routines = provider.routines;

    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      body: routines.isEmpty
          ? _buildEmptyState(context)
          : _buildRoutineList(context, routines, provider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRoutineDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Routine'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            'No Routines Yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a routine to organize your workouts',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateRoutineDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Routine'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineList(
    BuildContext context,
    List<Routine> routines,
    WorkoutProvider provider,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final routine = routines[index];
        return _RoutineCard(routine: routine, provider: provider);
      },
    );
  }

  void _showCreateRoutineDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRoutineScreen()),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final WorkoutProvider provider;

  const _RoutineCard({required this.routine, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () => _showRoutineDetails(context),
        onLongPress: () => _showRoutineOptions(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${routine.exerciseIds.length} exercises',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill),
                    color: AppTheme.primaryColor,
                    iconSize: 40,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkoutFlowScreen(routine: routine),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: routine.exerciseIds.take(5).map((id) {
                  final name = provider.getExerciseName(id);
                  return Chip(
                    label: Text(name, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              if (routine.exerciseIds.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${routine.exerciseIds.length - 5} more',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoutineDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoutineDetailScreen(routine: routine)),
    );
  }

  void _showRoutineOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Routine'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateRoutineScreen(routine: routine),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.error),
              title: const Text(
                'Delete Routine',
                style: TextStyle(color: AppTheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine?'),
        content: Text('Are you sure you want to delete "${routine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteRoutine(routine.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateRoutineScreen extends StatefulWidget {
  final Routine? routine;

  const CreateRoutineScreen({super.key, this.routine});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _nameController = TextEditingController();
  final List<String> _selectedExerciseIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.routine != null) {
      _nameController.text = widget.routine!.name;
      _selectedExerciseIds.addAll(widget.routine!.exerciseIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine == null ? 'New Routine' : 'Edit Routine'),
        actions: [
          TextButton(onPressed: _saveRoutine, child: const Text('Save')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Routine Name',
                hintText: 'e.g., Push Day, Leg Day',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Text(
                  'Exercises (${_selectedExerciseIds.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_selectedExerciseIds.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedExerciseIds.clear()),
                    child: const Text('Clear All'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _selectedExerciseIds.length + 1,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex >= _selectedExerciseIds.length ||
                    newIndex >= _selectedExerciseIds.length + 1) {
                  return;
                }

                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _selectedExerciseIds.removeAt(oldIndex);
                  _selectedExerciseIds.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                if (index == _selectedExerciseIds.length) {
                  return Padding(
                    key: const ValueKey('add_button'),
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: OutlinedButton.icon(
                      onPressed: () => _showExercisePicker(provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Exercises'),
                    ),
                  );
                }

                final exerciseId = _selectedExerciseIds[index];
                final exercise = provider.getExercise(exerciseId);

                return Card(
                  key: ValueKey(exerciseId),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(
                        Icons.drag_handle,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    title: Text(exercise?.name ?? 'Unknown'),
                    subtitle: Row(
                      children: [
                        Text(
                          exercise?.category ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (exercise?.isCustom == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CUSTOM',
                              style: TextStyle(
                                color: AppTheme.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppTheme.error,
                      ),
                      onPressed: () {
                        setState(() => _selectedExerciseIds.removeAt(index));
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showExercisePicker(WorkoutProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MultiSelectExercisePicker(
        allExercises: provider.allExercises,
        alreadySelectedIds: _selectedExerciseIds,
        onExercisesSelected: (selectedIds) {
          setState(() {
            for (var id in selectedIds) {
              if (!_selectedExerciseIds.contains(id)) {
                _selectedExerciseIds.add(id);
              }
            }
          });
        },
      ),
    );
  }

  void _saveRoutine() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine name')),
      );
      return;
    }

    if (_selectedExerciseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    final provider = context.read<WorkoutProvider>();

    if (widget.routine != null) {
      // Update existing
      final updated = Routine(
        id: widget.routine!.id,
        name: _nameController.text,
        exerciseIds: _selectedExerciseIds,
        createdAt: widget.routine!.createdAt,
      );
      await provider.updateRoutine(updated);
    } else {
      // Create new
      await provider.createRoutine(_nameController.text, _selectedExerciseIds);
    }

    if (mounted) Navigator.pop(context);
  }
}

/// Multi-select exercise picker with search functionality
class _MultiSelectExercisePicker extends StatefulWidget {
  final List<Exercise> allExercises;
  final List<String> alreadySelectedIds;
  final Function(List<String>) onExercisesSelected;

  const _MultiSelectExercisePicker({
    required this.allExercises,
    required this.alreadySelectedIds,
    required this.onExercisesSelected,
  });

  @override
  State<_MultiSelectExercisePicker> createState() =>
      _MultiSelectExercisePickerState();
}

class _MultiSelectExercisePickerState
    extends State<_MultiSelectExercisePicker> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Filter out already selected and apply search
    var availableExercises = widget.allExercises.where((e) {
      final notAlreadySelected = !widget.alreadySelectedIds.contains(e.id);
      final matchesSearch =
          _searchQuery.isEmpty ||
          e.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return notAlreadySelected && matchesSearch;
    }).toList();

    // Sort: custom exercises first, then alphabetically
    availableExercises.sort((a, b) {
      if (a.isCustom && !b.isCustom) return -1;
      if (!a.isCustom && b.isCustom) return 1;
      return a.name.compareTo(b.name);
    });

    // Group by muscle
    final grouped = <String, List<Exercise>>{};
    for (var ex in availableExercises) {
      final primary = ex.primaryMuscle;
      grouped.putIfAbsent(primary, () => []).add(ex);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header with search
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add Exercises',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_selectedIds.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _selectedIds.clear()),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search exercises...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  if (_selectedIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        '${_selectedIds.length} exercise${_selectedIds.length == 1 ? '' : 's'} selected',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Exercise list
            Expanded(
              child: grouped.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No exercises match your search'
                                : 'All exercises already added',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      children: grouped.entries.map((entry) {
                        final muscleName =
                            MuscleGroups.names[entry.key] ?? entry.key;
                        final muscleColor = AppTheme.getMuscleColor(entry.key);
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
                                    height: 16,
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...entry.value.map((exercise) {
                              final isSelected = _selectedIds.contains(
                                exercise.id,
                              );
                              return ListTile(
                                leading: Checkbox(
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
                                ),
                                title: Text(exercise.name),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      exercise.category,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if (exercise.isCustom) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warning.withOpacity(
                                            0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'CUSTOM',
                                          style: TextStyle(
                                            color: AppTheme.warning,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(exercise.id);
                                    } else {
                                      _selectedIds.add(exercise.id);
                                    }
                                  });
                                },
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
            ),

            // Bottom button
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () {
                            widget.onExercisesSelected(_selectedIds.toList());
                            Navigator.pop(context);
                          },
                    child: Text(
                      _selectedIds.isEmpty
                          ? 'Select exercises'
                          : 'Add ${_selectedIds.length} exercise${_selectedIds.length == 1 ? '' : 's'}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class RoutineDetailScreen extends StatelessWidget {
  final Routine routine;

  const RoutineDetailScreen({super.key, required this.routine});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(routine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateRoutineScreen(routine: routine),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: routine.exerciseIds.length,
        itemBuilder: (context, index) {
          final exerciseId = routine.exerciseIds[index];
          final exercise = provider.getExercise(exerciseId);

          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(exercise?.name ?? 'Unknown'),
              subtitle: exercise != null
                  ? Row(
                      children: [
                        Text(
                          '${exercise.category} • ${MuscleGroups.names[exercise.primaryMuscle] ?? ""}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (exercise.isCustom) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CUSTOM',
                              style: TextStyle(
                                color: AppTheme.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : null,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkoutFlowScreen(routine: routine),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Workout'),
      ),
    );
  }
}
