// workout_header.dart — Header bar for WorkoutFlowScreen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

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
    required this.isFirst,
    required this.isLast,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
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
  final bool isFirst;
  final bool isLast;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
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
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C0C12), Color(0x000C0C12)],
        ),
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: AppColors.textSoft,
                    onPressed: widget.onClose,
                  ),
                  // Exercise info
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.exerciseName,
                          style: GoogleFonts.geist(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Exercise ${widget.currentExerciseIndex + 1} of ${widget.totalExercises} · Set ${widget.setNumber}',
                              style: GoogleFonts.geist(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Timer chip + menu
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              _elapsedLabel,
                              style: GoogleFonts.geistMono(
                                color: AppColors.textSoft,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _OptionsMenu(
                        restSeconds: widget.restSeconds,
                        onRemoveLastSet: widget.onRemoveLastSet,
                        onSetRestTime: widget.onSetRestTime,
                        onFinish: widget.onFinish,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: RFProgressBar(
                value: widget.progress,
                height: 4,
                showGlow: false,
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
