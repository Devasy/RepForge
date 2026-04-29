// Routines Screen - Manage workout routines and training programs

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import '../data/exercise_database.dart';
import 'workout_flow_screen.dart';
import 'programs/programs_screen.dart';
import 'widgets/workout_conflict_dialog.dart';

Future<void> _startRoutineWorkoutFlow(
  BuildContext context,
  Routine routine,
) async {
  final provider = context.read<WorkoutProvider>();
  StartWorkoutConflictAction conflictAction = StartWorkoutConflictAction.cancel;

  final started = await provider.startWorkoutSafely(
    routine: routine,
    onConflict: () async {
      final action = await showWorkoutConflictDialog(
        context,
        workoutStartTime: provider.workoutStartTime ?? DateTime.now(),
      );
      conflictAction = action ?? StartWorkoutConflictAction.cancel;
      return conflictAction;
    },
  );

  if (!context.mounted) return;
  if (started || conflictAction == StartWorkoutConflictAction.resume) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutFlowScreen(routine: routine)),
    );
  }
}

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Routines'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Routines'),
              Tab(icon: Icon(Icons.calendar_month), text: 'Programs'),
            ],
          ),
        ),
        body: const TabBarView(children: [_RoutinesTab(), ProgramsScreen()]),
      ),
    );
  }
}

class _RoutinesTab extends StatelessWidget {
  const _RoutinesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final routines = provider.routines;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
                    onPressed: () => _startRoutineWorkoutFlow(context, routine),
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
              leading: const Icon(Icons.copy),
              title: const Text('Clone Routine'),
              onTap: () {
                Navigator.pop(context);
                _showCloneDialog(context);
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

  void _showCloneDialog(BuildContext context) {
    final controller = TextEditingController(text: routine.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clone Routine'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Routine Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                provider.createRoutine(newName, routine.exerciseIds);
                Navigator.pop(context);
              }
            },
            child: const Text('Clone'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
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
    // Use provider's exercises list (includes custom exercises)
    final provider = context.watch<WorkoutProvider>();
    final exercises = provider.allExercises;

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
                      onPressed: () => _showExercisePicker(exercises),
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
                    subtitle: Text(
                      exercise?.category ?? '',
                      style: const TextStyle(fontSize: 12),
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

  void _showExercisePicker(List<Exercise> allExercises) {
    // Local state for picker search - scoped to this modal only
    String pickerSearchQuery = '';
    // Use List instead of Set to preserve selection order
    final List<String> tempSelectedIds = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Filter exercises by search and exclude already selected
          var filteredExercises = allExercises.where((ex) {
            if (_selectedExerciseIds.contains(ex.id)) return false;
            if (pickerSearchQuery.isEmpty) return true;
            return ex.name.toLowerCase().contains(
              pickerSearchQuery.toLowerCase(),
            );
          }).toList();

          // Group by muscle
          final grouped = <String, List<Exercise>>{};
          for (var ex in filteredExercises) {
            final primary = ex.primaryMuscle;
            grouped.putIfAbsent(primary, () => []).add(ex);
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Fixed header with search and done button
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Add Exercises',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (tempSelectedIds.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedExerciseIds.addAll(
                                      tempSelectedIds,
                                    );
                                  });
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.check),
                                label: Text('Add ${tempSelectedIds.length}'),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Search field
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search exercises...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: pickerSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setModalState(
                                        () => pickerSearchQuery = '',
                                      );
                                    },
                                  )
                                : null,
                            isDense: true,
                          ),
                          onChanged: (val) {
                            setModalState(() => pickerSearchQuery = val);
                          },
                        ),
                        if (tempSelectedIds.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${tempSelectedIds.length} exercise${tempSelectedIds.length > 1 ? 's' : ''} selected',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Scrollable exercise list
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      children: [
                        ...grouped.entries.map((entry) {
                          final muscleName =
                              MuscleGroups.names[entry.key] ?? entry.key;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                child: Text(
                                  muscleName,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ...entry.value.map((exercise) {
                                final isSelected = tempSelectedIds.contains(
                                  exercise.id,
                                );
                                return ListTile(
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          // Prevent duplicates
                                          if (!tempSelectedIds.contains(
                                            exercise.id,
                                          )) {
                                            tempSelectedIds.add(exercise.id);
                                          }
                                        } else {
                                          tempSelectedIds.remove(exercise.id);
                                        }
                                      });
                                    },
                                  ),
                                  title: Text(
                                    exercise.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : null,
                                    ),
                                  ),
                                  subtitle: exercise.isCustom
                                      ? const Text(
                                          'Custom',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: AppTheme.primaryColor,
                                        )
                                      : const Icon(
                                          Icons.add_circle_outline,
                                          color: AppTheme.textMuted,
                                        ),
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        tempSelectedIds.remove(exercise.id);
                                      } else {
                                        // Prevent duplicates
                                        if (!tempSelectedIds.contains(
                                          exercise.id,
                                        )) {
                                          tempSelectedIds.add(exercise.id);
                                        }
                                      }
                                    });
                                  },
                                );
                              }),
                            ],
                          );
                        }),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
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
                  ? Text(
                      '${exercise.category} • ${MuscleGroups.names[exercise.primaryMuscle] ?? ""}',
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _startRoutineWorkoutFlow(context, routine);
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Workout'),
      ),
    );
  }
}
