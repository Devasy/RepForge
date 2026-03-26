// Workout Flow Screen - Samsung Health-style minimal workout interface

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/workout_provider.dart';
import '../theme/app_theme.dart';
import 'exercise_library_screen.dart';

class WorkoutFlowScreen extends StatefulWidget {
  final Routine? routine;
  final bool isQuickStart;
  final ProgramDay? programDay;
  final ProgramWeek? programWeek;

  const WorkoutFlowScreen({
    super.key,
    this.routine,
    this.isQuickStart = false,
    this.programDay,
    this.programWeek,
  });

  @override
  State<WorkoutFlowScreen> createState() => _WorkoutFlowScreenState();
}

class _WorkoutFlowScreenState extends State<WorkoutFlowScreen> {
  // Rest timer state
  bool _isResting = false;
  int _restSeconds = 90; // Default rest time
  Timer? _restTimer;
  int _remainingSeconds = 0;

  // Superset cycling: index to return to after rest (null = no return)
  int? _supersetReturnIndex;

  // Input controllers
  double _currentWeight = 20;
  int _currentReps = 10;
  bool _isDropset = false;
  final List<DropsetEntry> _drops = [];

  // TextEditingControllers for dropset fields (following Flutter best practices)
  final TextEditingController _mainWeightController = TextEditingController();
  final TextEditingController _mainRepsController = TextEditingController();
  final List<TextEditingController> _dropWeightControllers = [];
  final List<TextEditingController> _dropRepsControllers = [];

  @override
  void initState() {
    super.initState();
    // Defer initialization until after the first frame to avoid
    // calling notifyListeners() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWorkout();
    });
  }

  ProgramExerciseSlot? _slotForIndex(int idx) {
    if (widget.programDay == null) return null;
    final slots = widget.programDay!.exercises;
    return idx < slots.length ? slots[idx] : null;
  }

  /// Finds the index of the first exercise in the same superset group, scanning
  /// backward from [fromIdx].
  int _supersetGroupStart(int fromIdx, String groupId) {
    int start = fromIdx;
    while (start > 0 && _slotForIndex(start - 1)?.supersetGroupId == groupId) {
      start--;
    }
    return start;
  }

  /// Returns true if any exercise in [startIdx..endIdx] still has fewer sets
  /// logged than its target (deload-adjusted).
  bool _supersetNeedsMoreSets({
    required int startIdx,
    required int endIdx,
    required WorkoutProvider provider,
  }) {
    for (int i = startIdx; i <= endIdx; i++) {
      final slot = _slotForIndex(i);
      if (slot == null) continue;
      if (i >= provider.currentExerciseLogs.length) continue;
      final targetSets = (widget.programWeek?.isDeload == true)
          ? (slot.sets - (widget.programWeek?.deloadSetReduction ?? 0)).clamp(
              1,
              99,
            )
          : slot.sets;
      final logged = provider.currentExerciseLogs[i].sets.length;
      if (logged < targetSets) return true;
    }
    return false;
  }

  /// Returns true if the single slot at [index] still needs more sets.
  bool _slotNeedsMoreSets({
    required int index,
    required WorkoutProvider provider,
  }) {
    final slot = _slotForIndex(index);
    if (slot == null) return false;
    if (index >= provider.currentExerciseLogs.length) return false;
    final targetSets = (widget.programWeek?.isDeload == true)
        ? (slot.sets - (widget.programWeek?.deloadSetReduction ?? 0)).clamp(1, 99)
        : slot.sets;
    final logged = provider.currentExerciseLogs[index].sets.length;
    return logged < targetSets;
  }

  void _initializeWorkout() {
    final provider = context.read<WorkoutProvider>();

    if (widget.programDay != null) {
      final exerciseIds =
          widget.programDay!.exercises.map((s) => s.exerciseId).toList();
      provider.startWorkout(exerciseIds: exerciseIds);
      // Set initial rest time from first slot
      final firstSlot = _slotForIndex(0);
      if (firstSlot != null) _restSeconds = firstSlot.restSeconds;
      _loadLastSessionData();
    } else if (widget.routine != null) {
      provider.startWorkout(routine: widget.routine);
      _loadLastSessionData();
    } else if (widget.isQuickStart) {
      // Will add exercises as we go
      provider.startWorkout(exerciseIds: []);
    }
  }

  void _loadLastSessionData() {
    final provider = context.read<WorkoutProvider>();
    final currentExercise = provider.currentExercise;
    if (currentExercise == null) return;

    final lastSession = provider.getLastSessionForExercise(currentExercise.id);
    if (lastSession != null && lastSession.sets.isNotEmpty) {
      final lastSet = lastSession.sets.last;
      setState(() {
        _currentWeight = lastSet.weight;
        _currentReps = lastSet.reps;
        // Sync controllers with state (single source of truth)
        _mainWeightController.text = _currentWeight.toString();
        _mainRepsController.text = _currentReps.toString();
      });
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    // Dispose TextEditingControllers to prevent memory leaks (Flutter best practice)
    _mainWeightController.dispose();
    _mainRepsController.dispose();
    for (var controller in _dropWeightControllers) {
      controller.dispose();
    }
    for (var controller in _dropRepsControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    if (!provider.hasActiveWorkout) {
      return const Scaffold(body: Center(child: Text('No active workout')));
    }

    // If no exercises yet (quick start), show exercise selector
    if (provider.currentExerciseLogs.isEmpty) {
      return _buildExerciseSelector();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _isResting ? _buildRestTimerView() : _buildWorkoutView(),
      ),
    );
  }

  Widget _buildExerciseSelector() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Exercises'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _showCancelDialog,
        ),
      ),
      body: ExerciseSelectorScreen(
        selectionMode: true,
        onExercisesSelected: _startWithSelectedExercises,
      ),
    );
  }

  void _startWithSelectedExercises(List<String> exerciseIds) {
    if (exerciseIds.isEmpty) return;

    final provider = context.read<WorkoutProvider>();
    // Restart workout with selected exercises
    provider.cancelWorkout();
    provider.startWorkout(exerciseIds: exerciseIds);
  }

  Widget _buildWorkoutView() {
    final provider = context.watch<WorkoutProvider>();
    final currentExercise = provider.currentExercise;
    final currentLog = provider.currentExerciseLog;
    final recommendations = currentExercise != null
        ? provider.getRecommendations(currentExercise.id)
        : <SetRecommendation>[];

    return Column(
      children: [
        // Header
        _buildHeader(provider, currentExercise),

        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Program metadata banner (shown only in program-mode)
                _buildProgramMetaBanner(provider),

                // Recommendation card
                if (recommendations.isNotEmpty && currentLog != null)
                  _buildRecommendationCard(
                    recommendations,
                    currentLog.sets.length,
                  ),

                const SizedBox(height: AppSpacing.lg),

                // Weight and reps input
                if (!_isDropset) _buildInputSection(provider),

                if (!_isDropset) const SizedBox(height: AppSpacing.md),

                // Dropset toggle
                _buildDropsetSection(),

                const SizedBox(height: AppSpacing.lg),

                // Set done button
                _buildSetDoneButton(),

                const SizedBox(height: AppSpacing.lg),

                // Previous sets
                if (currentLog != null && currentLog.sets.isNotEmpty)
                  _buildPreviousSets(currentLog.sets),

                const SizedBox(height: AppSpacing.lg),

                // Last session info
                if (currentExercise != null)
                  _buildLastSessionInfo(currentExercise.id),
              ],
            ),
          ),
        ),

        // Bottom actions
        _buildBottomActions(provider),
      ],
    );
  }

  Widget _buildHeader(WorkoutProvider provider, Exercise? exercise) {
    final totalExercises = provider.currentExerciseLogs.length;
    final currentIndex = provider.currentExerciseIndex + 1;
    final currentLog = provider.currentExerciseLog;
    final setNumber = (currentLog?.sets.length ?? 0) + 1;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _showCancelDialog,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      exercise?.name ?? 'Select Exercise',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Exercise $currentIndex of $totalExercises • Set $setNumber',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _showOptionsMenu,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Progress bar
          LinearProgressIndicator(
            value: currentIndex / totalExercises,
            backgroundColor: AppTheme.cardColor,
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    List<SetRecommendation> recommendations,
    int currentSetIndex,
  ) {
    if (currentSetIndex >= recommendations.length) return const SizedBox();

    final rec = recommendations[currentSetIndex];
    final confidenceColor = rec.confidence == 'high'
        ? AppTheme.success
        : (rec.confidence == 'medium' ? AppTheme.warning : AppTheme.textMuted);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.2),
            AppTheme.secondaryColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suggested',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                Text(
                  '${rec.weight}kg × ${rec.reps} reps',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentWeight = rec.weight;
                _currentReps = rec.reps;
              });
              HapticFeedback.lightImpact();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(WorkoutProvider provider) {
    final exerciseId = provider.currentExercise?.id ?? '';
    final isAssistedBodyweight =
        exerciseId == 'pull_ups' || exerciseId == 'chin_ups';
    final weightLabel =
        isAssistedBodyweight ? 'Assist kg (0=BW)' : 'Weight (kg)';

    return Row(
      children: [
        // Weight input
        Expanded(
          child: _buildNumberInput(
            label: weightLabel,
            value: _currentWeight,
            onChanged: (val) => setState(() => _currentWeight = val),
            step: _currentWeight < 40 ? 2.5 : 5,
            decimals: 1,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // Reps input
        Expanded(
          child: _buildNumberInput(
            label: 'Reps',
            value: _currentReps.toDouble(),
            onChanged: (val) => setState(() => _currentReps = val.toInt()),
            step: 1,
            decimals: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput({
    required String label,
    required double value,
    required Function(double) onChanged,
    required double step,
    required int decimals,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCircleButton(
                icon: Icons.remove,
                onPressed: () {
                  onChanged((value - step).clamp(0, 999));
                  HapticFeedback.selectionClick();
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showNumberPicker(value, decimals, onChanged),
                  child: Text(
                    decimals == 0
                        ? value.toInt().toString()
                        : value.toStringAsFixed(decimals),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              _buildCircleButton(
                icon: Icons.add,
                onPressed: () {
                  onChanged((value + step).clamp(0, 999));
                  HapticFeedback.selectionClick();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
      ),
    );
  }

  Widget _buildDropsetSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.trending_down, color: AppTheme.warning),
              const SizedBox(width: 8),
              const Text(
                'Dropset',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Switch(
                value: _isDropset,
                onChanged: (val) {
                  setState(() {
                    _isDropset = val;
                    if (!val) {
                      // Dispose all drop controllers when turning off dropset mode
                      for (var controller in _dropWeightControllers) {
                        controller.dispose();
                      }
                      for (var controller in _dropRepsControllers) {
                        controller.dispose();
                      }
                      _dropWeightControllers.clear();
                      _dropRepsControllers.clear();
                      _drops.clear();
                    } else {
                      // Sync main controllers when enabling dropset to match current state values
                      _mainWeightController.text = _currentWeight.toString();
                      _mainRepsController.text = _currentReps.toString();
                    }
                  });
                },
                activeThumbColor: AppTheme.warning,
              ),
            ],
          ),
          if (_isDropset) ...[
            const SizedBox(height: AppSpacing.md),
            _buildMainSetEntry(),
            ..._drops.asMap().entries.map(
              (entry) => _buildDropEntry(entry.key),
            ),
            TextButton.icon(
              onPressed: _addDrop,
              icon: const Icon(Icons.add),
              label: const Text('Add Drop'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainSetEntry() {
    // Controllers are initialized in _loadLastSessionData and updated via onChanged
    // No controller.text assignments in build to avoid cursor jumps
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Text('Start:', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: _mainWeightController,
                    decoration: const InputDecoration(
                      hintText: 'kg',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                    ],
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null) {
                        _currentWeight = parsed;
                        // Don't call setState here - controller is the source of truth during input
                      }
                    },
                  ),
                ),
                const Text(
                  ' × ',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                SizedBox(
                  width: 50,
                  child: TextFormField(
                    controller: _mainRepsController,
                    decoration: const InputDecoration(
                      hintText: 'reps',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null) {
                        _currentReps = parsed;
                        // Don't call setState here - controller is the source of truth during input
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Align with delete button
        ],
      ),
    );
  }

  Widget _buildDropEntry(int index) {
    // Controllers are created and initialized in _addDrop()
    // Build method only READS from controllers, never creates or modifies them
    // This prevents cursor jumps and duplicate controller creation

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            'Drop ${index + 1}:',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: _dropWeightControllers[index],
                    decoration: const InputDecoration(
                      hintText: 'kg',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                    ],
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null) {
                        // Update drop data, controller is source of truth during input
                        _drops[index] = DropsetEntry(
                          weight: parsed,
                          reps: _drops[index].reps,
                        );
                      }
                    },
                  ),
                ),
                const Text(
                  ' × ',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                SizedBox(
                  width: 50,
                  child: TextFormField(
                    controller: _dropRepsControllers[index],
                    decoration: const InputDecoration(
                      hintText: 'reps',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null) {
                        // Update drop data, controller is source of truth during input
                        _drops[index] = DropsetEntry(
                          weight: _drops[index].weight,
                          reps: parsed,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              // Dispose controllers for this drop before removing
              if (index < _dropWeightControllers.length) {
                _dropWeightControllers[index].dispose();
                _dropWeightControllers.removeAt(index);
              }
              if (index < _dropRepsControllers.length) {
                _dropRepsControllers[index].dispose();
                _dropRepsControllers.removeAt(index);
              }
              setState(() => _drops.removeAt(index));
            },
          ),
        ],
      ),
    );
  }

  void _addDrop() {
    setState(() {
      final lastWeight = _drops.isEmpty ? _currentWeight : _drops.last.weight;
      final newWeight = (lastWeight * 0.8).roundToDouble();

      _drops.add(DropsetEntry(weight: newWeight, reps: _currentReps));

      // Create controllers for the new drop (Flutter best practice)
      _dropWeightControllers.add(
        TextEditingController(text: newWeight.toString()),
      );
      _dropRepsControllers.add(
        TextEditingController(text: _currentReps.toString()),
      );
    });
  }

  Widget _buildSetDoneButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _completeSet,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 28),
            SizedBox(width: 12),
            Text(
              'SET DONE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousSets(List<WorkoutSet> sets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This Session',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...sets.asMap().entries.map((entry) {
          final index = entry.key;
          final set = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppTheme.success,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Set ${index + 1}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${set.weight}kg × ${set.reps}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (set.isDropset) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DROP',
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
          );
        }),
      ],
    );
  }

  Widget _buildLastSessionInfo(String exerciseId) {
    final provider = context.read<WorkoutProvider>();
    final lastSession = provider.getLastSessionForExercise(exerciseId);

    if (lastSession == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.textMuted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'First time doing this exercise!',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last Session',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: lastSession.sets.asMap().entries.map((entry) {
              final set = entry.value;
              return Chip(
                label: Text(
                  '${set.weight}kg × ${set.reps}',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: AppTheme.surfaceColor,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(WorkoutProvider provider) {
    final isFirst = provider.currentExerciseIndex == 0;
    final isLast =
        provider.currentExerciseIndex >=
        provider.currentExerciseLogs.length - 1;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isFirst)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  provider.previousExercise();
                  _loadLastSessionData();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLast
                  ? _finishWorkout
                  : () {
                      provider.nextExercise();
                      _loadLastSessionData();
                    },
              icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
              label: Text(isLast ? 'Finish' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Program Meta Banner ====================

  Widget _buildProgramMetaBanner(WorkoutProvider provider) {
    if (widget.programDay == null || widget.programWeek == null) {
      return const SizedBox.shrink();
    }
    final slot = _slotForIndex(provider.currentExerciseIndex);
    if (slot == null) return const SizedBox.shrink();

    final week = widget.programWeek!;
    final displaySets = week.isDeload
        ? (slot.sets - week.deloadSetReduction).clamp(1, 99)
        : slot.sets;
    final repRange = slot.minReps == slot.maxReps
        ? '${slot.minReps} reps'
        : '${slot.minReps}–${slot.maxReps} reps';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: week.isDeload
              ? Colors.amber.withOpacity(0.4)
              : AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (week.isDeload) ...[
                const Icon(
                  Icons.battery_charging_full,
                  size: 14,
                  color: Colors.amber,
                ),
                const SizedBox(width: 4),
                const Text(
                  'DELOAD  ',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
              Text(
                'Target: $displaySets × $repRange',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: [
              _programChip(
                icon: Icons.timer_outlined,
                label: '${slot.restSeconds}s rest',
                color: AppTheme.textSecondary,
              ),
              if (slot.tempo != null)
                _programChip(icon: Icons.speed, label: 'Tempo ${slot.tempo}', color: AppTheme.secondaryColor),
              if (slot.weightPercentage != null)
                _programChip(
                  icon: Icons.fitness_center,
                  label: week.isDeload
                      ? '${(slot.weightPercentage! * week.deloadIntensityFactor).toStringAsFixed(0)}% 1RM'
                      : '${slot.weightPercentage!.toStringAsFixed(0)}% 1RM',
                  color: AppTheme.primaryColor,
                ),
              if (slot.supersetGroupId != null)
                _programChip(icon: Icons.link, label: 'Superset', color: AppTheme.secondaryColor),
            ],
          ),
          if (slot.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              slot.notes!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _programChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  // ==================== Rest Timer View ====================

  Widget _buildRestTimerView() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Container(
      width: double.infinity,
      color: AppTheme.backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'REST TIME',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 72,
              fontWeight: FontWeight.w200,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimerButton(
                icon: Icons.remove_circle_outline,
                label: '-30s',
                onPressed: () => _adjustRestTime(-30),
              ),
              const SizedBox(width: AppSpacing.lg),
              _buildTimerButton(
                icon: Icons.add_circle_outline,
                label: '+30s',
                onPressed: () => _adjustRestTime(30),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: _skipRest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'SKIP',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Actions ====================

  void _completeSet() {
    final provider = context.read<WorkoutProvider>();
    final currentIdx = provider.currentExerciseIndex;
    final currentSlot = _slotForIndex(currentIdx);
    final nextSlot = _slotForIndex(currentIdx + 1);

    final set = WorkoutSet(
      weight: _currentWeight,
      reps: _currentReps,
      isDropset: _isDropset,
      drops: _isDropset ? List.from(_drops) : null,
    );

    provider.addSet(set);
    HapticFeedback.heavyImpact();

    // Update rest time from current slot
    if (currentSlot != null) {
      _restSeconds = currentSlot.restSeconds;
    }

    // Reset dropset state and dispose controllers to prevent memory leaks
    setState(() {
      _isDropset = false;
      // Dispose all drop controllers before clearing
      for (var controller in _dropWeightControllers) {
        controller.dispose();
      }
      for (var controller in _dropRepsControllers) {
        controller.dispose();
      }
      _dropWeightControllers.clear();
      _dropRepsControllers.clear();
      _drops.clear();
    });

    // Superset auto-advance: if next exercise is in the same superset group
    // AND the next slot still needs more sets, advance immediately.
    final isSupersetPair = currentSlot?.supersetGroupId != null &&
        nextSlot?.supersetGroupId == currentSlot?.supersetGroupId;

    if (isSupersetPair &&
        _slotNeedsMoreSets(index: currentIdx + 1, provider: provider)) {
      provider.nextExercise();
      _loadLastSessionData();
      // Apply the next slot's rest time so the subsequent rest is correct
      final newSlot = _slotForIndex(provider.currentExerciseIndex);
      if (newSlot != null) setState(() => _restSeconds = newSlot.restSeconds);
    } else {
      // Detect if we just finished the last exercise in a superset group.
      // If the group still needs more sets, schedule a return after rest.
      final groupId = currentSlot?.supersetGroupId;
      if (groupId != null) {
        final groupStart = _supersetGroupStart(currentIdx, groupId);
        if (_supersetNeedsMoreSets(
          startIdx: groupStart,
          endIdx: currentIdx,
          provider: provider,
        )) {
          _supersetReturnIndex = groupStart;
        }
      }
      _startRestTimer();
    }
  }

  void _startRestTimer() {
    setState(() {
      _isResting = true;
      _remainingSeconds = _restSeconds;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        _skipRest();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    final returnIdx = _supersetReturnIndex;
    setState(() {
      _isResting = false;
      _remainingSeconds = 0;
      _supersetReturnIndex = null;
    });

    // If in a superset cycle, auto-return to the first exercise in the group
    if (returnIdx != null) {
      final provider = context.read<WorkoutProvider>();
      provider.goToExercise(returnIdx);
      _loadLastSessionData();
      final slot = _slotForIndex(returnIdx);
      if (slot != null) setState(() => _restSeconds = slot.restSeconds);
    }

    HapticFeedback.lightImpact();
  }

  void _adjustRestTime(int seconds) {
    setState(() {
      _remainingSeconds = (_remainingSeconds + seconds).clamp(0, 600);
      _restSeconds = (_restSeconds + seconds).clamp(30, 600);
    });
    HapticFeedback.selectionClick();
  }

  void _showNumberPicker(
    double currentValue,
    int decimals,
    Function(double) onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _NumberPickerContent(
        initialValue: currentValue,
        decimals: decimals,
        onChanged: onChanged,
      ),
    );
  }

  void _showOptionsMenu() {
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
              leading: const Icon(Icons.timer),
              title: const Text('Set Rest Timer'),
              subtitle: Text('Currently: ${_restSeconds}s'),
              onTap: () {
                Navigator.pop(context);
                _showRestTimerSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('Add Notes'),
              onTap: () {
                Navigator.pop(context);
                // Show notes dialog
              },
            ),
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Remove Last Set'),
              onTap: () {
                context.read<WorkoutProvider>().removeLastSet();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRestTimerSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Rest Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [30, 60, 90, 120, 150, 180].map((seconds) {
            return ListTile(
              title: Text('$seconds seconds'),
              trailing: _restSeconds == seconds
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () {
                setState(() => _restSeconds = seconds);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Workout?'),
        content: const Text('Your progress will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Workout'),
          ),
          TextButton(
            onPressed: () {
              context.read<WorkoutProvider>().cancelWorkout();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close workout screen
            },
            child: const Text(
              'Cancel Workout',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _finishWorkout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Workout?'),
        content: const Text('Save this workout session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await context.read<WorkoutProvider>().finishWorkout();
              if (mounted) {
                Navigator.pop(context); // Close workout screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Workout saved! Great job! 💪'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Save & Finish'),
          ),
        ],
      ),
    );
  }
}

/// A StatefulWidget for the number picker content that properly manages
/// its TextEditingController lifecycle to avoid memory leaks.
class _NumberPickerContent extends StatefulWidget {
  final double initialValue;
  final int decimals;
  final Function(double) onChanged;

  const _NumberPickerContent({
    required this.initialValue,
    required this.decimals,
    required this.onChanged,
  });

  @override
  State<_NumberPickerContent> createState() => _NumberPickerContentState();
}

class _NumberPickerContentState extends State<_NumberPickerContent> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.decimals == 0
          ? widget.initialValue.toInt().toString()
          : widget.initialValue.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text);
    if (parsed != null) {
      widget.onChanged(parsed);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            decoration: const InputDecoration(labelText: 'Enter value'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(onPressed: _submit, child: const Text('Done')),
        ],
      ),
    );
  }
}
