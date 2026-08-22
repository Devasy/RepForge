// ReadinessCard — daily training-readiness summary on the dashboard.
//
// Self-hiding: renders nothing until ReadinessManager has a scored snapshot,
// so the dashboard needs no conditional logic and users without watch data
// (or with the feature disabled) never see an empty state.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/interfaces/readiness_manager_interface.dart';
import '../../services/managers/readiness_manager.dart';
import '../../theme/app_theme.dart';
import 'rf_widgets.dart';

class ReadinessCard extends StatelessWidget {
  const ReadinessCard({super.key});

  // Per-component color thresholds, aligned with ReadinessCalculator bands.
  static const int _goodScore = 75;
  static const int _okScore = 50;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ReadinessManager>();
    final snapshot = manager.snapshot;
    debugPrint('[ReadinessCard] build: status=${manager.status} score=${snapshot?.score} band=${snapshot?.band}');

    final bool hasScore = manager.status == ReadinessStatus.ready &&
        snapshot != null &&
        snapshot.score != null &&
        snapshot.band != null;

    if (!hasScore) {
      return const SizedBox.shrink();
    }

    final color = _bandColor(snapshot.band!);

    return _buildMainCard(context, snapshot, color);
  }

  Widget _buildMainCard(
    BuildContext context,
    ReadinessSnapshot snapshot,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        glowColor: color,
        onTap: () => _showDetails(context, snapshot),
        semanticsLabel: 'Readiness ${snapshot.score} out of 100',
        child: Row(
          children: [
            _ScoreRing(score: snapshot.score!, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headline(snapshot.band!),
                    style: TextStyle(fontFamily: 'Geist', 
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(snapshot),
                    style: TextStyle(fontFamily: 'Geist', 
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textFaint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  static Color _bandColor(ReadinessBand band) => switch (band) {
        ReadinessBand.high => AppColors.success,
        ReadinessBand.moderate => AppColors.warning,
        ReadinessBand.low => AppColors.error,
      };

  static String _headline(ReadinessBand band) => switch (band) {
        ReadinessBand.high => 'Primed — good day to push',
        ReadinessBand.moderate => 'Train as planned',
        ReadinessBand.low => 'Take it easy today',
      };

  /// One line of evidence from the weakest available component.
  static String _subtitle(ReadinessSnapshot s) {
    final parts = <(int, String)>[
      if (s.sleepScore != null && s.sleepMinutes != null && s.sleepBaselineMinutes != null)
        (
          s.sleepScore!,
          'Sleep ${_fmtSleep(s.sleepMinutes!)} vs ${_fmtSleep(s.sleepBaselineMinutes!.round())} avg'
        ),
      if (s.rhrScore != null && s.restingHr != null && s.rhrBaseline != null)
        (
          s.rhrScore!,
          'Resting HR ${s.restingHr!.round()} vs ${s.rhrBaseline!.round()} avg'
        ),
      if (s.hrvScore != null && s.hrvMs != null && s.hrvBaseline != null)
        (
          s.hrvScore!,
          'HRV ${s.hrvMs!.round()}ms vs ${s.hrvBaseline!.round()}ms avg'
        ),
    ];
    if (parts.isEmpty) return 'Ready to train';
    parts.sort((a, b) => a.$1.compareTo(b.$1));
    return parts.first.$2;
  }

  static String _fmtSleep(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  void _showDetails(BuildContext context, ReadinessSnapshot snapshot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _ReadinessDetailsSheet(snapshot: snapshot),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.glass3,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$score',
            style: TextStyle(fontFamily: 'GeistMono', 
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessDetailsSheet extends StatelessWidget {
  const _ReadinessDetailsSheet({required this.snapshot});

  final ReadinessSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(snapshot.computedAt).format(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Readiness · ${snapshot.score}',
              style: TextStyle(fontFamily: 'Geist', 
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'As of $time, from your watch via Health Connect',
              style: TextStyle(fontFamily: 'Geist', color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            if (snapshot.sleepScore != null)
              _ComponentRow(
                label: 'Sleep',
                value:
                    '${ReadinessCard._fmtSleep(snapshot.sleepMinutes!)} · avg ${ReadinessCard._fmtSleep(snapshot.sleepBaselineMinutes!.round())}',
                score: snapshot.sleepScore!,
              ),
            if (snapshot.rhrScore != null)
              _ComponentRow(
                label: 'Resting heart rate',
                value:
                    '${snapshot.restingHr!.round()} bpm · avg ${snapshot.rhrBaseline!.round()} bpm',
                score: snapshot.rhrScore!,
              ),
            if (snapshot.hrvScore != null)
              _ComponentRow(
                label: 'HRV (RMSSD)',
                value:
                    '${snapshot.hrvMs!.round()} ms · avg ${snapshot.hrvBaseline!.round()} ms',
                score: snapshot.hrvScore!,
              ),
            const SizedBox(height: 14),
            Text(
              'Each factor compares last night and this morning to your own '
              '14-day average — only dips below your normal lower the score. '
              'Accuracy improves after about 5 nights of watch data.',
              style: TextStyle(fontFamily: 'Geist', 
                color: AppColors.textFaint,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    required this.label,
    required this.value,
    required this.score,
  });

  final String label;
  final String value;
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= ReadinessCard._goodScore
        ? AppColors.success
        : score >= ReadinessCard._okScore
            ? AppColors.warning
            : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontFamily: 'Geist', 
                  color: AppColors.textSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(fontFamily: 'GeistMono', 
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 5,
              backgroundColor: AppColors.glass2,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
