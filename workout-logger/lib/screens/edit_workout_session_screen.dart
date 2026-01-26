// Edit Workout Session Screen - Modify recorded workout sessions

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';

class EditWorkoutSessionScreen extends StatefulWidget {
  final WorkoutSession session;

  const EditWorkoutSessionScreen({super.key, required this.session});

  @override
  State<EditWorkoutSessionScreen> createState() =>
      _EditWorkoutSessionScreenState();
}

class _EditWorkoutSessionScreenState extends State<EditWorkoutSessionScreen> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TextEditingController _notesController;
  late TextEditingController _durationController;
  late List<_EditableExerciseLog> _editableExercises;
  bool _isSubmitting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.session.date;
    _selectedTime = TimeOfDay.fromDateTime(widget.session.date);
    _notesController = TextEditingController(text: widget.session.notes ?? '');
    _durationController = TextEditingController(
      text: widget.session.duration.toString(),
    );

    // Convert to editable structure, preserving all set metadata
    _editableExercises = widget.session.exercises.map((log) {
      return _EditableExerciseLog(
        exerciseId: log.exerciseId,
        sets: log.sets
            .map(
              (set) => _EditableSet(
                weight: set.weight,
                reps: set.reps,
                isDropset: set.isDropset,
                drops: set.drops,
                timeTaken: set.timeTaken,
                timestamp: set.timestamp,
              ),
            )
            .toList(),
        notes: log.notes,
      );
    }).toList();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.cardColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
      _markChanged();
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.cardColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
      _markChanged();
    }
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      // Copy last set values or use defaults
      final lastSet = _editableExercises[exerciseIndex].sets.isNotEmpty
          ? _editableExercises[exerciseIndex].sets.last
          : null;
      _editableExercises[exerciseIndex].sets.add(
        _EditableSet(
          weight: lastSet?.weight ?? 0,
          reps: lastSet?.reps ?? 0,
          isDropset: false,
          drops: null,
          timeTaken: null,
          timestamp: DateTime.now(),
        ),
      );
    });
    _markChanged();
  }

  void _deleteSet(int exerciseIndex, int setIndex) {
    setState(() {
      _editableExercises[exerciseIndex].sets.removeAt(setIndex);
    });
    _markChanged();
  }

  void _deleteExercise(int exerciseIndex) {
    setState(() {
      _editableExercises.removeAt(exerciseIndex);
    });
    _markChanged();
  }

  Future<void> _saveChanges() async {
    // Validate duration
    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid duration'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Validate that there's at least one exercise with sets
    final exercisesWithSets = _editableExercises
        .where((e) => e.sets.isNotEmpty)
        .toList();
    if (exercisesWithSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout must have at least one exercise with sets'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Convert editable exercises back to ExerciseLog, preserving metadata
      final updatedExercises = exercisesWithSets.map((e) {
        return ExerciseLog(
          exerciseId: e.exerciseId,
          sets: e.sets
              .map(
                (s) => WorkoutSet(
                  weight: s.weight,
                  reps: s.reps,
                  isDropset: s.isDropset,
                  drops: s.drops,
                  timeTaken: s.timeTaken,
                  timestamp: s.timestamp,
                ),
              )
              .toList(),
          notes: e.notes,
        );
      }).toList();

      // Create updated session
      final updatedSession = widget.session.copyWith(
        date: _selectedDate,
        duration: duration,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        exercises: updatedExercises,
      );

      // Save via provider
      final provider = context.read<WorkoutProvider>();
      await provider.updateWorkoutSession(updatedSession);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: AppTheme.success),
                SizedBox(width: 8),
                Text('Workout updated successfully'),
              ],
            ),
            backgroundColor: AppTheme.cardColor,
          ),
        );
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      debugPrint('Failed to save workout session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save workout. Please try again.'),
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

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Workout'),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : _saveChanges,
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
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Date & Time Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Date & Time',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Date',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(_selectedDate),
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: _selectTime,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Time',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeFormat.format(_selectedDate),
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Duration & Notes Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 20,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Duration (minutes)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: 'Duration in minutes',
                      ),
                      onChanged: (_) => _markChanged(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Icon(
                          Icons.notes,
                          size: 20,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Notes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Optional workout notes...',
                      ),
                      onChanged: (_) => _markChanged(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Exercises Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exercises',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${_editableExercises.length} exercises',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Exercise Cards
            ..._editableExercises.asMap().entries.map((entry) {
              final exerciseIndex = entry.key;
              final editableLog = entry.value;
              final exercise = provider.getExercise(editableLog.exerciseId);

              return _EditableExerciseCard(
                key: ValueKey('exercise_$exerciseIndex'),
                exerciseName: exercise?.name ?? 'Unknown Exercise',
                editableLog: editableLog,
                onSetChanged: (setIndex, weight, reps, isDropset, drops) {
                  setState(() {
                    editableLog.sets[setIndex].weight = weight;
                    editableLog.sets[setIndex].reps = reps;
                    if (editableLog.sets[setIndex].isDropset != isDropset) {
                      editableLog.sets[setIndex].isDropset = isDropset;
                      if (isDropset &&
                          editableLog.sets[setIndex].drops == null) {
                        editableLog.sets[setIndex].drops = [];
                      }
                    }
                    if (drops != null) {
                      editableLog.sets[setIndex].drops = drops;
                    }
                  });
                  _markChanged();
                },
                onAddSet: () => _addSet(exerciseIndex),
                onDeleteSet: (setIndex) => _deleteSet(exerciseIndex, setIndex),
                onDeleteExercise: () => _deleteExercise(exerciseIndex),
              );
            }),

            if (_editableExercises.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.fitness_center,
                        size: 48,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'No exercises in this workout',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 80), // Space for bottom
          ],
        ),
      ),
    );
  }
}

// Helper class for editable exercise data
class _EditableExerciseLog {
  final String exerciseId;
  final List<_EditableSet> sets;
  final String? notes;

  _EditableExerciseLog({
    required this.exerciseId,
    required this.sets,
    this.notes,
  });
}

class _EditableSet {
  double weight;
  int reps;
  bool isDropset;
  List<DropsetEntry>? drops;
  int? timeTaken;
  DateTime timestamp;

  _EditableSet({
    required this.weight,
    required this.reps,
    required this.timestamp,
    this.isDropset = false,
    this.drops,
    this.timeTaken,
  });
}

// Editable Exercise Card Widget
class _EditableExerciseCard extends StatelessWidget {
  final String exerciseName;
  final _EditableExerciseLog editableLog;
  final Function(
    int setIndex,
    double weight,
    int reps,
    bool isDropset,
    List<DropsetEntry>? drops,
  )
  onSetChanged;
  final VoidCallback onAddSet;
  final Function(int setIndex) onDeleteSet;
  final VoidCallback onDeleteExercise;

  const _EditableExerciseCard({
    super.key,
    required this.exerciseName,
    required this.editableLog,
    required this.onSetChanged,
    required this.onAddSet,
    required this.onDeleteSet,
    required this.onDeleteExercise,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    exerciseName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _confirmDeleteExercise(context),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppTheme.error,
                  tooltip: 'Remove exercise',
                ),
              ],
            ),

            const Divider(),

            // Sets
            ...editableLog.sets.asMap().entries.map((entry) {
              final setIndex = entry.key;
              final set = entry.value;

              return _EditableSetRow(
                setNumber: setIndex + 1,
                weight: set.weight,
                reps: set.reps,
                isDropset: set.isDropset,
                drops: set.drops,
                onWeightChanged: (weight) => onSetChanged(
                  setIndex,
                  weight,
                  set.reps,
                  set.isDropset,
                  set.drops,
                ),
                onRepsChanged: (reps) => onSetChanged(
                  setIndex,
                  set.weight,
                  reps,
                  set.isDropset,
                  set.drops,
                ),
                onDropsChanged: (drops) => onSetChanged(
                  setIndex,
                  set.weight,
                  set.reps,
                  set.isDropset,
                  drops,
                ),
                onIsDropsetChanged: (val) => onSetChanged(
                  setIndex,
                  set.weight,
                  set.reps,
                  val,
                  set.drops,
                ),
                onDelete: () => onDeleteSet(setIndex),
              );
            }),

            // Add Set Button
            Center(
              child: TextButton.icon(
                onPressed: onAddSet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Set'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExercise(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Remove Exercise?'),
        content: Text('Remove "$exerciseName" from this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDeleteExercise();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// Editable Set Row Widget
class _EditableSetRow extends StatefulWidget {
  final int setNumber;
  final double weight;
  final int reps;
  final bool isDropset;
  final List<DropsetEntry>? drops;
  final Function(double) onWeightChanged;
  final Function(int) onRepsChanged;
  final Function(List<DropsetEntry>) onDropsChanged;
  final Function(bool) onIsDropsetChanged;
  final VoidCallback onDelete;

  const _EditableSetRow({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.isDropset = false,
    this.drops,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onDropsChanged,
    required this.onIsDropsetChanged,
    required this.onDelete,
  });

  @override
  State<_EditableSetRow> createState() => _EditableSetRowState();
}

class _EditableSetRowState extends State<_EditableSetRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  final FocusNode _weightFocus = FocusNode();
  final FocusNode _repsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.weight.toString());
    _repsController = TextEditingController(text: widget.reps.toString());
  }

  @override
  void didUpdateWidget(covariant _EditableSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weight != oldWidget.weight && !_weightFocus.hasFocus) {
      if (double.tryParse(_weightController.text) != widget.weight) {
        _weightController.text = widget.weight.toString();
      }
    }
    if (widget.reps != oldWidget.reps && !_repsFocus.hasFocus) {
      if (int.tryParse(_repsController.text) != widget.reps) {
        _repsController.text = widget.reps.toString();
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          Row(
            children: [
              // Set number
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${widget.setNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Weight input
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _weightController,
                  focusNode: _weightFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    suffixText: 'kg',
                    suffixStyle: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    final weight = double.tryParse(value) ?? 0;
                    widget.onWeightChanged(weight);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // × symbol
              const Text('×', style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(width: AppSpacing.sm),

              // Reps input
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _repsController,
                  focusNode: _repsFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    suffixText: 'reps',
                    suffixStyle: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    final reps = int.tryParse(value) ?? 0;
                    widget.onRepsChanged(reps);
                  },
                ),
              ),

              const Spacer(),

              // Toggle Dropset button
              IconButton(
                onPressed: () => widget.onIsDropsetChanged(!widget.isDropset),
                icon: Icon(
                  widget.isDropset ? Icons.layers : Icons.layers_outlined,
                  size: 18,
                ),
                color: widget.isDropset
                    ? AppTheme.primaryColor
                    : AppTheme.textMuted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: widget.isDropset
                    ? 'Remove drops'
                    : 'Convert to dropset',
              ),

              // Delete button
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.close, size: 18),
                color: AppTheme.textMuted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Delete set',
              ),
            ],
          ),

          // Dropset Rows
          if (widget.isDropset) ...[
            if (widget.drops != null) ...[
              const SizedBox(height: 4),
              ...widget.drops!.asMap().entries.map((entry) {
                final index = entry.key;
                final drop = entry.value;
                return _EditableDropRow(
                  key: ValueKey('drop_${widget.setNumber}_$index'),
                  dropNumber: index + 1,
                  weight: drop.weight,
                  reps: drop.reps,
                  onWeightChanged: (val) {
                    final newDrops = List<DropsetEntry>.from(widget.drops!);
                    newDrops[index] = DropsetEntry(
                      weight: val,
                      reps: drop.reps,
                    );
                    widget.onDropsChanged(newDrops);
                  },
                  onRepsChanged: (val) {
                    final newDrops = List<DropsetEntry>.from(widget.drops!);
                    newDrops[index] = DropsetEntry(
                      weight: drop.weight,
                      reps: val,
                    );
                    widget.onDropsChanged(newDrops);
                  },
                  onDelete: () {
                    final newDrops = List<DropsetEntry>.from(widget.drops!)
                      ..removeAt(index);
                    widget.onDropsChanged(newDrops);
                  },
                );
              }),
            ],

            // Add drop button
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
              child: InkWell(
                onTap: () {
                  final newDrops = List<DropsetEntry>.from(widget.drops ?? []);
                  // Default to 80% of last weight or current weight
                  double initialWeight = widget.weight * 0.8;
                  if (newDrops.isNotEmpty) {
                    initialWeight = newDrops.last.weight * 0.8;
                  }
                  // Round to nearest 0.5
                  initialWeight = (initialWeight * 2).round() / 2;

                  newDrops.add(
                    DropsetEntry(weight: initialWeight, reps: widget.reps),
                  );
                  widget.onDropsChanged(newDrops);
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 14,
                      color: AppTheme.primaryColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add Drop',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor.withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditableDropRow extends StatefulWidget {
  final int dropNumber;
  final double weight;
  final int reps;
  final Function(double) onWeightChanged;
  final Function(int) onRepsChanged;
  final VoidCallback onDelete;

  const _EditableDropRow({
    super.key,
    required this.dropNumber,
    required this.weight,
    required this.reps,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onDelete,
  });

  @override
  State<_EditableDropRow> createState() => _EditableDropRowState();
}

class _EditableDropRowState extends State<_EditableDropRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  final FocusNode _weightFocus = FocusNode();
  final FocusNode _repsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.weight.toString());
    _repsController = TextEditingController(text: widget.reps.toString());
  }

  @override
  void didUpdateWidget(covariant _EditableDropRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weight != oldWidget.weight && !_weightFocus.hasFocus) {
      if (double.tryParse(_weightController.text) != widget.weight) {
        _weightController.text = widget.weight.toString();
      }
    }
    if (widget.reps != oldWidget.reps && !_repsFocus.hasFocus) {
      if (int.tryParse(_repsController.text) != widget.reps) {
        _repsController.text = widget.reps.toString();
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.subdirectory_arrow_right,
            size: 16,
            color: AppTheme.textMuted.withOpacity(0.5),
          ),
          const SizedBox(width: 8),

          Text(
            'Drop ${widget.dropNumber}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Weight input
          SizedBox(
            width: 70,
            height: 32,
            child: TextField(
              controller: _weightController,
              focusNode: _weightFocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 0,
                ),
                suffixText: 'kg',
                suffixStyle: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor.withOpacity(0.7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                final weight = double.tryParse(value) ?? 0;
                widget.onWeightChanged(weight);
              },
            ),
          ),

          const SizedBox(width: 8),
          const Text(
            '×',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(width: 8),

          // Reps input
          SizedBox(
            width: 60,
            height: 32,
            child: TextField(
              controller: _repsController,
              focusNode: _repsFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 0,
                ),
                suffixText: 'reps',
                suffixStyle: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor.withOpacity(0.7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                final reps = int.tryParse(value) ?? 0;
                widget.onRepsChanged(reps);
              },
            ),
          ),

          const Spacer(),

          IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.close, size: 16),
            color: AppTheme.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove drop',
          ),
        ],
      ),
    );
  }
}
