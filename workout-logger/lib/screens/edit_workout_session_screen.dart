// edit_workout_session_screen.dart — Edit a recorded workout session

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';
import 'widgets/editable_exercise_card.dart';

class EditWorkoutSessionScreen extends StatefulWidget {
  const EditWorkoutSessionScreen({super.key, required this.session});
  final WorkoutSession session;

  @override
  State<EditWorkoutSessionScreen> createState() =>
      _EditWorkoutSessionScreenState();
}

class _EditWorkoutSessionScreenState extends State<EditWorkoutSessionScreen> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TextEditingController _notesCtrl;
  late TextEditingController _durationCtrl;
  late List<EditableExerciseLog> _exercises;
  bool _isSubmitting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.session.date;
    _selectedTime = TimeOfDay.fromDateTime(widget.session.date);
    _notesCtrl = TextEditingController(text: widget.session.notes ?? '');
    _durationCtrl = TextEditingController(
      text: widget.session.duration.toString(),
    );
    _exercises = widget.session.exercises.map((log) {
      return EditableExerciseLog(
        exerciseId: log.exerciseId,
        sets: log.sets
            .map(
              (s) => EditableSet(
                weight: s.weight,
                reps: s.reps,
                isDropset: s.isDropset,
                drops: s.drops?.toList(),
                timeTaken: s.timeTaken,
                timestamp: s.timestamp,
              ),
            )
            .toList(),
        notes: log.notes,
      );
    }).toList();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.cardHigh,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _selectedTime.hour,
            _selectedTime.minute,
          ));
      _markChanged();
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.cardHigh,
          ),
        ),
        child: child!,
      ),
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
      final last = _exercises[exerciseIndex].sets.isNotEmpty
          ? _exercises[exerciseIndex].sets.last
          : null;
      _exercises[exerciseIndex].sets.add(EditableSet(
        weight: last?.weight ?? 0,
        reps: last?.reps ?? 0,
        timestamp: DateTime.now(),
      ));
    });
    _markChanged();
  }

  void _deleteSet(int exIdx, int setIdx) {
    setState(() => _exercises[exIdx].sets.removeAt(setIdx));
    _markChanged();
  }

  void _deleteExercise(int exIdx) {
    setState(() => _exercises.removeAt(exIdx));
    _markChanged();
  }

  Future<void> _save() async {
    final duration = int.tryParse(_durationCtrl.text);
    if (duration == null || duration < 0) {
      _snack('Please enter a valid duration', isError: true);
      return;
    }
    final withSets = _exercises.where((e) => e.sets.isNotEmpty).toList();
    if (withSets.isEmpty) {
      _snack('Workout must have at least one exercise with sets', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final updatedExercises = withSets.map((e) {
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

      final updated = widget.session.copyWith(
        date: _selectedDate,
        duration: duration,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        exercises: updatedExercises,
      );

      await context.read<WorkoutProvider>().updateWorkoutSession(updated);

      if (mounted) {
        _snack('Workout updated');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Save failed: $e');
      if (mounted) _snack('Failed to save. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Discard Changes?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'You have unsaved changes. Discard them?',
          style: TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSoft),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: isError ? AppColors.error : AppColors.cardHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Edit Workout',
            style: TextStyle(color: AppColors.textPrimary),
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
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Date & Time
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(icon: Icons.calendar_today_rounded,
                      color: AppColors.primary, label: 'Date & Time'),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _TapField(
                          label: 'Date',
                          value: DateFormat('EEE, MMM d, yyyy')
                              .format(_selectedDate),
                          onTap: _selectDate,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _TapField(
                        label: 'Time',
                        value: DateFormat('h:mm a').format(_selectedDate),
                        onTap: _selectTime,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Duration & Notes
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(icon: Icons.timer_outlined,
                      color: AppColors.secondary, label: 'Duration (minutes)'),
                  const SizedBox(height: AppSpacing.sm),
                  _StyledField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    hint: 'Minutes',
                    onChanged: (_) => _markChanged(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _sectionLabel(icon: Icons.notes_rounded,
                      color: AppColors.warning, label: 'Notes'),
                  const SizedBox(height: AppSpacing.sm),
                  _StyledField(
                    controller: _notesCtrl,
                    hint: 'Optional workout notes…',
                    maxLines: 3,
                    onChanged: (_) => _markChanged(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                const RFSectionHeader('Exercises'),
                const Spacer(),
                Text(
                  '${_exercises.length} exercises',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            ..._exercises.asMap().entries.map((entry) {
              final i = entry.key;
              final log = entry.value;
              final ex = provider.getExercise(log.exerciseId);
              return EditableExerciseCard(
                key: ValueKey('exercise_$i'),
                exerciseName: ex?.name ?? 'Unknown Exercise',
                editableLog: log,
                onSetChanged: ({required int setIndex, required double weight, required int reps, required bool isDropset, List<DropsetEntry>? drops}) {
                  setState(() {
                    log.sets[setIndex].weight = weight;
                    log.sets[setIndex].reps = reps;
                    log.sets[setIndex].isDropset = isDropset;
                    if (drops != null) log.sets[setIndex].drops = drops;
                  });
                  _markChanged();
                },
                onAddSet: () => _addSet(i),
                onDeleteSet: (si) => _deleteSet(i, si),
                onDeleteExercise: () => _deleteExercise(i),
              );
            }),

            if (_exercises.isEmpty)
              RFEmptyState(
                icon: Icons.fitness_center_rounded,
                title: 'No exercises',
                subtitle: 'All exercises have been removed',
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel({required IconData icon, required Color color, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSoft,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: child,
    );
  }
}

// ── Tappable date/time display field ──────────────────────────────────────────
class _TapField extends StatelessWidget {
  const _TapField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Styled text field ─────────────────────────────────────────────────────────
class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
        ),
      ),
    );
  }
}
