// editable_exercise_card.dart — Editable exercise card + set/drop rows for edit screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';

// ── Shared mutable data classes ───────────────────────────────────────────────
class EditableExerciseLog {
  final String exerciseId;
  final List<EditableSet> sets;
  final String? notes;

  EditableExerciseLog({
    required this.exerciseId,
    required this.sets,
    this.notes,
  });
}

class EditableSet {
  double weight;
  int reps;
  bool isDropset;
  List<DropsetEntry>? drops;
  int? timeTaken;
  DateTime timestamp;

  EditableSet({
    required this.weight,
    required this.reps,
    required this.timestamp,
    this.isDropset = false,
    this.drops,
    this.timeTaken,
  });
}

// ── Editable exercise card ────────────────────────────────────────────────────
class EditableExerciseCard extends StatelessWidget {
  const EditableExerciseCard({
    super.key,
    required this.exerciseName,
    required this.editableLog,
    required this.onSetChanged,
    required this.onAddSet,
    required this.onDeleteSet,
    required this.onDeleteExercise,
  });

  final String exerciseName;
  final EditableExerciseLog editableLog;
  final void Function(
    int setIndex,
    double weight,
    int reps,
    bool isDropset,
    List<DropsetEntry>? drops,
  ) onSetChanged;
  final VoidCallback onAddSet;
  final void Function(int setIndex) onDeleteSet;
  final VoidCallback onDeleteExercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    exerciseName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Set rows
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: editableLog.sets.asMap().entries.map((entry) {
                final i = entry.key;
                final set = entry.value;
                return EditableSetRow(
                  key: ValueKey('set_${exerciseName}_$i'),
                  setNumber: i + 1,
                  weight: set.weight,
                  reps: set.reps,
                  isDropset: set.isDropset,
                  drops: set.drops,
                  onWeightChanged: (w) =>
                      onSetChanged(i, w, set.reps, set.isDropset, set.drops),
                  onRepsChanged: (r) =>
                      onSetChanged(i, set.weight, r, set.isDropset, set.drops),
                  onIsDropsetChanged: (d) =>
                      onSetChanged(i, set.weight, set.reps, d, set.drops),
                  onDropsChanged: (drops) =>
                      onSetChanged(i, set.weight, set.reps, set.isDropset, drops),
                  onDelete: () => onDeleteSet(i),
                );
              }).toList(),
            ),
          ),

          // Add set button
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: GestureDetector(
              onTap: onAddSet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Add Set',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Remove Exercise?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "$exerciseName" from this workout?',
          style: const TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSoft),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDeleteExercise();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ── Editable set row ──────────────────────────────────────────────────────────
class EditableSetRow extends StatefulWidget {
  const EditableSetRow({
    super.key,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onIsDropsetChanged,
    required this.onDropsChanged,
    required this.onDelete,
    this.isDropset = false,
    this.drops,
  });

  final int setNumber;
  final double weight;
  final int reps;
  final bool isDropset;
  final List<DropsetEntry>? drops;
  final void Function(double) onWeightChanged;
  final void Function(int) onRepsChanged;
  final void Function(bool) onIsDropsetChanged;
  final void Function(List<DropsetEntry>) onDropsChanged;
  final VoidCallback onDelete;

  @override
  State<EditableSetRow> createState() => _EditableSetRowState();
}

class _EditableSetRowState extends State<EditableSetRow> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(text: widget.weight.toString());
    _repsCtrl = TextEditingController(text: widget.reps.toString());
  }

  @override
  void didUpdateWidget(covariant EditableSetRow old) {
    super.didUpdateWidget(old);
    if (widget.weight != old.weight && !_weightFocus.hasFocus) {
      if (double.tryParse(_weightCtrl.text) != widget.weight) {
        _weightCtrl.text = widget.weight.toString();
      }
    }
    if (widget.reps != old.reps && !_repsFocus.hasFocus) {
      if (int.tryParse(_repsCtrl.text) != widget.reps) {
        _repsCtrl.text = widget.reps.toString();
      }
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
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
              // Set number badge
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.setNumber}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Weight
              _NumField(
                controller: _weightCtrl,
                focusNode: _weightFocus,
                suffix: 'kg',
                decimal: true,
                width: 78,
                onChanged: (v) =>
                    widget.onWeightChanged(double.tryParse(v) ?? 0),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('×', style: TextStyle(color: AppColors.textMuted)),
              ),

              // Reps
              _NumField(
                controller: _repsCtrl,
                focusNode: _repsFocus,
                suffix: 'reps',
                width: 72,
                onChanged: (v) =>
                    widget.onRepsChanged(int.tryParse(v) ?? 0),
              ),

              const Spacer(),

              // Dropset toggle
              GestureDetector(
                onTap: () =>
                    widget.onIsDropsetChanged(!widget.isDropset),
                child: Icon(
                  widget.isDropset
                      ? Icons.layers_rounded
                      : Icons.layers_outlined,
                  size: 18,
                  color: widget.isDropset
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Delete
              GestureDetector(
                onTap: widget.onDelete,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),

          // Drop rows
          if (widget.isDropset && widget.drops != null) ...[
            ...widget.drops!.asMap().entries.map((e) {
              final i = e.key;
              final drop = e.value;
              return EditableDropRow(
                key: ValueKey('drop_${widget.setNumber}_$i'),
                dropNumber: i + 1,
                weight: drop.weight,
                reps: drop.reps,
                onWeightChanged: (w) {
                  final updated = List<DropsetEntry>.from(widget.drops!);
                  updated[i] = DropsetEntry(weight: w, reps: drop.reps);
                  widget.onDropsChanged(updated);
                },
                onRepsChanged: (r) {
                  final updated = List<DropsetEntry>.from(widget.drops!);
                  updated[i] = DropsetEntry(weight: drop.weight, reps: r);
                  widget.onDropsChanged(updated);
                },
                onDelete: () {
                  final updated = List<DropsetEntry>.from(widget.drops!)
                    ..removeAt(i);
                  widget.onDropsChanged(updated);
                },
              );
            }),
            // Add drop
            GestureDetector(
              onTap: () {
                final existing = widget.drops ?? [];
                final initW = existing.isEmpty
                    ? widget.weight * 0.8
                    : existing.last.weight * 0.8;
                final rounded = (initW * 2).round() / 2;
                widget.onDropsChanged([
                  ...existing,
                  DropsetEntry(weight: rounded, reps: widget.reps),
                ]);
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 34, top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 13,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add Drop',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

// ── Drop row ──────────────────────────────────────────────────────────────────
class EditableDropRow extends StatefulWidget {
  const EditableDropRow({
    super.key,
    required this.dropNumber,
    required this.weight,
    required this.reps,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onDelete,
  });

  final int dropNumber;
  final double weight;
  final int reps;
  final void Function(double) onWeightChanged;
  final void Function(int) onRepsChanged;
  final VoidCallback onDelete;

  @override
  State<EditableDropRow> createState() => _EditableDropRowState();
}

class _EditableDropRowState extends State<EditableDropRow> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(text: widget.weight.toString());
    _repsCtrl = TextEditingController(text: widget.reps.toString());
  }

  @override
  void didUpdateWidget(covariant EditableDropRow old) {
    super.didUpdateWidget(old);
    if (widget.weight != old.weight && !_weightFocus.hasFocus) {
      if (double.tryParse(_weightCtrl.text) != widget.weight) {
        _weightCtrl.text = widget.weight.toString();
      }
    }
    if (widget.reps != old.reps && !_repsFocus.hasFocus) {
      if (int.tryParse(_repsCtrl.text) != widget.reps) {
        _repsCtrl.text = widget.reps.toString();
      }
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 34, top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 14,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Text(
            'Drop ${widget.dropNumber}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(width: AppSpacing.sm),
          _NumField(
            controller: _weightCtrl,
            focusNode: _weightFocus,
            suffix: 'kg',
            decimal: true,
            width: 68,
            height: 30,
            onChanged: (v) =>
                widget.onWeightChanged(double.tryParse(v) ?? 0),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '×',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          _NumField(
            controller: _repsCtrl,
            focusNode: _repsFocus,
            suffix: 'reps',
            width: 60,
            height: 30,
            onChanged: (v) => widget.onRepsChanged(int.tryParse(v) ?? 0),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onDelete,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared number text field ──────────────────────────────────────────────────
class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.focusNode,
    required this.suffix,
    required this.onChanged,
    this.decimal = false,
    this.width = 80,
    this.height = 36,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String suffix;
  final bool decimal;
  final double width;
  final double height;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        inputFormatters: decimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))]
            : [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          suffixText: suffix,
          suffixStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
