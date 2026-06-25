// Program Designer Screen
//
// Multi-step UI to create or edit a training program:
//   Step 1: Metadata (name, description, author, total weeks, phases)
//   Step 2: Week structure (mark deload weeks, add days per week)
//   Step 3: Exercise slots per day (sets, rep range, rest, tempo, weight%, notes)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../theme/app_theme.dart';

class ProgramDesignerScreen extends StatefulWidget {
  final TrainingProgram? existing;

  const ProgramDesignerScreen({super.key, this.existing});

  @override
  State<ProgramDesignerScreen> createState() => _ProgramDesignerScreenState();
}

class _ProgramDesignerScreenState extends State<ProgramDesignerScreen> {
  final _uuid = const Uuid();
  int _step = 0;

  // ── Step 1 State ─────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  int _totalWeeks = 12;
  final List<TrainingPhase> _phases = [];

  // ── Step 2 State ─────────────────────────────────────────────────────
  late List<ProgramWeek> _weeks;

  // ── Step 3 State ─────────────────────────────────────────────────────
  // (editing happens inline inside _weeks list)

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final p = widget.existing!;
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description ?? '';
      _authorCtrl.text = p.author ?? '';
      _totalWeeks = p.totalWeeks;
      _phases.addAll(p.phases);
      _weeks = p.weeks.map((w) => w).toList();
    } else {
      _weeks = [];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Program' : 'Edit Program'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: AppTheme.surfaceColor,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
      body: IndexedStack(
        index: _step,
        children: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (_step > 0)
              OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: const Text('Back'),
              ),
            const Spacer(),
            Text(
              'Step ${_step + 1} of 3',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _step < 2 ? _nextStep : _save,
              child: Text(_step < 2 ? 'Next' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Metadata ──────────────────────────────────────────────────

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const _SectionHeader('Program Details'),
        _field(_nameCtrl, 'Program Name *', hint: 'e.g. 12-Week Hypertrophy'),
        const SizedBox(height: AppSpacing.sm),
        _field(_descCtrl, 'Description', maxLines: 3),
        const SizedBox(height: AppSpacing.sm),
        _field(_authorCtrl, 'Author / Coach', hint: 'Optional'),
        const SizedBox(height: AppSpacing.lg),
        const _SectionHeader('Duration'),
        _NumberStepper(
          label: 'Total Weeks',
          value: _totalWeeks,
          min: 1,
          max: 52,
          onChanged: (v) {
            final error = _validatePhases(v);
            if (error != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(error),
                backgroundColor: AppTheme.error,
              ));
            } else {
              setState(() {
                _totalWeeks = v;
                _rebuildWeeks();
              });
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SectionHeader('Phases (optional)'),
        ..._phases.asMap().entries.map(
          (entry) => _buildPhaseChip(entry.key, entry.value),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _addPhase,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Phase'),
        ),
      ],
    );
  }

  Widget _buildPhaseChip(int idx, TrainingPhase phase) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        dense: true,
        title: Text(phase.name),
        subtitle: Text('Weeks ${phase.startWeek}–${phase.endWeek}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
          onPressed: () => setState(() => _phases.removeAt(idx)),
        ),
        onTap: () => _editPhase(idx, phase),
      ),
    );
  }

  void _addPhase() => _showPhaseDialog(null, null);
  void _editPhase(int idx, TrainingPhase phase) => _showPhaseDialog(idx, phase);

  void _showPhaseDialog(int? idx, TrainingPhase? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int start = existing?.startWeek ?? 1;
    int end = existing?.endWeek ?? _totalWeeks;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Add Phase' : 'Edit Phase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phase Name',
                  hintText: 'e.g. Foundation',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _NumberStepper(
                label: 'Start Week',
                value: start,
                min: 1,
                max: _totalWeeks,
                onChanged: (v) => setDlg(() => start = v),
              ),
              _NumberStepper(
                label: 'End Week',
                value: end,
                min: start,
                max: _totalWeeks,
                onChanged: (v) => setDlg(() => end = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final phase = TrainingPhase(
                  id: existing?.id ?? _uuid.v4(),
                  name: nameCtrl.text.isEmpty ? 'Phase' : nameCtrl.text,
                  startWeek: start,
                  endWeek: end,
                );

                final backupPhase = idx != null ? _phases[idx] : null;
                if (idx != null) {
                  _phases[idx] = phase;
                } else {
                  _phases.add(phase);
                }

                final error = _validatePhases(_totalWeeks);
                if (error != null) {
                  // Revert
                  if (idx != null) {
                    _phases[idx] = backupPhase!;
                  } else {
                    _phases.removeLast();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(error),
                    backgroundColor: AppTheme.error,
                  ));
                  return; // Prevent closing
                }

                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Week Structure ─────────────────────────────────────────────

  Widget _buildStep2() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _weeks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _SectionHeader('Weeks & Days');
        }
        final week = _weeks[index - 1];
        return _buildWeekEditor(index - 1, week);
      },
    );
  }

  Widget _buildWeekEditor(int idx, ProgramWeek week) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExpansionTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: week.isDeload
                ? Colors.amber.withValues(alpha: 0.2)
                : AppTheme.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            'W${week.weekNumber}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: week.isDeload ? Colors.amber : AppTheme.primaryColor,
            ),
          ),
        ),
        title: Text(
          week.isDeload ? 'Week ${week.weekNumber} — Deload' : 'Week ${week.weekNumber}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: week.isDeload ? Colors.amber : AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          '${week.days.length} day${week.days.length != 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                // Deload toggle
                SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deload Week'),
                  value: week.isDeload,
                  onChanged: (v) => setState(() {
                    _weeks[idx] = week.copyWith(isDeload: v);
                  }),
                ),
                if (week.isDeload) ...[
                  _NumberStepper(
                    label: 'Intensity factor (%)',
                    value: (week.deloadIntensityFactor * 100).round(),
                    min: 50,
                    max: 95,
                    onChanged: (v) => setState(() {
                      _weeks[idx] = week.copyWith(
                        deloadIntensityFactor: v / 100.0,
                      );
                    }),
                  ),
                  _NumberStepper(
                    label: 'Sets reduced by',
                    value: week.deloadSetReduction,
                    min: 0,
                    max: 3,
                    onChanged: (v) => setState(() {
                      _weeks[idx] = week.copyWith(deloadSetReduction: v);
                    }),
                  ),
                ],
                const Divider(),
                // Days in this week
                ...week.days.asMap().entries.map(
                  (entry) => _buildDayChip(idx, entry.key, entry.value),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addDay(idx),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Day'),
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
      leading: const Icon(Icons.drag_handle, color: AppTheme.textMuted),
      title: Text(day.name),
      subtitle: Text(
        '${day.exercises.length} exercise${day.exercises.length != 1 ? 's' : ''}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
        onPressed: () => setState(() {
          final days = List<ProgramDay>.from(_weeks[weekIdx].days)
            ..removeAt(dayIdx);
          _weeks[weekIdx] = _weeks[weekIdx].copyWith(days: days);
        }),
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
            title: const Text('Add Day'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Day Name',
                    hintText: 'e.g. Push, Pull, Legs',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int?>(
                  decoration: const InputDecoration(
                    labelText: 'Day of Week (optional)',
                  ),
                  initialValue: dow,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Unscheduled')),
                    ...List.generate(7, (i) => i + 1).map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1],
                          ),
                        )),
                  ],
                  onChanged: (v) => setDlg(() => dow = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newDay = ProgramDay(
                    id: _uuid.v4(),
                    name: nameCtrl.text.isEmpty ? 'Day' : nameCtrl.text,
                    dayOfWeek: dow,
                    exercises: [],
                  );
                  setState(() {
                    final days = List<ProgramDay>.from(_weeks[weekIdx].days)
                      ..add(newDay);
                    _weeks[weekIdx] = _weeks[weekIdx].copyWith(days: days);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Step 3: Exercises per Day ──────────────────────────────────────────

  Widget _buildStep3() {
    final allExercises = context.read<WorkoutProvider>().allExercises;

    final items = <Widget>[const _SectionHeader('Exercises per Day')];

    for (int wi = 0; wi < _weeks.length; wi++) {
      final week = _weeks[wi];
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.sm),
        child: Text(
          'Week ${week.weekNumber}${week.isDeload ? ' — Deload' : ''}',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ));
      for (int di = 0; di < week.days.length; di++) {
        items.add(_buildDayExerciseEditor(wi, di, week.days[di], allExercises));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: items,
    );
  }

  Widget _buildDayExerciseEditor(
    int weekIdx,
    int dayIdx,
    ProgramDay day,
    List<Exercise> allExercises,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExpansionTile(
        title: Text(
          day.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Week ${_weeks[weekIdx].weekNumber} · ${day.exercises.length} exercise${day.exercises.length != 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                ...day.exercises.asMap().entries.map(
                  (entry) => _buildSlotEditor(
                    weekIdx,
                    dayIdx,
                    entry.key,
                    entry.value,
                    allExercises,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _addExerciseSlot(
                    weekIdx,
                    dayIdx,
                    allExercises,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Exercise'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotEditor(
    int weekIdx,
    int dayIdx,
    int slotIdx,
    ProgramExerciseSlot slot,
    List<Exercise> allExercises,
  ) {
    final exercise = allExercises.where((e) => e.id == slot.exerciseId).firstOrNull;
    final name = exercise?.name ?? slot.exerciseId;

    return Card(
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        dense: true,
        title: Text(name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          '${slot.sets}×${slot.minReps}–${slot.maxReps} · ${slot.restSeconds}s'
          '${slot.tempo != null ? ' · ${slot.tempo}' : ''}'
          '${slot.weightPercentage != null ? ' · ${slot.weightPercentage!.toStringAsFixed(0)}%' : ''}',
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _editSlot(weekIdx, dayIdx, slotIdx, slot, allExercises),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
              onPressed: () => setState(() {
                final exercises = List<ProgramExerciseSlot>.from(
                  _weeks[weekIdx].days[dayIdx].exercises,
                )..removeAt(slotIdx);
                _updateDayExercises(weekIdx, dayIdx, exercises);
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _addExerciseSlot(int weekIdx, int dayIdx, List<Exercise> allExercises) {
    _showSlotDialog(weekIdx, dayIdx, null, null, allExercises);
  }

  void _editSlot(
    int weekIdx,
    int dayIdx,
    int slotIdx,
    ProgramExerciseSlot slot,
    List<Exercise> allExercises,
  ) {
    _showSlotDialog(weekIdx, dayIdx, slotIdx, slot, allExercises);
  }

  void _showSlotDialog(
    int weekIdx,
    int dayIdx,
    int? slotIdx,
    ProgramExerciseSlot? existing,
    List<Exercise> allExercises,
  ) {
    String? selectedExerciseId = existing?.exerciseId;
    int sets = existing?.sets ?? 3;
    int minReps = existing?.minReps ?? 8;
    int maxReps = existing?.maxReps ?? 12;
    int restSec = existing?.restSeconds ?? 90;
    final tempoCtrl = TextEditingController(text: existing?.tempo ?? '');
    final weightPctCtrl = TextEditingController(
      text: existing?.weightPercentage?.toStringAsFixed(0) ?? '',
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String exerciseSearch = '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final filtered = allExercises
              .where(
                (e) => e.name.toLowerCase().contains(exerciseSearch.toLowerCase()),
              )
              .take(20)
              .toList();

          return AlertDialog(
            title: Text(existing == null ? 'Add Exercise' : 'Edit Exercise'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search exercise',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                    ),
                    onChanged: (v) => setDlg(() => exerciseSearch = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 80,
                      maxHeight: 160,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        title: Text(filtered[i].name, style: const TextStyle(fontSize: 13)),
                        selected: selectedExerciseId == filtered[i].id,
                        selectedColor: AppTheme.primaryColor,
                        onTap: () => setDlg(() => selectedExerciseId = filtered[i].id),
                      ),
                    ),
                  ),
                  const Divider(),
                  _NumberStepper(
                    label: 'Sets',
                    value: sets,
                    min: 1,
                    max: 10,
                    onChanged: (v) => setDlg(() => sets = v),
                  ),
                  _NumberStepper(
                    label: 'Min Reps',
                    value: minReps,
                    min: 1,
                    max: maxReps,
                    onChanged: (v) => setDlg(() => minReps = v),
                  ),
                  _NumberStepper(
                    label: 'Max Reps',
                    value: maxReps,
                    min: minReps,
                    max: 50,
                    onChanged: (v) => setDlg(() => maxReps = v),
                  ),
                  _NumberStepper(
                    label: 'Rest (seconds)',
                    value: restSec,
                    min: 15,
                    max: 300,
                    step: 15,
                    onChanged: (v) => setDlg(() => restSec = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: tempoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tempo (e.g. 3-1-1)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: weightPctCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Weight % (e.g. 70)',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedExerciseId == null) return;
                  final slot = ProgramExerciseSlot(
                    exerciseId: selectedExerciseId!,
                    sets: sets,
                    minReps: minReps,
                    maxReps: maxReps,
                    restSeconds: restSec,
                    tempo: tempoCtrl.text.isEmpty ? null : tempoCtrl.text,
                    weightPercentage: double.tryParse(weightPctCtrl.text),
                    notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                    supersetGroupId: existing?.supersetGroupId,
                  );
                  setState(() {
                    final exercises = List<ProgramExerciseSlot>.from(
                      _weeks[weekIdx].days[dayIdx].exercises,
                    );
                    if (slotIdx != null) {
                      exercises[slotIdx] = slot;
                    } else {
                      exercises.add(slot);
                    }
                    _updateDayExercises(weekIdx, dayIdx, exercises);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateDayExercises(
    int weekIdx,
    int dayIdx,
    List<ProgramExerciseSlot> exercises,
  ) {
    final days = List<ProgramDay>.from(_weeks[weekIdx].days);
    days[dayIdx] = days[dayIdx].copyWith(exercises: exercises);
    _weeks[weekIdx] = _weeks[weekIdx].copyWith(days: days);
  }

  // ── Navigation ───────────────────────────────────────────────────────

  void _nextStep() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a program name to continue')),
        );
        return;
      }
      _rebuildWeeks();
    }
    setState(() => _step++);
  }

  void _rebuildWeeks() {
    // Keep existing weeks, only add/remove to match _totalWeeks
    if (_weeks.length < _totalWeeks) {
      final phaseId = _phases.isNotEmpty ? _phases.first.id : null;
      for (int i = _weeks.length + 1; i <= _totalWeeks; i++) {
        _weeks.add(
          ProgramWeek(weekNumber: i, phaseId: phaseId, days: []),
        );
      }
    } else if (_weeks.length > _totalWeeks) {
      _weeks = _weeks.sublist(0, _totalWeeks);
    }
    // Assign phase ids based on phase ranges
    for (int i = 0; i < _weeks.length; i++) {
      final weekNum = i + 1;
      String? pid;
      for (final phase in _phases) {
        if (weekNum >= phase.startWeek && weekNum <= phase.endWeek) {
          pid = phase.id;
          break;
        }
      }
      _weeks[i] = _weeks[i].copyWith(phaseId: pid);
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program name is required')),
      );
      return;
    }

    final phaseError = _validatePhases(_totalWeeks);
    if (phaseError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phaseError), backgroundColor: AppTheme.error),
      );
      return;
    }

    if (_weeks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one week before saving')),
      );
      return;
    }

    final hasEmptyDays = _weeks.any(
      (w) => w.days.any((d) => d.exercises.isEmpty),
    );
    if (hasEmptyDays) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Empty Days'),
          content: const Text(
            'Some days have no exercises. Save anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    if (!mounted) return;

    final provider = context.read<WorkoutProvider>();
    final program = TrainingProgram(
      id: widget.existing?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
      author: _authorCtrl.text.isEmpty ? null : _authorCtrl.text,
      totalWeeks: _totalWeeks,
      phases: _phases,
      weeks: _weeks,
      isImported: widget.existing?.isImported ?? false,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    await provider.programManager.saveProgram(program);
    if (mounted) Navigator.pop(context);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String? _validatePhases(int proposedTotalWeeks) {
    if (_phases.isEmpty) return null;

    // Detect truncation
    for (final phase in _phases) {
      if (phase.endWeek > proposedTotalWeeks) {
        return 'Cannot reduce weeks to $proposedTotalWeeks. Phase "${phase.name}" ends on week ${phase.endWeek}.';
      }
      if (phase.startWeek > phase.endWeek) {
        return 'Phase "${phase.name}" has an invalid range (starts after it ends).';
      }
    }

    // Detect overlapping
    final sortedPhases = List<TrainingPhase>.from(_phases)..sort((a, b) => a.startWeek.compareTo(b.startWeek));
    for (int i = 0; i < sortedPhases.length - 1; i++) {
      if (sortedPhases[i].endWeek >= sortedPhases[i + 1].startWeek) {
        return 'Phases "${sortedPhases[i].name}" and "${sortedPhases[i + 1].name}" overlap.';
      }
    }

    return null;
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

// ── Shared Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > min
                ? () => onChanged((value - step).clamp(min, max).toInt())
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
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: value < max
                ? () => onChanged((value + step).clamp(min, max).toInt())
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
