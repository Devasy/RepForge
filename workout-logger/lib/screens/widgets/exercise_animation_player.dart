import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../data/exercise_animations.dart';
import '../../data/exercise_database.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'exercise_movement_painter.dart';

/// Offline, user-controlled movement illustrations. Playback is opt-in and
/// stops when hidden, covered by another route, or sent to the background.
class ExerciseAnimationPlayer extends StatefulWidget {
  const ExerciseAnimationPlayer({super.key, required this.exercise});
  final Exercise exercise;

  @override
  State<ExerciseAnimationPlayer> createState() =>
      _ExerciseAnimationPlayerState();
}

class _ExerciseAnimationPlayerState extends State<ExerciseAnimationPlayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _playing = false;
  bool _reducedMotion = false;
  double _speed = 1;
  ExerciseAnimation? get _animation =>
      ExerciseAnimation.forExercise(widget.exercise);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(_checkVisibility);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion || !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      _playing = false;
    }
  }

  @override
  void didUpdateWidget(ExerciseAnimationPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exercise.id != oldWidget.exercise.id ||
        widget.exercise.isCustom != oldWidget.exercise.isCustom) {
      _controller.stop();
      _controller.value = 0;
      _playing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pause();
    }
  }

  void _checkVisibility() {
    if (!_playing || !mounted) return;
    final box = context.findRenderObject();
    if (ModalRoute.of(context)?.isCurrent == false) {
      _pause();
    } else if (box is RenderBox && box.hasSize && box.attached) {
      final top = box.localToGlobal(Offset.zero).dy;
      if (top >= MediaQuery.sizeOf(context).height ||
          top + box.size.height <= 0) {
        _pause();
      }
    }
  }

  void _pause() {
    _controller.stop();
    if (_playing && mounted) setState(() => _playing = false);
  }

  void _toggle() {
    if (_playing) {
      _pause();
    } else {
      setState(() => _playing = true);
      _controller.repeat(
        period: Duration(milliseconds: (4000 / _speed).round()),
      );
    }
  }

  void _changeSpeed(double speed) {
    setState(() => _speed = speed);
    if (_playing) {
      _controller.repeat(
        period: Duration(milliseconds: (4000 / _speed).round()),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    if (animation == null) return const SizedBox.shrink();
    final muscleId =
        widget.exercise.muscleActivations.firstOrNull?.muscleGroupId;
    final muscleColor = muscleId == null
        ? AppColors.primary
        : AppColors.muscle(muscleId);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            final amount = (1 - math.cos(progress * 2 * math.pi)) / 2;
            final returning = progress >= .5;
            final cue = returning ? animation.secondCue : animation.firstCue;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.exercise.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Movement illustration',
                  style: TextStyle(color: AppColors.textSoft),
                ),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  image: true,
                  label: '${widget.exercise.name} movement illustration. $cue.',
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: double.infinity,
                      height: 240,
                      child: CustomPaint(
                        key: const ValueKey('exercise-movement-canvas'),
                        painter: ExerciseMovementPainter(
                          animation: animation,
                          amount: amount,
                          muscleColor: muscleColor,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  animation.isHold
                      ? 'Hold position'
                      : returning
                      ? 'Return'
                      : 'Movement',
                  style: TextStyle(
                    color: muscleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(cue, style: const TextStyle(color: AppColors.textPrimary)),
                if (!animation.isHold) ...[
                  Slider(
                    key: const ValueKey('exercise-movement-slider'),
                    value: progress,
                    label: '${(progress * 100).round()}% of repetition',
                    semanticFormatterCallback: (value) =>
                        '${(value * 100).round()} percent of repetition',
                    onChangeStart: (_) => _pause(),
                    onChanged: (value) {
                      _pause();
                      _controller.value = value;
                    },
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _reducedMotion ? null : _toggle,
                        icon: Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(_playing ? 'Pause' : 'Play'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 48),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Restart movement',
                        onPressed: () {
                          _pause();
                          _controller.value = 0;
                        },
                        icon: const Icon(Icons.replay_rounded),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                      ),
                      PopupMenuButton<double>(
                        tooltip: 'Playback speed',
                        initialValue: _speed,
                        onSelected: _changeSpeed,
                        itemBuilder: (_) => [
                          for (final speed in [.5, 1.0, 1.5])
                            PopupMenuItem(
                              value: speed,
                              child: Text('$speed× speed'),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Text(
                            '$_speed× speed',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_reducedMotion) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Motion is off. Drag the slider to inspect each position.',
                      style: TextStyle(color: AppColors.textSoft),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    animation.secondCue,
                    style: const TextStyle(color: AppColors.textSoft),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Simplified movement diagram. Highlight shows the target muscle group.',
                  style: TextStyle(color: AppColors.textSoft, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

@Preview(name: 'Squat movement', group: 'Exercise guides', size: Size(360, 600))
Widget squatMovementPreview() => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: ExerciseAnimationPlayer(
        exercise: ExerciseDatabase.getAll().firstWhere((e) => e.id == 'squat'),
      ),
    ),
  ),
);
