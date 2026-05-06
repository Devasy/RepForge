// routine_creator.dart — CreateRoutineScreen, RoutineDetailScreen, start helper

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../data/exercise_database.dart';
import '../workout_flow_screen.dart';
import 'rf_widgets.dart';
import 'rf_cards.dart';
import 'workout_conflict_dialog.dart';

// ── Start routine workout (shared helper) ─────────────────────────────────────
Future<void> startRoutineWorkoutFlow(
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

// ── Create / Edit Routine Screen ──────────────────────────────────────────────
class CreateRoutineScreen extends StatefulWidget {
  const CreateRoutineScreen({super.key, this.routine});
  final Routine? routine;

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _nameController = TextEditingController();
  final List<String> _selectedIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.routine != null) {
      _nameController.text = widget.routine!.name;
      _selectedIds.addAll(widget.routine!.exerciseIds);
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
    final isEditing = widget.routine != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          isEditing ? 'Edit Routine' : 'New Routine',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textSoft),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Routine name (e.g. Push Day)',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Text(
                  'Exercises (${_selectedIds.length})',
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _selectedIds.clear()),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              itemCount: _selectedIds.length + 1,
              onReorder: (old, next) {
                if (old >= _selectedIds.length ||
                    next >= _selectedIds.length + 1) {
                  return;
                }
                setState(() {
                  if (next > old) next--;
                  final item = _selectedIds.removeAt(old);
                  _selectedIds.insert(next, item);
                });
              },
              itemBuilder: (_, i) {
                if (i == _selectedIds.length) {
                  return Padding(
                    key: const ValueKey('add_btn'),
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: OutlineGlowButton(
                      label: 'Add Exercises',
                      onPressed: () =>
                          _showPicker(context, provider.allExercises),
                      fullWidth: true,
                    ),
                  );
                }
                final id = _selectedIds[i];
                final ex = provider.getExercise(id);
                return Container(
                  key: ValueKey(id),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const Icon(
                          Icons.drag_handle_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex?.name ?? 'Unknown',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (ex != null)
                              Text(
                                ex.category,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedIds.removeAt(i)),
                        child: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, List<Exercise> all) {
    String query = '';
    final List<String> temp = [];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final filtered = all.where((ex) {
            if (_selectedIds.contains(ex.id)) return false;
            return query.isEmpty ||
                ex.name.toLowerCase().contains(query.toLowerCase());
          }).toList();

          final grouped = <String, List<Exercise>>{};
          for (final ex in filtered) {
            grouped.putIfAbsent(ex.primaryMuscle, () => []).add(ex);
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, sc) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.glassBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Add Exercises',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (temp.isNotEmpty)
                            GlowButton(
                              label: 'Add ${temp.length}',
                              icon: Icons.check_rounded,
                              onPressed: () {
                                setState(() => _selectedIds.addAll(temp));
                                Navigator.of(ctx).pop();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: TextField(
                          onChanged: (v) => setModal(() => query = v),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search exercises…',
                            hintStyle: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.textMuted,
                              size: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: sc,
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
                              child: RFSectionHeader(muscleName),
                            ),
                            ...entry.value.map((ex) {
                              final sel = temp.contains(ex.id);
                              return ExerciseCard(
                                exercise: ex,
                                selected: sel,
                                onTap: () => setModal(() {
                                  if (sel) {
                                    temp.remove(ex.id);
                                  } else {
                                    temp.add(ex.id);
                                  }
                                }),
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine name')),
      );
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    final provider = context.read<WorkoutProvider>();
    if (widget.routine != null) {
      final updated = Routine(
        id: widget.routine!.id,
        name: _nameController.text.trim(),
        exerciseIds: _selectedIds,
        createdAt: widget.routine!.createdAt,
      );
      await provider.updateRoutine(updated);
    } else {
      await provider.createRoutine(
        _nameController.text.trim(),
        _selectedIds,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}

// ── Routine Detail Screen ─────────────────────────────────────────────────────
class RoutineDetailScreen extends StatelessWidget {
  const RoutineDetailScreen({super.key, required this.routine});
  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          routine.name,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textSoft),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textSoft),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CreateRoutineScreen(routine: routine),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          100,
        ),
        itemCount: routine.exerciseIds.length,
        itemBuilder: (_, i) {
          final ex = provider.getExercise(routine.exerciseIds[i]);
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex?.name ?? 'Unknown',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (ex != null)
                        Text(
                          '${ex.category} · ${MuscleGroups.names[ex.primaryMuscle] ?? ex.primaryMuscle}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => startRoutineWorkoutFlow(context, routine),
        backgroundColor: AppColors.primary,
        elevation: 0,
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
        label: const Text(
          'Start Workout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
