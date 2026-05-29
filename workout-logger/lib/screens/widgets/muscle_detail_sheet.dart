// muscle_detail_sheet.dart — Drill-down sheet for a muscle group.
// Shows weekly contributing exercises (volume + growth trend) and an
// on-demand AI insight via GeminiService.generateInsight.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/workout_provider.dart';
import '../../services/settings_provider.dart';
import '../../services/ai/gemini_ai_service.dart';
import '../../services/interfaces/ml_service_interface.dart';
import '../../data/exercise_database.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';
import '../ai_coach_screen.dart';

class MuscleDetailSheet extends StatelessWidget {
  const MuscleDetailSheet({
    super.key,
    required this.muscleId,
    required this.provider,
  });

  final String muscleId;
  final WorkoutProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final recovery = provider.getMuscleRecoveryScores()[muscleId];
    final name = MuscleGroups.names[muscleId] ?? muscleId;
    final color = AppColors.muscle(muscleId);
    final exercises = provider.getMuscleExerciseBreakdown(muscleId);

    Color recoveryColor = AppColors.textFaint;
    String recoveryLabel = '—';
    if (recovery != null) {
      recoveryLabel = '${recovery.recoveryPercent}%';
      if (recovery.recoveryFraction >= 0.90) {
        recoveryColor = AppColors.success;
      } else if (recovery.recoveryFraction >= 0.70) {
        recoveryColor = AppColors.warning;
      } else {
        recoveryColor = AppColors.error;
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row: muscle name + recovery badge
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.geist(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: recoveryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: recoveryColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: recoveryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      recoveryLabel,
                      style: GoogleFonts.geistMono(
                        color: recoveryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (recovery != null) ...[
            const SizedBox(height: 4),
            Text(
              recovery.isRecovered
                  ? 'Ready to train'
                  : recovery.isUnderRecovered
                      ? 'Still fatigued — consider rest'
                      : 'Recovering',
              style: GoogleFonts.geist(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          RFSectionHeader('Contributing this week', bottomPad: false),
          const SizedBox(height: AppSpacing.sm),

          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'No sessions logged for this muscle in the last 7 days.',
                style: GoogleFonts.geist(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            )
          else
            ...exercises.map((ex) {
              final displayVol = settings.toDisplay(ex.volume);
              final volStr = displayVol >= 1000
                  ? '${(displayVol / 1000).toStringAsFixed(1)}k'
                  : displayVol.toStringAsFixed(0);
              final growth = ex.growth;
              Color trendColor = AppColors.textFaint;
              IconData trendIcon = Icons.remove_rounded;
              if (growth != null) {
                if (growth.slope > 2) {
                  trendColor = AppColors.success;
                  trendIcon = Icons.trending_up_rounded;
                } else if (growth.slope > 0) {
                  trendColor = AppColors.secondary;
                  trendIcon = Icons.trending_up_rounded;
                } else if (growth.slope < -2) {
                  trendColor = AppColors.error;
                  trendIcon = Icons.trending_down_rounded;
                } else {
                  trendColor = AppColors.warning;
                  trendIcon = Icons.trending_flat_rounded;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ex.name,
                        style: GoogleFonts.geist(
                          color: AppColors.textSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$volStr ${settings.unitLabel}',
                      style: GoogleFonts.geistMono(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(trendIcon, size: 16, color: trendColor),
                  ],
                ),
              );
            }),

          const SizedBox(height: AppSpacing.md),
          _AiInsightSection(
            muscleId: muscleId,
            muscleName: name,
            provider: provider,
          ),
        ],
      ),
    );
  }
}

// ── AI insight section ─────────────────────────────────────────────────────────

class _AiInsightSection extends StatefulWidget {
  const _AiInsightSection({
    required this.muscleId,
    required this.muscleName,
    required this.provider,
  });

  final String muscleId;
  final String muscleName;
  final WorkoutProvider provider;

  @override
  State<_AiInsightSection> createState() => _AiInsightSectionState();
}

class _AiInsightSectionState extends State<_AiInsightSection> {
  String? _insight;
  bool _loading = false;

  Future<void> _fetchInsight() async {
    setState(() => _loading = true);
    final gemini = context.read<GeminiAiService>();
    final settings = context.read<SettingsProvider>();
    final mlService = context.read<IMLService>();
    final provider = widget.provider;

    final exerciseMap = {for (final e in provider.allExercises) e.id: e};
    final recovery = mlService.computeMuscleRecoveryScores(
      provider.sessions,
      exerciseMap,
    );
    final exercises = provider.getMuscleExerciseBreakdown(widget.muscleId);
    final recoveryScore = recovery[widget.muscleId];

    final contextText = StringBuffer()
      ..writeln('Muscle: ${widget.muscleName}')
      ..writeln(
          'Recovery: ${recoveryScore != null ? "${recoveryScore.recoveryPercent}% (${recoveryScore.isRecovered ? "ready" : recoveryScore.isUnderRecovered ? "fatigued" : "recovering"})" : "no data"}')
      ..writeln('Weekly contributing exercises:');
    for (final ex in exercises) {
      final vol = settings.toDisplay(ex.volume);
      contextText.writeln(
          '  ${ex.name}: ${vol.toStringAsFixed(0)} ${settings.unitLabel}');
    }

    const system =
        'You are an expert personal trainer. Give a specific, actionable 2–3 sentence insight about this muscle group — cover training readiness, volume, and one practical tip. Be concise and direct.';

    final insight =
        await gemini.generateInsight(system, contextText.toString());
    if (mounted) setState(() { _insight = insight; _loading = false; });
  }

  void _openCoach(BuildContext context) {
    final seed =
        'Give me advice on training my ${widget.muscleName}. '
        'What should I focus on in my next session?';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiCoachScreen(seedPrompt: seed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gemini = context.watch<GeminiAiService>();
    if (!gemini.isConfigured) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_insight == null && !_loading) ...[
          Row(
            children: [
              Expanded(
                child: OutlineGlowButton(
                  label: 'Get AI Insight',
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  fullWidth: true,
                  small: true,
                  onPressed: _fetchInsight,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlineGlowButton(
                label: 'Ask Coach',
                icon: Icons.chat_bubble_outline_rounded,
                color: AppColors.secondary,
                small: true,
                onPressed: () => _openCoach(context),
              ),
            ],
          ),
        ] else if (_loading) ...[
          const Center(child: RFLoadingDots()),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      'AI Insight',
                      style: GoogleFonts.geist(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _insight!,
                  style: GoogleFonts.geist(
                    color: AppColors.textSoft,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () => _openCoach(context),
                  child: Text(
                    'Continue in Coach →',
                    style: GoogleFonts.geist(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
