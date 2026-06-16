// SleepHrCard — compact overnight-HR summary on the dashboard.
//
// Self-hiding: renders SizedBox.shrink() when ReadinessManager has no
// SleepHrSnapshot, so the dashboard needs no conditional logic.

import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/sleep_hr_models.dart';
import '../../services/managers/readiness_manager.dart';
import '../../theme/app_theme.dart';
import '../sleep_detail_screen.dart';
import 'rf_widgets.dart';
import 'sleep_hr_charts.dart' show kSleepStageColors;

class SleepHrCard extends StatelessWidget {
  const SleepHrCard({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ReadinessManager>();
    final snap = manager.sleepHrSnapshot;
    if (snap == null) return const SizedBox.shrink();

    final remAvg = snap.statsFor('rem')?.avgBpm;
    final deepAvg = snap.statsFor('deep')?.avgBpm;

    final startFmt = _fmtTime(_toIst(snap.sleepStart));
    final endFmt = _fmtTime(_toIst(snap.sleepEnd));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        onTap: () => _openSheet(context, snap),
        semanticsLabel: 'Sleep heart rate, P95 ${snap.p95Bpm} bpm',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep heart rate',
                      style: GoogleFonts.geist(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last night · $startFmt – $endFmt',
                      style: GoogleFonts.geist(
                        color: AppColors.textFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textFaint,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Mini-stats row
            Row(
              children: [
                _MiniStat(
                  label: 'P5',
                  value: '${snap.p5Bpm}',
                  unit: 'bpm',
                  color: AppColors.success,
                ),
                _MiniStat(
                  label: 'P95',
                  value: '${snap.p95Bpm}',
                  unit: 'bpm',
                  color: AppColors.primary,
                ),
                if (deepAvg != null)
                  _MiniStat(
                    label: 'Deep avg',
                    value: deepAvg.round().toString(),
                    unit: 'bpm',
                    color: kSleepStageColors['deep']!,
                  ),
                if (remAvg != null)
                  _MiniStat(
                    label: 'REM avg',
                    value: remAvg.round().toString(),
                    unit: 'bpm',
                    color: kSleepStageColors['rem']!,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Sparkline
            SizedBox(
              height: 44,
              child: CustomPaint(
                size: const Size(double.infinity, 44),
                painter: _SparklinePainter(snap.segments),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, SleepHrSnapshot snap) {
    // Land on the night this snapshot represents (handles the watch-not-synced
    // fallback where it's the night before last).
    Navigator.of(context).push(
      slideRoute(SleepDetailScreen(initialDate: snap.sleepEnd)),
    );
  }

  static DateTime _toIst(DateTime dt) =>
      dt.toUtc().add(const Duration(hours: 5, minutes: 30));

  static String _fmtTime(DateTime dt) {
    final h = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.geist(
              color: AppColors.textFaint,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 1),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.geistMono(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.geist(
                    color: AppColors.textFaint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the compact sparkline: coloured low/high bars + moving-average line.
class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.segments);

  final List<SleepHrSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final allBpms = segments.expand((s) => [s.minBpm, s.maxBpm]);
    final bpmMin = allBpms.reduce(min).toDouble() - 4;
    final bpmMax = segments.map((s) => s.maxBpm).reduce((a, b) => a > b ? a : b).toDouble() + 4;

    double yFor(double bpm) =>
        size.height - ((bpm - bpmMin) / (bpmMax - bpmMin)) * size.height;

    final n = segments.length;
    final barW = size.width / n;

    // Draw bars
    for (var i = 0; i < n; i++) {
      final seg = segments[i];
      final color = kSleepStageColors[seg.stage] ?? AppColors.primary;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      final x = i * barW;
      final yTop = yFor(seg.maxBpm.toDouble());
      final yBot = yFor(seg.minBpm.toDouble());
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 0.5, yTop, barW - 1, (yBot - yTop).clamp(2, double.infinity)),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, paint);
    }

    // Moving-average trend line (window = 5)
    final linePaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < n; i++) {
      final start = (i - 4).clamp(0, n - 1);
      final slice = segments.sublist(start, i + 1);
      final ma = slice.map((s) => s.avgBpm).reduce((a, b) => a + b) / slice.length;
      final x = i * barW + barW / 2;
      final y = yFor(ma);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw as solid for the compact sparkline — dashes not worth the complexity at 44dp.
    canvas.drawPath(path, linePaint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.segments != segments;
}
