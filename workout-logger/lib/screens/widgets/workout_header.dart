// workout_header.dart — Header bar for WorkoutFlowScreen

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';
import 'rf_shell.dart';

// ── WorkoutHeader ─────────────────────────────────────────────────────────────
// Shows exercise name, set/exercise progress, elapsed timer, and nav actions.
class WorkoutHeader extends StatefulWidget {
  const WorkoutHeader({
    super.key,
    required this.exerciseName,
    required this.currentExerciseIndex,
    required this.totalExercises,
    required this.setNumber,
    required this.workoutStartTime,
    required this.progress,
    required this.onClose,
    required this.onFinish,
    required this.onRemoveLastSet,
    required this.onSetRestTime,
    this.restSeconds = 90,
  });

  final String exerciseName;
  final int currentExerciseIndex;
  final int totalExercises;
  final int setNumber;
  final DateTime? workoutStartTime;
  final double progress;
  final VoidCallback onClose;
  final VoidCallback onFinish;
  final VoidCallback onRemoveLastSet;
  final void Function(int seconds) onSetRestTime;
  final int restSeconds;

  @override
  State<WorkoutHeader> createState() => _WorkoutHeaderState();
}

class _WorkoutHeaderState extends State<WorkoutHeader> {
  late Timer _ticker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
  }

  void _updateElapsed() {
    if (widget.workoutStartTime == null) return;
    setState(() {
      _elapsedSeconds =
          DateTime.now().difference(widget.workoutStartTime!).inSeconds;
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Left-aligned title, matching every other screen header in the app. The
    // title used to be centred while the leading and trailing clusters had
    // very different widths, which pushed it visibly off the optical centre.
    return RFScreenHeader(
      title: widget.exerciseName,
      subtitle:
          'Exercise ${widget.currentExerciseIndex + 1} of ${widget.totalExercises} · Set ${widget.setNumber}',
      onBack: widget.onClose,
      leadingIcon: Icons.close_rounded,
      leadingTooltip: 'Cancel workout',
      actions: [
        _ElapsedChip(label: _elapsedLabel),
        _OptionsMenu(
          restSeconds: widget.restSeconds,
          onRemoveLastSet: widget.onRemoveLastSet,
          onSetRestTime: widget.onSetRestTime,
          onFinish: widget.onFinish,
        ),
      ],
      bottom: RFProgressBar(
        value: widget.progress,
        height: 3,
        showGlow: false,
      ),
    );
  }
}

// ── Elapsed chip ──────────────────────────────────────────────────────────────
class _ElapsedChip extends StatelessWidget {
  const _ElapsedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Elapsed time',
      value: label,
      child: Container(
        // A floor, not a fixed height: a large text scale needs more than 38pt.
        constraints: const BoxConstraints(minHeight: 38),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.glass2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'GeistMono',
                color: AppColors.textSoft,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Options Menu ──────────────────────────────────────────────────────────────
class _OptionsMenu extends StatelessWidget {
  const _OptionsMenu({
    required this.restSeconds,
    required this.onRemoveLastSet,
    required this.onSetRestTime,
    required this.onFinish,
  });

  final int restSeconds;
  final VoidCallback onRemoveLastSet;
  final void Function(int) onSetRestTime;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppColors.cardHigh,
      icon: const Icon(
        Icons.more_vert_rounded,
        color: AppColors.textSoft,
        size: 22,
      ),
      onSelected: (v) {
        if (v == 'remove') onRemoveLastSet();
        if (v == 'finish') onFinish();
        if (v.startsWith('rest_')) {
          onSetRestTime(int.parse(v.substring(5)));
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'remove', child: Text('Remove Last Set')),
        const PopupMenuDivider(),
        for (final s in [30, 60, 90, 120, 180])
          PopupMenuItem(
            value: 'rest_$s',
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16),
                const SizedBox(width: 8),
                Text('Rest: ${s}s'),
                if (restSeconds == s) ...[
                  const Spacer(),
                  const Icon(Icons.check_rounded, size: 14),
                ],
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'finish',
          child: Text('Finish Workout',
              style: TextStyle(color: AppColors.success)),
        ),
      ],
    );
  }
}
