// ai_program_generator_screen.dart — Natural-language training program generation via Gemini

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/gemini_service.dart';
import '../services/workout_provider.dart';
import '../services/managers/program_manager.dart';
import '../theme/app_theme.dart';
import 'widgets/rf_widgets.dart';

class AiProgramGeneratorScreen extends StatefulWidget {
  const AiProgramGeneratorScreen({super.key});

  @override
  State<AiProgramGeneratorScreen> createState() =>
      _AiProgramGeneratorScreenState();
}

class _AiProgramGeneratorScreenState extends State<AiProgramGeneratorScreen> {
  final _promptCtrl = TextEditingController();
  bool _generating = false;
  String _statusText = '';
  TrainingProgram? _preview;
  String? _error;

  // Prompt suggestions
  static const _suggestions = [
    '12-week hypertrophy, 4 days/week, push-pull-legs-upper',
    '8-week strength focus, 3 days/week, full body',
    '6-week cut program, 5 days/week, high volume',
    '16-week powerlifting peaking, 4 days/week',
  ];

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _generating = true;
      _preview = null;
      _error = null;
      _statusText = 'Designing your program…';
    });

    try {
      final gemini = context.read<GeminiService>();
      final wp = context.read<WorkoutProvider>();

      setState(() => _statusText = 'Building workout structure…');
      final program = await gemini.generateProgram(
        userPrompt: prompt,
        allExercises: wp.allExercises,
      );

      if (mounted) {
        setState(() {
          _preview = program;
          _generating = false;
          _statusText = '';
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _generating = false;
          _statusText = '';
        });
      }
    }
  }

  Future<void> _saveProgram() async {
    if (_preview == null) return;
    HapticFeedback.mediumImpact();
    final manager = context.read<ProgramManager>();
    await manager.saveProgram(_preview!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AmbientGlow(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPromptCard(),
                        const SizedBox(height: AppSpacing.lg),
                        if (_generating) _buildGeneratingState(),
                        if (_error != null) _buildError(),
                        if (_preview != null) _buildPreview(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.glass3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSoft,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow(0.4),
                  blurRadius: 12,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Program Generator',
                  style: GoogleFonts.geist(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Powered by Gemini',
                  style: GoogleFonts.geist(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Describe your program',
                style: GoogleFonts.geist(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.glassBorderStrong),
            ),
            child: TextField(
              controller: _promptCtrl,
              style: GoogleFonts.geist(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText:
                    'e.g. "12-week hypertrophy program, 4 days/week, push-pull split, intermediate level"',
                hintStyle: GoogleFonts.geist(
                  color: AppColors.textFaint,
                  fontSize: 13,
                  height: 1.5,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'QUICK PROMPTS',
            style: GoogleFonts.geistMono(
              color: AppColors.textFaint,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _suggestions.map((s) {
              return GestureDetector(
                onTap: () => setState(() => _promptCtrl.text = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.glass,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.geist(
                      color: AppColors.textSoft,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlowButton(
            label: _generating ? 'Generating…' : 'Generate Program',
            icon: Icons.auto_awesome_rounded,
            onPressed: _generating ? null : _generate,
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingState() {
    return GlassCard(
      glowColor: AppColors.primary,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _statusText,
            style: GoogleFonts.geist(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Gemini is designing your training block…',
            style: GoogleFonts.geist(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildError() {
    return GlassCard(
      borderColor: AppColors.error.withValues(alpha: 0.4),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.geist(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final p = _preview!;
    final deloads = p.weeks.where((w) => w.isDeload).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RFSectionHeader('Generated Program'),
        GlassCard(
          glowColor: AppColors.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: GoogleFonts.geist(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (p.description != null)
                          Text(
                            p.description!,
                            style: GoogleFonts.geist(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  RFChip(label: '${p.totalWeeks} weeks', color: AppColors.primary),
                  RFChip(label: '${p.phases.length} phases', color: AppColors.secondary),
                  RFChip(
                    label: '${p.weeks.fold(0, (s, w) => s + w.days.length)} training days',
                    color: AppColors.textSoft,
                  ),
                  if (deloads > 0)
                    RFChip(label: '$deloads deload', color: AppColors.warning),
                ],
              ),
              if (p.phases.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.glassBorder, height: 1),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'PHASES',
                  style: GoogleFonts.geistMono(
                    color: AppColors.textFaint,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...p.phases.map(
                  (phase) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          phase.name,
                          style: GoogleFonts.geist(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Wk ${phase.startWeek}–${phase.endWeek}',
                          style: GoogleFonts.geistMono(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlowButton(
          label: 'Add to My Programs',
          icon: Icons.add_rounded,
          onPressed: _saveProgram,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlineGlowButton(
          label: 'Regenerate',
          icon: Icons.refresh_rounded,
          onPressed: _generate,
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
