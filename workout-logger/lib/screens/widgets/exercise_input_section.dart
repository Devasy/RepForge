// exercise_input_section.dart — Set entry UI for WorkoutFlowScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/settings_provider.dart';
import '../../theme/app_theme.dart';
import 'rf_shell.dart';

// ── ExerciseInputSection ──────────────────────────────────────────────────────
// Suggestion card, weight/reps inputs, dropset, session history, program meta.
class ExerciseInputSection extends StatelessWidget {
  const ExerciseInputSection({
    super.key,
    required this.contentWidth,
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
    required this.onApplyRecommendation,
    this.programSlot,
    this.programWeek,
    this.exerciseId,
    this.availableHandles,
    this.selectedHandle,
    this.onHandleChanged,
  });

  /// Layout width minus padding. Passed in, not measured: the host screen's [IntrinsicHeight] (which [Spacer] needs) forbids a [LayoutBuilder] under it.
  final double contentWidth;

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
  final VoidCallback onApplyRecommendation;
  final ProgramExerciseSlot? programSlot;
  final ProgramWeek? programWeek;
  final String? exerciseId;
  final List<String>? availableHandles;
  final String? selectedHandle;
  final ValueChanged<String?>? onHandleChanged;

  @override
  Widget build(BuildContext context) {
    final isAssistedBW = isAssistedBodyweightExercise(exerciseId);
    final effectiveWeight = (settings.userBodyWeight - currentWeight).clamp(0.0, 500.0);
    final effectiveWeightDisplay = settings.toDisplay(effectiveWeight);
    final bodyWeightDisplay = settings.toDisplay(settings.userBodyWeight);
    final currentWeightDisplay = settings.toDisplay(currentWeight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Program metadata
        if (programSlot != null && programWeek != null)
          _ProgramMetaBanner(slot: programSlot!, week: programWeek!),

        // Handle / Attachment Selector
        if (availableHandles != null && availableHandles!.isNotEmpty) ...[
          _HandleSelector(
            availableHandles: availableHandles!,
            selectedHandle: selectedHandle,
            onChanged: onHandleChanged,
            // Once a set has been logged for this exercise instance, the
            // handle is locked — the selector must not let the user (or
            // silently appear to) relabel already-recorded sets.
            locked: previousSets.isNotEmpty,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

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
            contentWidth: contentWidth,
            currentWeight: currentWeight,
            currentReps: currentReps,
            settings: settings,
            isAssistedBW: isAssistedBW,
            onWeightChanged: onWeightChanged,
            onRepsChanged: onRepsChanged,
          ),
          if (isAssistedBW) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  // Long enough to wrap on a narrow phone, more so at a large text scale.
                  Expanded(
                    child: Text(
                      'Effective Volume Load: ${effectiveWeightDisplay.toStringAsFixed(1)} ${settings.unitLabel} (${bodyWeightDisplay.toStringAsFixed(1)} BW − ${currentWeightDisplay.toStringAsFixed(1)} Assist) × $currentReps reps',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSoft, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

        // Absorbs leftover height so the history below reads as a footer.
        const Spacer(),

        if (previousSets.isNotEmpty) ...[
          _PreviousSetsSection(sets: previousSets, settings: settings),
          const SizedBox(height: AppSpacing.lg),
        ],
        _LastSessionSection(lastSession: lastSession, settings: settings),
      ],
    );
  }
}

// ── Handle Selector ──────────────────────────────────────────────────────────
class _HandleSelector extends StatelessWidget {
  const _HandleSelector({
    required this.availableHandles,
    required this.selectedHandle,
    required this.onChanged,
    this.locked = false,
  });

  final List<String> availableHandles;
  final String? selectedHandle;
  final ValueChanged<String?>? onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    // Only show a chip as selected once the user (or a restored draft) has
    // actually chosen it — never default-highlight the first handle just
    // because nothing has been persisted yet.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFLabel('Attachment'),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableHandles.map((handle) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: RFOptionChip(
                  label: handle,
                  selected: selectedHandle == handle,
                  inMutuallyExclusiveGroup: true,
                  onTap: locked || onChanged == null
                      ? null
                      : () => onChanged!(handle),
                ),
              );
            }).toList(),
          ),
        ),
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
                    const Flexible(
                      child: Text(
                        'AI Suggestion',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
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
    required this.contentWidth,
    required this.currentWeight,
    required this.currentReps,
    required this.settings,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.isAssistedBW = false,
  });

  final double contentWidth;
  final double currentWeight;
  final int currentReps;
  final SettingsProvider settings;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final bool isAssistedBW;

  @override
  Widget build(BuildContext context) {
    final weightLabel =
        isAssistedBW ? 'Assist (${settings.unitLabel})' : settings.unitLabel;
    final displayWeight = settings.toDisplay(currentWeight);

    // Once a large system font squeezes the value past legibility, stack rather than shrink the digits further.
    final pairedWidth = (contentWidth - AppSpacing.md) / 2;
    final stacked = !_NumberInputCard.valueFits(context, pairedWidth);
    final cardWidth = stacked ? contentWidth : pairedWidth;

    final weightCard = _NumberInputCard(
      cardWidth: cardWidth,
      label: weightLabel,
      value: displayWeight,
      step: settings.weightIncrement,
      decimals: 1,
      onChanged: (v) => onWeightChanged(settings.toStorage(v)),
    );
    final repsCard = _NumberInputCard(
      cardWidth: cardWidth,
      label: 'Reps',
      value: currentReps.toDouble(),
      step: 1,
      decimals: 0,
      onChanged: (v) => onRepsChanged(v.toInt()),
    );

    if (stacked) {
      return Column(
        children: [
          weightCard,
          const SizedBox(height: AppSpacing.md),
          repsCard,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: weightCard),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: repsCard),
      ],
    );
  }
}

// ── Number Input Card ─────────────────────────────────────────────────────────
class _NumberInputCard extends StatefulWidget {
  const _NumberInputCard({
    required this.cardWidth,
    required this.label,
    required this.value,
    required this.step,
    required this.decimals,
    required this.onChanged,
  });

  /// Laid-out width; passed for the reason [ExerciseInputSection.contentWidth] gives.
  final double cardWidth;

  final String label;
  final double value;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;

  /// Tighter than the usual `md`, to leave the value more of the row.
  static const double hPadding = AppSpacing.sm + 2;

  static const double maxValueFontSize = 36;
  static const double minValueFontSize = 18;

  /// Room left for the value between the two steppers in a card [cardWidth] wide.
  static double valueSlotWidth(BuildContext context, double cardWidth) =>
      cardWidth - hPadding * 2 - _StepBtn.sizeOf(context) * 2;

  /// Whether a card [cardWidth] wide still shows `100.0` legibly — [_InputRow] stacks when it does not.
  static bool valueFits(BuildContext context, double cardWidth) =>
      valueSlotWidth(context, cardWidth) >=
      measureValue(context, '100.0', minValueFontSize);

  static TextStyle valueStyle(double fontSize) => TextStyle(
        fontFamily: 'GeistMono',
        color: AppColors.textPrimary,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      );

  /// Width [text] paints at, honouring the reader's text scale.
  static double measureValue(
      BuildContext context, String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: valueStyle(fontSize)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

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

  /// Largest size that paints [text] inside the value slot, floored at [_NumberInputCard.minValueFontSize].
  double _fitFontSize(BuildContext context, String text) {
    const maxSize = _NumberInputCard.maxValueFontSize;
    final slot = _NumberInputCard.valueSlotWidth(context, widget.cardWidth);
    if (!slot.isFinite) return maxSize;
    // A few pixels for the caret, which sits past the last glyph.
    final available = slot - 4;
    if (available <= 0) return _NumberInputCard.minValueFontSize;
    final natural = _NumberInputCard.measureValue(context, text, maxSize);
    if (natural <= available || natural <= 0) return maxSize;
    return (maxSize * available / natural)
        .clamp(_NumberInputCard.minValueFontSize, maxSize);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _NumberInputCard.hPadding,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          // Kept to one line so the two cards in a row stay the same height.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RFLabel(widget.label),
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
                // Re-fitted per keystroke: a 3-digit weight or a large system font would otherwise be clipped.
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: _NumberInputCard.valueStyle(
                      _fitFontSize(
                        context,
                        value.text.isEmpty ? _format() : value.text,
                      ),
                    ),
                    maxLines: 1,
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
                      if (_controller.text != formatted) {
                        _controller.text = formatted;
                      }
                      _focusNode.unfocus();
                    },
                  ),
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

  /// Fixed: a stepper stays a thumb target, so the value beside it is what gives.
  static double sizeOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.narrow ? 36.0 : 40.0;

  @override
  Widget build(BuildContext context) {
    final size = sizeOf(context);
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
              const Expanded(
                child: Text(
                  'Dropset',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
        const RFLabel('This session', dim: true),
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
            Expanded(
              child: Text(
                'First time doing this exercise!',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RFLabel('Last session', dim: true),
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
              Flexible(
                child: Text(
                  'Target: $displaySets × $repRange',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
