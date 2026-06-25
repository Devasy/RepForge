// program_week_editor.dart — Step 2 week structure editor + shared stepper widget

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';

// ── Shared primitive: number stepper ─────────────────────────────────────────
class ProgramNumberStepper extends StatelessWidget {
  const ProgramNumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSoft),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 18),
            color: AppColors.textSoft,
            onPressed: value > min
                ? () => onChanged((value - step).clamp(min, max))
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 18),
            color: AppColors.textSoft,
            onPressed: value < max
                ? () => onChanged((value + step).clamp(min, max))
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ── Shared primitive: section header ─────────────────────────────────────────
class ProgramSectionHeader extends StatelessWidget {
  const ProgramSectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Step 2: Week structure editor ─────────────────────────────────────────────
class ProgramWeekEditorStep extends StatefulWidget {
  const ProgramWeekEditorStep({
    super.key,
    required this.weeks,
    required this.onWeeksChanged,
  });

  final List<ProgramWeek> weeks;
  final void Function(List<ProgramWeek>) onWeeksChanged;

  @override
  State<ProgramWeekEditorStep> createState() => _ProgramWeekEditorStepState();
}

class _ProgramWeekEditorStepState extends State<ProgramWeekEditorStep> {
  final _uuid = const Uuid();
  late List<ProgramWeek> _weeks;

  @override
  void initState() {
    super.initState();
    _weeks = List.from(widget.weeks);
  }

  @override
  void didUpdateWidget(ProgramWeekEditorStep old) {
    super.didUpdateWidget(old);
    if (widget.weeks != old.weeks) {
      _weeks = List.from(widget.weeks);
    }
  }

  void _update(List<ProgramWeek> weeks) {
    setState(() => _weeks = weeks);
    widget.onWeeksChanged(weeks);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _weeks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const ProgramSectionHeader('Weeks & Days');
        return _buildWeekEditor(index - 1, _weeks[index - 1]);
      },
    );
  }

  Widget _buildWeekEditor(int idx, ProgramWeek week) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: week.isDeload
              ? Colors.amber.withValues(alpha: 0.35)
              : AppColors.glassBorder,
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: week.isDeload
                ? Colors.amber.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: Text(
            'W${week.weekNumber}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: week.isDeload ? Colors.amber : AppColors.primary,
            ),
          ),
        ),
        title: Text(
          week.isDeload
              ? 'Week ${week.weekNumber} — Deload'
              : 'Week ${week.weekNumber}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: week.isDeload ? Colors.amber : AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${week.days.length} day${week.days.length != 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Deload Week',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                  value: week.isDeload,
                  activeThumbColor: Colors.amber,
                  onChanged: (v) {
                    final updated = List<ProgramWeek>.from(_weeks);
                    updated[idx] = week.copyWith(isDeload: v);
                    _update(updated);
                  },
                ),
                if (week.isDeload) ...[
                  ProgramNumberStepper(
                    label: 'Intensity factor (%)',
                    value: (week.deloadIntensityFactor * 100).round(),
                    min: 50,
                    max: 95,
                    onChanged: (v) {
                      final updated = List<ProgramWeek>.from(_weeks);
                      updated[idx] = week.copyWith(
                        deloadIntensityFactor: v / 100.0,
                      );
                      _update(updated);
                    },
                  ),
                  ProgramNumberStepper(
                    label: 'Sets reduced by',
                    value: week.deloadSetReduction,
                    min: 0,
                    max: 3,
                    onChanged: (v) {
                      final updated = List<ProgramWeek>.from(_weeks);
                      updated[idx] = week.copyWith(deloadSetReduction: v);
                      _update(updated);
                    },
                  ),
                ],
                Divider(color: AppColors.glassBorder),
                ...week.days.asMap().entries.map(
                  (e) => _buildDayChip(idx, e.key, e.value),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addDay(idx),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Day'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(int weekIdx, int dayIdx, ProgramDay day) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.drag_handle_rounded, color: AppColors.textMuted),
      title: Text(
        day.name,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
      subtitle: Text(
        '${day.exercises.length} exercise${day.exercises.length != 1 ? 's' : ''}',
        style: const TextStyle(fontSize: 11, color: AppColors.textSoft),
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.error,
          size: 18,
        ),
        onPressed: () {
          final days = List<ProgramDay>.from(_weeks[weekIdx].days)
            ..removeAt(dayIdx);
          final updated = List<ProgramWeek>.from(_weeks);
          updated[weekIdx] = updated[weekIdx].copyWith(days: days);
          _update(updated);
        },
      ),
    );
  }

  void _addDay(int weekIdx) {
    showDialog(
      context: context,
      builder: (_) {
        final nameCtrl = TextEditingController();
        int? dow;
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor: AppColors.cardHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            title: const Text(
              'Add Day',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _styledField(nameCtrl, 'Day Name', hint: 'e.g. Push, Pull, Legs'),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int?>(
                  decoration: const InputDecoration(
                    labelText: 'Day of Week (optional)',
                    labelStyle: TextStyle(color: AppColors.textSoft),
                  ),
                  dropdownColor: AppColors.cardHigh,
                  style: const TextStyle(color: AppColors.textPrimary),
                  initialValue: dow,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Unscheduled'),
                    ),
                    ...List.generate(7, (i) => i + 1).map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setDlg(() => dow = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSoft),
                ),
              ),
              TextButton(
                onPressed: () {
                  final newDay = ProgramDay(
                    id: _uuid.v4(),
                    name: nameCtrl.text.isEmpty ? 'Day' : nameCtrl.text,
                    dayOfWeek: dow,
                    exercises: [],
                  );
                  final days = List<ProgramDay>.from(_weeks[weekIdx].days)
                    ..add(newDay);
                  final updated = List<ProgramWeek>.from(_weeks);
                  updated[weekIdx] = updated[weekIdx].copyWith(days: days);
                  _update(updated);
                  Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _styledField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSoft),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
