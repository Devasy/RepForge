// exercise_input_section.dart — Set entry UI for WorkoutFlowScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

// ── ExerciseInputSection ──────────────────────────────────────────────────────
// Renders: AI suggestion card, weight/reps inputs, dropset section,
// LOG SET button, previous sets, last session info, program metadata banner.
class ExerciseInputSection extends StatelessWidget {
  const ExerciseInputSection({
    super.key,
    required this.currentWeight,
    required this.currentReps,
    required this.isDropset,
    required this.drops,
    required this.mainWeightController,
    required this.mainRepsController,
    required this.dropWeightControllers,
    required this.dropRepsControllers,
    required this.recommendations,
    required this.previousSets,
    required this.lastSession,
    required this.settings,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onDropsetToggled,
    required this.onDropAdded,
    required this.onDropRemoved,
    required this.onDropWeightChanged,
    required this.onDropRepsChanged,
    required this.onLogSet,
    required this.onApplyRecommendation,
    this.programSlot,
    this.programWeek,
    this.exerciseId,
  });

  final double currentWeight;
  final int currentReps;
  final bool isDropset;
  final List<DropsetEntry> drops;
  final TextEditingController mainWeightController;
  final TextEditingController mainRepsController;
  final List<TextEditingController> dropWeightControllers;
  final List<TextEditingController> dropRepsControllers;
  final List<SetRecommendation> recommendations;
  final List<WorkoutSet> previousSets;
  final ExerciseLog? lastSession;
  final SettingsProvider settings;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final ValueChanged<bool> onDropsetToggled;
  final VoidCallback onDropAdded;
  final ValueChanged<int> onDropRemoved;
  final void Function(int index, double weight) onDropWeightChanged;
  final void Function(int index, int reps) onDropRepsChanged;
  final VoidCallback onLogSet;
  final VoidCallback onApplyRecommendation;
  final ProgramExerciseSlot? programSlot;
  final ProgramWeek? programWeek;
  final String? exerciseId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Program metadata
        if (programSlot != null && programWeek != null)
          _ProgramMetaBanner(slot: programSlot!, week: programWeek!),

        // AI suggestion
        if (recommendations.isNotEmpty)
          _RecommendationCard(
            rec: recommendations[previousSets.length < recommendations.length
                ? previousSets.length
                : recommendations.length - 1],
            settings: settings,
            onApply: onApplyRecommendation,
          ),

        const SizedBox(height: AppSpacing.lg),

        // Weight + reps inputs
        if (!isDropset) ...[
          _InputRow(
            currentWeight: currentWeight,
            currentReps: currentReps,
            settings: settings,
            exerciseId: exerciseId,
            onWeightChanged: onWeightChanged,
            onRepsChanged: onRepsChanged,
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Dropset section
        _DropsetSection(
          isDropset: isDropset,
          drops: drops,
          currentWeight: currentWeight,
          currentReps: currentReps,
          mainWeightController: mainWeightController,
          mainRepsController: mainRepsController,
          dropWeightControllers: dropWeightControllers,
          dropRepsControllers: dropRepsControllers,
          settings: settings,
          onToggled: onDropsetToggled,
          onDropAdded: onDropAdded,
          onDropRemoved: onDropRemoved,
          onDropWeightChanged: onDropWeightChanged,
          onDropRepsChanged: onDropRepsChanged,
        ),

        const SizedBox(height: AppSpacing.lg),

        // LOG SET button
        GlowButton(
          label: 'LOG SET',
          icon: Icons.check_rounded,
          onPressed: onLogSet,
        ),

        // Previous sets
        if (previousSets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _PreviousSetsSection(sets: previousSets, settings: settings),
        ],

        // Last session
        const SizedBox(height: AppSpacing.lg),
        _LastSessionSection(lastSession: lastSession, settings: settings),
      ],
    );
  }
}

// ── Recommendation Card ────────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.rec,
    required this.settings,
    required this.onApply,
  });

  final SetRecommendation rec;
  final SettingsProvider settings;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final displayWeight = settings.toDisplay(rec.weight);
    final weightStr = displayWeight == displayWeight.truncateToDouble()
        ? displayWeight.toStringAsFixed(0)
        : displayWeight.toStringAsFixed(1);
    final confidenceColor = rec.confidence == 'high'
        ? AppColors.success
        : rec.confidence == 'medium'
            ? AppColors.warning
            : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'AI Suggestion',
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: confidenceColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$weightStr ${settings.unitLabel} × ${rec.reps} reps',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              onApply();
              HapticFeedback.lightImpact();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Apply',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input Row ────────────────────────────────────────────────────────────────
class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.currentWeight,
    required this.currentReps,
    required this.settings,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.exerciseId,
  });

  final double currentWeight;
  final int currentReps;
  final SettingsProvider settings;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final String? exerciseId;

  @override
  Widget build(BuildContext context) {
    final isAssistedBW =
        exerciseId == 'pull_ups' || exerciseId == 'chin_ups';
    final weightLabel =
        isAssistedBW ? 'Assist (${settings.unitLabel})' : settings.unitLabel;
    final displayWeight = settings.toDisplay(currentWeight);

    return Row(
      children: [
        Expanded(
          child: _NumberInputCard(
            label: weightLabel,
            value: displayWeight,
            step: settings.weightIncrement,
            decimals: 1,
            onChanged: (v) => onWeightChanged(settings.toStorage(v)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _NumberInputCard(
            label: 'Reps',
            value: currentReps.toDouble(),
            step: 1,
            decimals: 0,
            onChanged: (v) => onRepsChanged(v.toInt()),
          ),
        ),
      ],
    );
  }
}

// ── Number Input Card ─────────────────────────────────────────────────────────
class _NumberInputCard extends StatefulWidget {
  const _NumberInputCard({
    required this.label,
    required this.value,
    required this.step,
    required this.decimals,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberInputCard> createState() => _NumberInputCardState();
}

class _NumberInputCardState extends State<_NumberInputCard> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format());
  }

  @override
  void didUpdateWidget(_NumberInputCard old) {
    super.didUpdateWidget(old);
    // Sync controller when value changes externally (e.g. AI apply, stepper)
    // but don't interrupt the user while they're typing.
    if (old.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = _format();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _format() => widget.decimals > 0
      ? widget.value.toStringAsFixed(widget.decimals)
      : widget.value.toInt().toString();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Text(
            widget.label,
            style: TextStyle(fontFamily: 'Geist', 
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepBtn(
                icon: Icons.remove_rounded,
                onTap: () => widget.onChanged(
                  (widget.value - widget.step).clamp(0, 999).toDouble(),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(fontFamily: 'GeistMono', 
                    color: AppColors.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: widget.decimals > 0,
                  ),
                  inputFormatters: widget.decimals > 0
                      ? [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*$'),
                          ),
                        ]
                      : [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (text) {
                    final parsed = double.tryParse(text);
                    if (parsed != null) {
                      widget.onChanged(parsed.clamp(0, 999).toDouble());
                    }
                  },
                  onEditingComplete: () {
                    final formatted = _format();
                    if (_controller.text != formatted) _controller.text = formatted;
                    _focusNode.unfocus();
                  },
                ),
              ),
              _StepBtn(
                icon: Icons.add_rounded,
                onTap: () => widget.onChanged(
                  (widget.value + widget.step).clamp(0, 999).toDouble(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width < AppBreakpoints.narrow ? 36.0 : 40.0;
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}

// ── Dropset Section ───────────────────────────────────────────────────────────
class _DropsetSection extends StatelessWidget {
  const _DropsetSection({
    required this.isDropset,
    required this.drops,
    required this.currentWeight,
    required this.currentReps,
    required this.mainWeightController,
    required this.mainRepsController,
    required this.dropWeightControllers,
    required this.dropRepsControllers,
    required this.settings,
    required this.onToggled,
    required this.onDropAdded,
    required this.onDropRemoved,
    required this.onDropWeightChanged,
    required this.onDropRepsChanged,
  });

  final bool isDropset;
  final List<DropsetEntry> drops;
  final double currentWeight;
  final int currentReps;
  final TextEditingController mainWeightController;
  final TextEditingController mainRepsController;
  final List<TextEditingController> dropWeightControllers;
  final List<TextEditingController> dropRepsControllers;
  final SettingsProvider settings;
  final ValueChanged<bool> onToggled;
  final VoidCallback onDropAdded;
  final ValueChanged<int> onDropRemoved;
  final void Function(int, double) onDropWeightChanged;
  final void Function(int, int) onDropRepsChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_down_rounded,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Dropset',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Switch(
                value: isDropset,
                onChanged: onToggled,
                activeThumbColor: AppColors.warning,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          if (isDropset) ...[
            const SizedBox(height: AppSpacing.md),
            _DropRow(
              label: 'Start',
              weightController: mainWeightController,
              repsController: mainRepsController,
              unitLabel: settings.unitLabel,
              onWeightChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) onDropWeightChanged(-1, settings.toStorage(parsed));
              },
              onRepsChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null) onDropRepsChanged(-1, parsed);
              },
            ),
            ...drops.asMap().entries.map((e) => _DropRow(
              label: 'Drop ${e.key + 1}',
              weightController: dropWeightControllers[e.key],
              repsController: dropRepsControllers[e.key],
              unitLabel: settings.unitLabel,
              onWeightChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) onDropWeightChanged(e.key, settings.toStorage(parsed));
              },
              onRepsChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null) onDropRepsChanged(e.key, parsed);
              },
              onDelete: () => onDropRemoved(e.key),
            )),
            TextButton.icon(
              onPressed: onDropAdded,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Drop'),
              style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _DropRow extends StatelessWidget {
  const _DropRow({
    required this.label,
    required this.weightController,
    required this.repsController,
    required this.unitLabel,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.onDelete,
  });

  final String label;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final String unitLabel;
  final ValueChanged<String> onWeightChanged;
  final ValueChanged<String> onRepsChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: TextField(
              controller: weightController,
              decoration: InputDecoration(
                hintText: unitLabel,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              onChanged: onWeightChanged,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('×', style: TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: repsController,
              decoration: const InputDecoration(
                hintText: 'reps',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onRepsChanged,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              color: AppColors.textMuted,
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            )
          else
            const SizedBox(width: 32),
        ],
      ),
    );
  }
}

// ── Previous Sets ─────────────────────────────────────────────────────────────
class _PreviousSetsSection extends StatelessWidget {
  const _PreviousSetsSection({required this.sets, required this.settings});

  final List<WorkoutSet> sets;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THIS SESSION',
          style: TextStyle(fontFamily: 'Geist', 
            color: AppColors.textFaint,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sets.asMap().entries.expand((e) {
            final i = e.key;
            final s = e.value;
            final dw = settings.toDisplay(s.weight);
            final wStr = dw == dw.truncateToDouble()
                ? dw.toStringAsFixed(0)
                : dw.toStringAsFixed(1);
            final setChip = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$wStr × ${s.reps}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (s.isDropset)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.trending_down_rounded,
                        size: 12,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            );

            if (settings.showAdvancedMetrics && s.reps > 0 && s.weight > 0) {
              final orm = s.reps == 1
                  ? s.weight
                  : s.weight * (1 + s.reps / 30.0);
              final ormDisplay = settings.toDisplay(orm);
              final ormStr = ormDisplay == ormDisplay.truncateToDouble()
                  ? ormDisplay.toStringAsFixed(0)
                  : ormDisplay.toStringAsFixed(1);
              final ormChip = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '~$ormStr${settings.unitLabel} 1RM',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
              return [setChip, ormChip];
            }

            return [setChip];
          }).toList(),
        ),
      ],
    );
  }
}

// ── Last Session ──────────────────────────────────────────────────────────────
class _LastSessionSection extends StatelessWidget {
  const _LastSessionSection({required this.lastSession, required this.settings});

  final ExerciseLog? lastSession;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    if (lastSession == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.star_outline_rounded,
                color: AppColors.textMuted, size: 16),
            SizedBox(width: 8),
            Text(
              'First time doing this exercise!',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LAST SESSION',
          style: TextStyle(fontFamily: 'Geist', 
            color: AppColors.textFaint,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: lastSession!.sets.map((s) {
            final dw = settings.toDisplay(s.weight);
            final wStr = dw == dw.truncateToDouble()
                ? dw.toStringAsFixed(0)
                : dw.toStringAsFixed(1);
            return Chip(
              label: Text(
                '$wStr × ${s.reps}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
              ),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.glassBorder),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Program Meta Banner ────────────────────────────────────────────────────────
class _ProgramMetaBanner extends StatelessWidget {
  const _ProgramMetaBanner({required this.slot, required this.week});

  final ProgramExerciseSlot slot;
  final ProgramWeek week;

  @override
  Widget build(BuildContext context) {
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: week.isDeload
              ? Colors.amber.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (week.isDeload)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.battery_charging_full_rounded,
                      size: 14, color: Colors.amber),
                ),
              Text(
                'Target: $displaySets × $repRange',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
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
              _metaChip(
                icon: Icons.timer_outlined,
                label: '${slot.restSeconds}s rest',
                color: AppColors.textSoft,
              ),
              if (slot.tempo != null)
                _metaChip(icon: Icons.speed_rounded, label: 'Tempo ${slot.tempo}', color: AppColors.secondary),
              if (slot.supersetGroupId != null)
                _metaChip(icon: Icons.link_rounded, label: 'Superset', color: AppColors.secondary),
            ],
          ),
          if (slot.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              slot.notes!,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
