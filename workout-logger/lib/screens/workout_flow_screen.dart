// workout_flow_screen.dart — Active workout session screen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';


import '../models/models.dart';
import '../services/workout_provider.dart';
import '../services/settings_provider.dart';
import '../services/managers/pr_manager.dart';
import '../theme/app_theme.dart';
import 'add_custom_exercise_screen.dart';
import 'exercise_library_screen.dart';
import 'workout_summary_screen.dart';
import 'widgets/workout_header.dart';
import 'widgets/exercise_input_section.dart';
import 'widgets/rest_timer_view.dart';

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

enum _LeaveAction { discard, keep, cancel }

class _WorkoutFlowScreenState extends State<WorkoutFlowScreen> {
  // Rest timer
  bool _isResting = false;
  int _restSeconds = 90;
  Timer? _restTimer;
  int _remainingSeconds = 0;
  int? _supersetReturnIndex;

  // Set entry state
  double _currentWeight = 20;
  int _currentReps = 10;
  bool _isDropset = false;
  final List<DropsetEntry> _drops = [];

  // Text controllers
  final TextEditingController _mainWeightCtrl = TextEditingController();
  final TextEditingController _mainRepsCtrl = TextEditingController();
  final List<TextEditingController> _dropWeightCtrls = [];
  final List<TextEditingController> _dropRepsCtrls = [];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeWorkout());
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _mainWeightCtrl.dispose();
    _mainRepsCtrl.dispose();
    for (final c in _dropWeightCtrls) {
      c.dispose();
    }
    for (final c in _dropRepsCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Program helpers ─────────────────────────────────────────────────────────

  ProgramDay? _resolvedDay(WorkoutProvider p) =>
      widget.programDay ?? p.activeProgramDay;

  ProgramWeek? _resolvedWeek(WorkoutProvider p) =>
      widget.programWeek ?? p.activeProgramWeek;

  ProgramExerciseSlot? _slot(int idx, {WorkoutProvider? p}) {
    final provider = p ?? context.read<WorkoutProvider>();
    final day = _resolvedDay(provider);
    if (day == null) return null;
    return idx < day.exercises.length ? day.exercises[idx] : null;
  }

  int _supersetGroupStart(int from, String groupId, {WorkoutProvider? p}) {
    int start = from;
    while (start > 0 &&
        _slot(start - 1, p: p)?.supersetGroupId == groupId) {
      start--;
    }
    return start;
  }

  bool _supersetNeedsMoreSets({
    required int startIdx,
    required int endIdx,
    required WorkoutProvider p,
  }) {
    final week = _resolvedWeek(p);
    for (int i = startIdx; i <= endIdx; i++) {
      final s = _slot(i, p: p);
      if (s == null || i >= p.currentExerciseLogs.length) continue;
      final target = week?.isDeload == true
          ? (s.sets - (week?.deloadSetReduction ?? 0)).clamp(1, 99)
          : s.sets;
      if (p.currentExerciseLogs[i].sets.length < target) return true;
    }
    return false;
  }

  bool _slotNeedsMoreSets({required int index, required WorkoutProvider p}) {
    final s = _slot(index, p: p);
    if (s == null || index >= p.currentExerciseLogs.length) return false;
    final week = _resolvedWeek(p);
    final target = week?.isDeload == true
        ? (s.sets - (week?.deloadSetReduction ?? 0)).clamp(1, 99)
        : s.sets;
    return p.currentExerciseLogs[index].sets.length < target;
  }

  // ── Init / data load ────────────────────────────────────────────────────────

  void _initializeWorkout() {
    final provider = context.read<WorkoutProvider>();
    final day = _resolvedDay(provider);
    final week = _resolvedWeek(provider);

    if (provider.hasActiveWorkout) {
      final s = _slot(provider.currentExerciseIndex, p: provider);
      if (s != null) _restSeconds = s.restSeconds;
      _loadLastSessionData();
      return;
    }

    if (day != null) {
      provider.startWorkout(
        exerciseIds: day.exercises.map((s) => s.exerciseId).toList(),
        programDay: day,
        programWeek: week,
      );
      final first = _slot(0, p: provider);
      if (first != null) _restSeconds = first.restSeconds;
      _loadLastSessionData();
    } else if (widget.routine != null) {
      provider.startWorkout(routine: widget.routine);
      _loadLastSessionData();
    } else if (widget.isQuickStart) {
      provider.startWorkout(exerciseIds: []);
    }
  }

  void _loadLastSessionData() {
    final provider = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();
    final exercise = provider.currentExercise;
    if (exercise == null) return;

    final currentHandle = provider.currentExerciseLog?.handle;
    final last = provider.getLastSessionForExercise(
      exercise.id,
      handle: currentHandle,
    );
    if (last != null && last.sets.isNotEmpty) {
      final lastSet = last.sets.last;
      setState(() {
        _currentWeight = lastSet.weight;
        _currentReps = lastSet.reps;
        final dw = settings.toDisplay(_currentWeight);
        _mainWeightCtrl.text = dw == dw.truncateToDouble()
            ? dw.toStringAsFixed(0)
            : dw.toStringAsFixed(1);
        _mainRepsCtrl.text = _currentReps.toString();
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();

    if (!provider.hasActiveWorkout) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (provider.currentExerciseLogs.isEmpty) {
      return _buildExerciseSelector();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _isResting ? _buildRestView(provider) : _buildWorkoutView(provider),
      ),
    );
  }

  Widget _buildExerciseSelector() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Exercises'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _showCancelDialog,
        ),
      ),
      body: ExerciseSelectorScreen(
        selectionMode: true,
        onExercisesSelected: _startWithSelected,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: AppBreakpoints.navBarClearance),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddCustomExerciseScreen()),
          ),
          backgroundColor: AppColors.card,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.glassBorderStrong),
          ),
          icon: const Icon(Icons.add_rounded, color: AppColors.primary),
          label: const Text(
            'New exercise',
            style: TextStyle(
              color: AppColors.textSoft,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startWithSelected(List<String> ids) async {
    if (ids.isEmpty) return;
    final provider = context.read<WorkoutProvider>();
    await provider.cancelWorkout();
    provider.startWorkout(exerciseIds: ids);
  }

  Widget _buildWorkoutView(WorkoutProvider provider) {
    final exercise = provider.currentExercise;
    final log = provider.currentExerciseLog;
    final settings = context.watch<SettingsProvider>();
    final totalExercises = provider.currentExerciseLogs.length;
    final idx = provider.currentExerciseIndex;
    final isFirst = idx == 0;
    final isLast = idx >= totalExercises - 1;

    final selectedHandle = log?.handle;
    final recommendations = exercise != null
        ? provider.getRecommendations(exercise.id, handle: selectedHandle)
        : <SetRecommendation>[];

    final lastSession = exercise != null
        ? provider.getLastSessionForExercise(exercise.id, handle: selectedHandle)
        : null;

    return Column(
      children: [
        WorkoutHeader(
          exerciseName: exercise?.name ?? 'Workout',
          currentExerciseIndex: idx,
          totalExercises: totalExercises,
          setNumber: (log?.sets.length ?? 0) + 1,
          workoutStartTime: provider.workoutStartTime,
          progress: totalExercises > 0 ? (idx + 1) / totalExercises : 0,
          isFirst: isFirst,
          isLast: isLast,
          onClose: _showCancelDialog,
          onPrevious: () {
            provider.previousExercise();
            _loadLastSessionData();
          },
          onNext: () {
            provider.nextExercise();
            _loadLastSessionData();
          },
          onFinish: _finishWorkout,
          onRemoveLastSet: provider.removeLastSet,
          onSetRestTime: (s) => setState(() => _restSeconds = s),
          restSeconds: _restSeconds,
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ExerciseInputSection(
              currentWeight: _currentWeight,
              currentReps: _currentReps,
              isDropset: _isDropset,
              drops: _drops,
              mainWeightController: _mainWeightCtrl,
              mainRepsController: _mainRepsCtrl,
              dropWeightControllers: _dropWeightCtrls,
              dropRepsControllers: _dropRepsCtrls,
              recommendations: recommendations,
              previousSets: log?.sets ?? [],
              lastSession: lastSession,
              settings: settings,
              exerciseId: exercise?.id,
              availableHandles: exercise?.availableHandles,
              selectedHandle: selectedHandle,
              onHandleChanged: (h) {
                provider.setExerciseHandle(h);
                _loadLastSessionData();
              },
              programSlot: _slot(idx, p: provider),
              programWeek: _resolvedWeek(provider),
              onWeightChanged: (v) => setState(() => _currentWeight = v),
              onRepsChanged: (v) => setState(() => _currentReps = v),
              onDropsetToggled: _toggleDropset,
              onDropAdded: _addDrop,
              onDropRemoved: _removeDrop,
              onDropWeightChanged: (i, w) {
                if (i == -1) {
                  _currentWeight = w;
                } else if (i < _drops.length) {
                  _drops[i] = DropsetEntry(weight: w, reps: _drops[i].reps);
                }
              },
              onDropRepsChanged: (i, r) {
                if (i == -1) {
                  _currentReps = r;
                } else if (i < _drops.length) {
                  _drops[i] = DropsetEntry(weight: _drops[i].weight, reps: r);
                }
              },
              onLogSet: _completeSet,
              onApplyRecommendation: () {
                if (recommendations.isEmpty) return;
                final setIdx = (log?.sets.length ?? 0)
                    .clamp(0, recommendations.length - 1);
                final rec = recommendations[setIdx];
                setState(() {
                  _currentWeight = rec.weight;
                  _currentReps = rec.reps;
                  final settings = context.read<SettingsProvider>();
                  final dw = settings.toDisplay(rec.weight);
                  _mainWeightCtrl.text = dw == dw.truncateToDouble()
                      ? dw.toStringAsFixed(0)
                      : dw.toStringAsFixed(1);
                  _mainRepsCtrl.text = rec.reps.toString();
                });
              },
            ),
          ),
        ),
        _buildBottomNav(provider, isFirst, isLast),
      ],
    );
  }

  Widget _buildRestView(WorkoutProvider provider) {
    final idx = provider.currentExerciseIndex;
    final nextExercise = idx + 1 < provider.currentExerciseLogs.length
        ? provider.getExerciseName(
            provider.currentExerciseLogs[idx + 1].exerciseId)
        : null;

    return RestTimerView(
      remainingSeconds: _remainingSeconds,
      totalSeconds: _restSeconds,
      onAdjust: _adjustRest,
      onSkip: _skipRest,
      nextExerciseName: nextExercise,
    );
  }

  Widget _buildBottomNav(WorkoutProvider provider, bool isFirst, bool isLast) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          if (!isFirst)
            Flexible(
              child: GestureDetector(
                onTap: () {
                  provider.previousExercise();
                  _loadLastSessionData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.glass2,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: Border.all(color: AppColors.glassBorderStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Prev',
                        style: TextStyle(fontFamily: 'Geist', 
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          const Spacer(),
          Flexible(
            child: GestureDetector(
              onTap: isLast
                  ? _finishWorkout
                  : () {
                      provider.nextExercise();
                      _loadLastSessionData();
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: isLast ? AppColors.success : AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  boxShadow: [
                    BoxShadow(
                      color: (isLast ? AppColors.success : AppColors.primary)
                          .withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        isLast ? 'Finish' : 'Next exercise',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Geist', 
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
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

  // ── Dropset helpers ─────────────────────────────────────────────────────────

  void _toggleDropset(bool val) {
    setState(() {
      _isDropset = val;
      if (!val) {
        for (final c in _dropWeightCtrls) {
          c.dispose();
        }
        for (final c in _dropRepsCtrls) {
          c.dispose();
        }
        _dropWeightCtrls.clear();
        _dropRepsCtrls.clear();
        _drops.clear();
      } else {
        final settings = context.read<SettingsProvider>();
        final dw = settings.toDisplay(_currentWeight);
        _mainWeightCtrl.text = dw == dw.truncateToDouble()
            ? dw.toStringAsFixed(0)
            : dw.toStringAsFixed(1);
        _mainRepsCtrl.text = _currentReps.toString();
      }
    });
  }

  void _addDrop() {
    final settings = context.read<SettingsProvider>();
    setState(() {
      final lastWeight = _drops.isEmpty ? _currentWeight : _drops.last.weight;
      final newWeight = (lastWeight * 0.8).roundToDouble();
      _drops.add(DropsetEntry(weight: newWeight, reps: _currentReps));
      final dw = settings.toDisplay(newWeight);
      final dwStr = dw == dw.truncateToDouble()
          ? dw.toStringAsFixed(0)
          : dw.toStringAsFixed(1);
      _dropWeightCtrls.add(TextEditingController(text: dwStr));
      _dropRepsCtrls.add(
        TextEditingController(text: _currentReps.toString()),
      );
    });
  }

  void _removeDrop(int index) {
    if (index < _dropWeightCtrls.length) {
      _dropWeightCtrls[index].dispose();
      _dropWeightCtrls.removeAt(index);
    }
    if (index < _dropRepsCtrls.length) {
      _dropRepsCtrls[index].dispose();
      _dropRepsCtrls.removeAt(index);
    }
    setState(() => _drops.removeAt(index));
  }

  // ── Set completion ──────────────────────────────────────────────────────────

  void _completeSet() {
    final provider = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();
    final idx = provider.currentExerciseIndex;
    final currentSlot = _slot(idx, p: provider);
    final nextSlot = _slot(idx + 1, p: provider);

    // For bodyweight-assisted exercises (assisted dips/pull-ups/etc.) the
    // weight input represents the assist load, not the lifted load. Snapshot
    // the assist weight and the bodyweight it was computed against so
    // historical volume stays correct even if the user's bodyweight later
    // changes in settings.
    final isAssistedBW =
        isAssistedBodyweightExercise(provider.currentExercise?.id);

    final set = WorkoutSet(
      weight: _currentWeight,
      reps: _currentReps,
      isDropset: _isDropset,
      drops: _isDropset ? List.from(_drops) : null,
      assistWeight: isAssistedBW ? _currentWeight : null,
      bodyWeightAtLog: isAssistedBW ? settings.userBodyWeight : null,
    );

    provider.addSet(set);
    HapticFeedback.heavyImpact();

    if (currentSlot != null) _restSeconds = currentSlot.restSeconds;

    setState(() {
      _isDropset = false;
      for (final c in _dropWeightCtrls) {
        c.dispose();
      }
      for (final c in _dropRepsCtrls) {
        c.dispose();
      }
      _dropWeightCtrls.clear();
      _dropRepsCtrls.clear();
      _drops.clear();
    });

    // Superset auto-advance
    final isSupersetPair = currentSlot?.supersetGroupId != null &&
        nextSlot?.supersetGroupId == currentSlot?.supersetGroupId;

    if (isSupersetPair &&
        _slotNeedsMoreSets(index: idx + 1, p: provider)) {
      provider.nextExercise();
      _loadLastSessionData();
      final newSlot = _slot(provider.currentExerciseIndex, p: provider);
      if (newSlot != null) setState(() => _restSeconds = newSlot.restSeconds);
    } else {
      final groupId = currentSlot?.supersetGroupId;
      if (groupId != null) {
        final groupStart =
            _supersetGroupStart(idx, groupId, p: provider);
        if (_supersetNeedsMoreSets(
          startIdx: groupStart,
          endIdx: idx,
          p: provider,
        )) {
          _supersetReturnIndex = groupStart;
        }
      }
      _startRestTimer();
    }
  }

  // ── Rest timer ──────────────────────────────────────────────────────────────

  void _startRestTimer() {
    setState(() {
      _isResting = true;
      _remainingSeconds = _restSeconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
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
    if (returnIdx != null) {
      final provider = context.read<WorkoutProvider>();
      provider.goToExercise(returnIdx);
      _loadLastSessionData();
      final s = _slot(returnIdx, p: provider);
      if (s != null) setState(() => _restSeconds = s.restSeconds);
    }
    HapticFeedback.lightImpact();
  }

  void _adjustRest(int delta) {
    setState(() {
      _remainingSeconds = (_remainingSeconds + delta).clamp(0, 600);
      _restSeconds = (_restSeconds + delta).clamp(30, 600);
    });
    HapticFeedback.selectionClick();
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        title: const Text('Cancel Workout?'),
        content: const Text('Your progress will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final ctxNav = Navigator.of(ctx);
              await context.read<WorkoutProvider>().cancelWorkout();
              if (!mounted) return;
              ctxNav.pop();
              nav.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _finishWorkout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        title: const Text('Finish Workout?'),
        content: const Text('Ready to save this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final prManager = context.read<PRManager>();
              Navigator.of(ctx).pop();
              final session =
                  await context.read<WorkoutProvider>().finishWorkout();
              final newPRs = await prManager.checkAndUpdatePRs(session);
              if (!mounted) return;
              nav.pushReplacement(MaterialPageRoute(
                builder: (_) => WorkoutSummaryScreen(
                  session: session,
                  newPRs: newPRs,
                ),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Save & Finish'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBack() async {
    final action = await showDialog<_LeaveAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        title: const Text('Leave workout?'),
        content: const Text(
          'Progress is saved. You can resume next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.discard),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.keep),
            child: const Text('Keep & exit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveAction.cancel),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == _LeaveAction.discard) {
      await context.read<WorkoutProvider>().cancelWorkout();
      if (mounted) Navigator.pop(context);
    } else if (action == _LeaveAction.keep) {
      Navigator.pop(context);
    }
  }
}
