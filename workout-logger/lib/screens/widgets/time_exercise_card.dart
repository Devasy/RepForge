// time_exercise_card.dart — Live duration tracking for time-based holds
// Features dual-mode tracking: live stopwatch & countdown presets, plus manual editing.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';
import 'rf_shell.dart';

enum TimeTrackMode { stopwatch, timer }

class TimeExerciseCard extends StatefulWidget {
  const TimeExerciseCard({
    super.key,
    required this.durationSeconds,
    required this.onDurationChanged,
    required this.currentWeight,
    required this.onWeightChanged,
    required this.settings,
    this.initialWeight = 0.0,
  });

  final int durationSeconds;
  final ValueChanged<int> onDurationChanged;
  final double currentWeight;
  final ValueChanged<double> onWeightChanged;
  final SettingsProvider settings;
  final double initialWeight;

  @override
  State<TimeExerciseCard> createState() => _TimeExerciseCardState();
}

class _TimeExerciseCardState extends State<TimeExerciseCard> {
  TimeTrackMode _mode = TimeTrackMode.stopwatch;
  Timer? _ticker;
  bool _isRunning = false;

  // Stopwatch state
  int _stopwatchElapsed = 0;

  // Countdown timer state
  int _timerInitialSeconds = 60;
  int _timerRemainingSeconds = 60;

  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _stopwatchElapsed = widget.durationSeconds > 0 ? widget.durationSeconds : 0;
    _timerInitialSeconds = widget.durationSeconds > 0 ? widget.durationSeconds : 60;
    _timerRemainingSeconds = _timerInitialSeconds;
    final initialDisplay = widget.currentWeight > 0 ? widget.settings.toDisplay(widget.currentWeight) : 0.0;
    _weightController = TextEditingController(
      text: initialDisplay > 0
          ? (initialDisplay == initialDisplay.truncateToDouble()
              ? initialDisplay.toStringAsFixed(0)
              : initialDisplay.toStringAsFixed(1))
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant TimeExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRunning && widget.durationSeconds != oldWidget.durationSeconds) {
      _stopwatchElapsed = widget.durationSeconds;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _weightController.dispose();
    super.dispose();
  }

  void _toggleStopwatch() {
    if (_isRunning) {
      _ticker?.cancel();
      setState(() => _isRunning = false);
      widget.onDurationChanged(_stopwatchElapsed);
    } else {
      setState(() => _isRunning = true);
      HapticFeedback.lightImpact();
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _stopwatchElapsed++;
        });
        widget.onDurationChanged(_stopwatchElapsed);
      });
    }
  }

  void _resetStopwatch() {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
      _stopwatchElapsed = 0;
    });
    widget.onDurationChanged(0);
  }

  void _toggleTimer() {
    if (_isRunning) {
      _ticker?.cancel();
      setState(() => _isRunning = false);
    } else {
      if (_timerRemainingSeconds <= 0) {
        _timerRemainingSeconds = _timerInitialSeconds;
      }
      setState(() => _isRunning = true);
      HapticFeedback.lightImpact();
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_timerRemainingSeconds > 1) {
          setState(() {
            _timerRemainingSeconds--;
          });
          widget.onDurationChanged(_timerInitialSeconds - _timerRemainingSeconds);
        } else {
          timer.cancel();
          setState(() {
            _timerRemainingSeconds = 0;
            _isRunning = false;
          });
          widget.onDurationChanged(_timerInitialSeconds);
          HapticFeedback.heavyImpact();
        }
      });
    }
  }

  void _resetTimer() {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
      _timerRemainingSeconds = _timerInitialSeconds;
    });
    widget.onDurationChanged(_timerInitialSeconds);
  }

  void _selectPreset(int seconds) {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
      _timerInitialSeconds = seconds;
      _timerRemainingSeconds = seconds;
      _stopwatchElapsed = seconds;
    });
    widget.onDurationChanged(seconds);
    HapticFeedback.selectionClick();
  }

  void _adjustSeconds(int delta) {
    if (_mode == TimeTrackMode.stopwatch) {
      final updated = (_stopwatchElapsed + delta).clamp(0, 3600);
      setState(() => _stopwatchElapsed = updated);
      widget.onDurationChanged(updated);
    } else {
      final updated = (_timerRemainingSeconds + delta).clamp(5, 3600);
      setState(() {
        _timerRemainingSeconds = updated;
        _timerInitialSeconds = updated;
      });
      widget.onDurationChanged(updated);
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _editDurationManually() async {
    final controller = TextEditingController(
      text: '${_mode == TimeTrackMode.stopwatch ? _stopwatchElapsed : _timerRemainingSeconds}',
    );

    final entered = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Set Duration (seconds)',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'e.g. 60',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            suffixText: 'sec',
            suffixStyle: const TextStyle(color: AppColors.primary),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.glassBorder),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.primary),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSoft)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(val);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Set', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (entered != null && entered >= 0 && mounted) {
      setState(() {
        if (_mode == TimeTrackMode.stopwatch) {
          _stopwatchElapsed = entered;
        } else {
          _timerInitialSeconds = entered;
          _timerRemainingSeconds = entered;
        }
      });
      widget.onDurationChanged(entered);
    }
  }

  String _formatTime(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentSecs = _mode == TimeTrackMode.stopwatch ? _stopwatchElapsed : _timerRemainingSeconds;
    final progress = _mode == TimeTrackMode.timer && _timerInitialSeconds > 0
        ? (_timerRemainingSeconds / _timerInitialSeconds).clamp(0.0, 1.0)
        : 1.0;

    return GlassCard(
      accentBorder: _isRunning,
      glowColor: _isRunning ? AppColors.primary : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode toggle row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.glass1,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _ModeChip(
                      label: 'Stopwatch',
                      icon: Icons.timer_outlined,
                      active: _mode == TimeTrackMode.stopwatch,
                      onTap: () {
                        if (_mode != TimeTrackMode.stopwatch) {
                          _ticker?.cancel();
                          setState(() {
                            _mode = TimeTrackMode.stopwatch;
                            _isRunning = false;
                          });
                        }
                      },
                    ),
                    _ModeChip(
                      label: 'Countdown',
                      icon: Icons.hourglass_bottom_rounded,
                      active: _mode == TimeTrackMode.timer,
                      onTap: () {
                        if (_mode != TimeTrackMode.timer) {
                          _ticker?.cancel();
                          setState(() {
                            _mode = TimeTrackMode.timer;
                            _isRunning = false;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textMuted),
                tooltip: 'Set duration manually',
                onPressed: _isRunning ? null : _editDurationManually,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Preset Chips (for quick countdowns / target duration)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [30, 45, 60, 90, 120].map((s) {
              final isSelected = (_mode == TimeTrackMode.timer && _timerInitialSeconds == s) ||
                  (_mode == TimeTrackMode.stopwatch && _stopwatchElapsed == s);
              return GestureDetector(
                onTap: () => _selectPreset(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.glass1,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${s}s',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textSoft,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Big Display & Radial Progress
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: AppColors.glassBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isRunning ? AppColors.secondary : AppColors.primary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isRunning ? null : _editDurationManually,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(currentSecs),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _mode == TimeTrackMode.stopwatch
                            ? (_isRunning ? 'HOLDING...' : 'HOLD TIME')
                            : (_isRunning ? 'COUNTING DOWN' : 'TARGET TIME'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: _isRunning ? AppColors.secondary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Action Controls: -5s, Start/Pause, +5s, Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RFIconButton(
                icon: Icons.remove_rounded,
                tooltip: '-5 seconds',
                size: 44,
                onTap: () => _adjustSeconds(-5),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GlowButton(
                  label: _isRunning ? 'Pause' : 'Start',
                  icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onPressed: _mode == TimeTrackMode.stopwatch ? _toggleStopwatch : _toggleTimer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              RFIconButton(
                icon: Icons.add_rounded,
                tooltip: '+5 seconds',
                size: 44,
                onTap: () => _adjustSeconds(5),
              ),
              const SizedBox(width: AppSpacing.xs),
              RFIconButton(
                icon: Icons.replay_rounded,
                tooltip: 'Reset',
                size: 44,
                onTap: _mode == TimeTrackMode.stopwatch ? _resetStopwatch : _resetTimer,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Optional Added Weight row (for weighted holds e.g. plate on back)
          Row(
            children: [
              const Icon(Icons.fitness_center_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.xs),
              const Text(
                'Added Weight (Optional)',
                style: TextStyle(fontSize: 12, color: AppColors.textSoft, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    suffixText: widget.settings.unitLabel,
                    suffixStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    hintText: '0.0',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.glass1,
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  onChanged: (val) {
                    final d = double.tryParse(val.trim()) ?? 0.0;
                    widget.onWeightChanged(widget.settings.toStorage(d));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
