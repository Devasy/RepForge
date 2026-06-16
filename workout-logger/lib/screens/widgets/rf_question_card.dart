// rf_question_card.dart — Reusable AI question card (option chips + custom input).
// Used by RoutineOptimizerScreen when the AI calls ask_user_questions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

/// Renders a list of [QuestionSpec]s as interactive chip cards and calls
/// [onSubmit] with all answers when the user taps "Continue".
class RFQuestionCard extends StatefulWidget {
  const RFQuestionCard({
    super.key,
    required this.questions,
    required this.onSubmit,
  });

  final List<QuestionSpec> questions;
  final ValueChanged<List<AnswerSpec>> onSubmit;

  @override
  State<RFQuestionCard> createState() => _RFQuestionCardState();
}

class _RFQuestionCardState extends State<RFQuestionCard> {
  late final List<Set<String>> _selected;
  late final List<TextEditingController> _customCtrls;

  @override
  void initState() {
    super.initState();
    _selected = List.generate(widget.questions.length, (_) => {});
    _customCtrls = List.generate(
      widget.questions.length,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (final c in _customCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    final answers = <AnswerSpec>[
      for (var i = 0; i < widget.questions.length; i++)
        AnswerSpec(
          question: widget.questions[i].question,
          selected: _selected[i].toList(),
          custom: _customCtrls[i].text.trim().isEmpty
              ? null
              : _customCtrls[i].text.trim(),
        ),
    ];
    widget.onSubmit(answers);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded,
                  size: 14, color: AppColors.secondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'QUICK QUESTIONS',
                style: TextStyle(fontFamily: 'Geist', 
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < widget.questions.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 1),
              const Divider(color: AppColors.glassBorder, height: 24),
            ],
            _QuestionBlock(
              spec: widget.questions[i],
              selected: _selected[i],
              controller: _customCtrls[i],
              onToggle: (opt) => setState(() {
                final spec = widget.questions[i];
                if (spec.multiSelect) {
                  if (_selected[i].contains(opt)) {
                    _selected[i].remove(opt);
                  } else {
                    _selected[i].add(opt);
                  }
                } else {
                  _selected[i] = {opt};
                }
              }),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: GlowButton(
              label: 'Continue',
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  const _QuestionBlock({
    required this.spec,
    required this.selected,
    required this.controller,
    required this.onToggle,
  });

  final QuestionSpec spec;
  final Set<String> selected;
  final TextEditingController controller;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          spec.question,
          style: TextStyle(fontFamily: 'Geist', 
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final opt in spec.options)
              _OptionChip(
                label: opt,
                selected: selected.contains(opt),
                onTap: () => onToggle(opt),
              ),
          ],
        ),
        if (spec.allowCustom) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            style: TextStyle(fontFamily: 'Geist', 
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Or type your own answer…',
              hintStyle: TextStyle(fontFamily: 'Geist', 
                fontSize: 12,
                color: AppColors.textFaint,
              ),
              filled: true,
              fillColor: AppColors.glass2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide:
                    const BorderSide(color: AppColors.secondary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondary.withValues(alpha: 0.18)
              : AppColors.glass2,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected
                ? AppColors.secondary.withValues(alpha: 0.6)
                : AppColors.glassBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(fontFamily: 'Geist', 
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.secondary : AppColors.textSoft,
          ),
        ),
      ),
    );
  }
}
