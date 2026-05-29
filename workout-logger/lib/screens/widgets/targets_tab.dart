// targets_tab.dart — Analytics "Targets" tab

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/workout_provider.dart';
import '../../services/settings_provider.dart';
import '../../services/ai/gemini_ai_service.dart';
import '../../theme/app_theme.dart';
import '../../data/exercise_database.dart';
import 'rf_widgets.dart';
import 'rf_cards.dart';
import '../ai_coach_screen.dart';

class TargetsTab extends StatelessWidget {
  const TargetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final targets = provider.targets;
    final active = targets.where((t) => !t.isCompleted).toList();
    final completed = targets.where((t) => t.isCompleted).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: targets.isEmpty
          ? RFEmptyState(
              icon: Icons.flag_rounded,
              title: 'No Targets Set',
              subtitle: 'Set a goal to track your progress',
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryHeader(active: active, completed: completed),
                  const SizedBox(height: AppSpacing.md),
                  if (active.isNotEmpty) ...[
                    const RFSectionHeader('Active'),
                    ...active.map(
                      (t) => _TargetCardWithAi(
                        target: t,
                        exerciseName: provider.getExerciseName(t.exerciseId),
                        growthModel: provider.getGrowthModel(t.exerciseId),
                        onDelete: () => provider.deleteTarget(t.id),
                      ),
                    ),
                  ],
                  if (completed.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    const RFSectionHeader('Completed'),
                    ...completed.map(
                      (t) => TargetCard(
                        target: t,
                        exerciseName: provider.getExerciseName(t.exerciseId),
                        onDelete: () => provider.deleteTarget(t.id),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: AppBreakpoints.navBarClearance),
        child: FloatingActionButton.extended(
          onPressed: () => _showCreateSheet(context),
          backgroundColor: AppColors.primary,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'New Target',
            style: GoogleFonts.geist(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _CreateTargetSheet(),
    );
  }
}

// ── Summary header ─────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.active,
    required this.completed,
  });

  final List<Target> active;
  final List<Target> completed;

  @override
  Widget build(BuildContext context) {
    final onTrack = active
        .where((t) =>
            t.estimatedCompletionDate != null &&
            t.estimatedCompletionDate!.isAfter(DateTime.now()))
        .length;
    final stalled = active.length - onTrack;

    return Row(
      children: [
        _SummaryChip(
          label: '${active.length} active',
          color: AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        if (onTrack > 0)
          _SummaryChip(
            label: '$onTrack on track',
            color: AppColors.success,
          ),
        if (stalled > 0) ...[
          const SizedBox(width: AppSpacing.sm),
          _SummaryChip(
            label: '$stalled stalled',
            color: AppColors.warning,
          ),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.sm),
          _SummaryChip(
            label: '${completed.length} done',
            color: AppColors.textMuted,
          ),
        ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.geistMono(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Target card with status word + AI stalled nudge ────────────────────────────

class _TargetCardWithAi extends StatefulWidget {
  const _TargetCardWithAi({
    required this.target,
    required this.exerciseName,
    required this.growthModel,
    this.onDelete,
  });

  final Target target;
  final String exerciseName;
  final GrowthModel? growthModel;
  final VoidCallback? onDelete;

  @override
  State<_TargetCardWithAi> createState() => _TargetCardWithAiState();
}

class _TargetCardWithAiState extends State<_TargetCardWithAi> {
  String? _nudge;
  bool _loadingNudge = false;

  bool get _isStalled {
    final t = widget.target;
    if (t.estimatedCompletionDate == null) return true;
    return t.estimatedCompletionDate!.isBefore(DateTime.now());
  }

  String get _statusWord {
    if (widget.target.isCompleted) return 'Done';
    if (!_isStalled) return 'On track';
    return 'Stalled';
  }

  Color get _statusColor {
    if (widget.target.isCompleted) return AppColors.success;
    if (!_isStalled) return AppColors.success;
    return AppColors.warning;
  }

  Future<void> _fetchNudge() async {
    setState(() => _loadingNudge = true);
    final gemini = context.read<GeminiAiService>();
    final settings = context.read<SettingsProvider>();
    final t = widget.target;

    final contextText =
        'Exercise: ${widget.exerciseName}\n'
        'Target: ${t.targetValue} ${settings.unitLabel} (${t.targetType})\n'
        'Current: ${t.currentValue.toStringAsFixed(1)} ${settings.unitLabel} '
        '(${t.progressPercentage.toStringAsFixed(0)}%)\n'
        'Estimated completion: ${t.estimatedCompletionDate != null ? DateFormat('MMM d, y').format(t.estimatedCompletionDate!) : "unknown — no growth trend"}\n'
        '${widget.growthModel != null ? "Growth slope: ${widget.growthModel!.slope.toStringAsFixed(2)} per session, R² ${(widget.growthModel!.r2 * 100).toStringAsFixed(0)}%" : "No growth model yet."}';

    const system =
        'You are a concise personal trainer. Give 1–2 sentences of actionable advice to help the user get this stalled target back on track. Be specific and encouraging.';

    final nudge = await gemini.generateInsight(system, contextText);
    if (mounted) setState(() { _nudge = nudge; _loadingNudge = false; });
  }

  void _openCoach() {
    final seed =
        'I\'m stuck on my ${widget.target.targetType} target for ${widget.exerciseName}. '
        'Currently at ${widget.target.currentValue.toStringAsFixed(1)}, '
        'aiming for ${widget.target.targetValue}. How do I get unstuck?';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AiCoachScreen(seedPrompt: seed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final gemini = context.watch<GeminiAiService>();
    final t = widget.target;
    final pct = t.progressPercentage.clamp(0.0, 100.0);
    final etaStr = t.estimatedCompletionDate != null
        ? DateFormat('MMM d, y').format(t.estimatedCompletionDate!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
              Expanded(
                child: Text(
                  widget.exerciseName,
                  style: GoogleFonts.geist(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              RFChip(
                label: t.targetType,
                small: true,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                      color: _statusColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _statusWord,
                  style: GoogleFonts.geistMono(
                    color: _statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.onDelete != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${settings.toDisplay(t.currentValue).toStringAsFixed(1)} / '
                '${settings.toDisplay(t.targetValue).toStringAsFixed(1)} ${settings.unitLabel}',
                style: GoogleFonts.geist(
                  color: AppColors.textSoft,
                  fontSize: 12,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: GoogleFonts.geistMono(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RFProgressBar(value: t.progressPercentage / 100),
          if (etaStr != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 11, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Est. $etaStr',
                  style: GoogleFonts.geist(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],

          // AI stalled nudge section
          if (gemini.isConfigured && _isStalled) ...[
            const SizedBox(height: AppSpacing.sm),
            if (_nudge == null && !_loadingNudge)
              Row(
                children: [
                  Expanded(
                    child: OutlineGlowButton(
                      label: 'Why am I stuck?',
                      icon: Icons.auto_awesome_rounded,
                      color: AppColors.warning,
                      fullWidth: true,
                      small: true,
                      onPressed: _fetchNudge,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlineGlowButton(
                    label: 'Ask Coach',
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppColors.secondary,
                    small: true,
                    onPressed: _openCoach,
                  ),
                ],
              )
            else if (_loadingNudge)
              const Center(child: RFLoadingDots())
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 12, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          'AI Tip',
                          style: GoogleFonts.geist(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _nudge!,
                      style: GoogleFonts.geist(
                        color: AppColors.textSoft,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _openCoach,
                      child: Text(
                        'Continue in Coach →',
                        style: GoogleFonts.geist(
                          color: AppColors.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Create target bottom sheet ─────────────────────────────────────────────────

class _CreateTargetSheet extends StatefulWidget {
  const _CreateTargetSheet();

  @override
  State<_CreateTargetSheet> createState() => _CreateTargetSheetState();
}

class _CreateTargetSheetState extends State<_CreateTargetSheet> {
  String? _selectedExerciseId;
  String _targetType = 'weight';
  final _valueController = TextEditingController();
  bool _isSubmitting = false;
  bool _loadingSuggestion = false;
  String? _suggestionText;

  static const _types = [
    ('weight', 'Max Weight'),
    ('reps', 'Max Reps'),
    ('volume', 'Volume'),
  ];

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestion() async {
    if (_selectedExerciseId == null) return;
    setState(() => _loadingSuggestion = true);

    final provider = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();
    final gemini = context.read<GeminiAiService>();
    final exerciseName = provider.getExerciseName(_selectedExerciseId!);
    final growth = provider.getGrowthModel(_selectedExerciseId!);
    final oneRM = provider.getBestOneRM(_selectedExerciseId!);

    String contextText =
        'Exercise: $exerciseName\nTarget type: $_targetType\n';
    if (growth != null) {
      contextText +=
          'Growth slope: ${settings.toDisplay(growth.slope).toStringAsFixed(2)} ${settings.unitLabel}/session\n'
          'R²: ${(growth.r2 * 100).toStringAsFixed(0)}%\n';
    }
    if (oneRM != null) {
      contextText +=
          'Estimated 1RM: ${settings.formatWeight(oneRM)}\n';
    }

    const system =
        'You are a strength coach. Suggest ONE realistic target value and an estimated timeframe (e.g. "100 kg in ~8 weeks based on your current progression"). '
        'Be concise — one sentence max. State only the number and timeframe.';

    final suggestion = await gemini.generateInsight(system, contextText);
    if (mounted) {
      setState(() {
        _suggestionText = suggestion;
        _loadingSuggestion = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ExerciseDatabase.getAll();
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final gemini = context.watch<GeminiAiService>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'New Target',
            style: GoogleFonts.geist(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'EXERCISE',
            style: GoogleFonts.geist(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedExerciseId,
                isExpanded: true,
                dropdownColor: AppColors.cardHigh,
                hint: Text(
                  'Select exercise…',
                  style: GoogleFonts.geist(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                style: GoogleFonts.geist(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                icon: const Icon(Icons.expand_more_rounded,
                    color: AppColors.textMuted, size: 20),
                items: exercises
                    .map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedExerciseId = v;
                  _suggestionText = null;
                }),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          Text(
            'TARGET TYPE',
            style: GoogleFonts.geist(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _types.map((t) {
              final selected = _targetType == t.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _targetType = t.$1;
                    _suggestionText = null;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Text(
                      t.$2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.geist(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.md),
          Text(
            'TARGET VALUE',
            style: GoogleFonts.geist(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: TextField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d*$')),
              ],
              style: GoogleFonts.geist(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 100',
                hintStyle:
                    GoogleFonts.geist(color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),

          // AI suggestion
          if (gemini.isConfigured && _selectedExerciseId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            if (_suggestionText == null && !_loadingSuggestion)
              GestureDetector(
                onTap: _fetchSuggestion,
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'Suggest a target based on my progress',
                      style: GoogleFonts.geist(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_loadingSuggestion)
              const Center(child: RFLoadingDots())
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _suggestionText!,
                        style: GoogleFonts.geist(
                          color: AppColors.textSoft,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: AppSpacing.lg),
          GlowButton(
            label: 'Create Target',
            icon: Icons.flag_rounded,
            onPressed: _isSubmitting ? null : _submit,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selectedExerciseId == null || _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: AppColors.cardHigh,
        ),
      );
      return;
    }
    final value = double.tryParse(_valueController.text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid target value'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<WorkoutProvider>().createTarget(
            exerciseId: _selectedExerciseId!,
            type: _targetType,
            targetValue: value,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
