// HeartRateCard — compact all-day HR summary on the dashboard.
//
// Self-hiding: renders SizedBox.shrink() when ReadinessManager has no
// HrDaySnapshot, mirroring SleepHrCard.

import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/sleep_hr_models.dart';
import '../../services/managers/readiness_manager.dart';
import '../../theme/app_theme.dart';
import '../heart_rate_detail_screen.dart';
import 'rf_widgets.dart';

class HeartRateCard extends StatelessWidget {
  const HeartRateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ReadinessManager>();
    final snap = manager.hrDaySnapshot;
    if (snap == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        borderColor: AppColors.secondary.withValues(alpha: 0.20),
        onTap: () => Navigator.of(context).push(
          slideRoute(const HeartRateDetailScreen()),
        ),
        semanticsLabel: 'Heart rate, resting ${snap.restingBpm ?? '--'} bpm',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded, size: 13, color: AppColors.accent),
                        const SizedBox(width: 5),
                        Text(
                          'Heart rate',
                          style: GoogleFonts.geist(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Today · all-day',
                      style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 11),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniStat(
                  label: 'Resting',
                  value: snap.restingBpm?.toString() ?? '—',
                  unit: 'bpm',
                  color: AppColors.secondary,
                ),
                _MiniStat(label: 'Min', value: '${snap.minBpm}', unit: 'bpm', color: AppColors.textMuted),
                _MiniStat(label: 'Max', value: '${snap.maxBpm}', unit: 'bpm', color: AppColors.accent),
                _MiniStat(label: 'Avg', value: '${snap.avgBpm.round()}', unit: 'bpm', color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: CustomPaint(
                size: const Size(double.infinity, 44),
                painter: _HrSparkline(snap),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['12a', '6a', '12p', '6p', 'now']
                  .map((l) => Text(l, style: GoogleFonts.geistMono(color: AppColors.textFaint, fontSize: 8)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.unit, required this.color});

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
          Text(label, style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 10)),
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
                  style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact all-day HR sparkline: min–max range bars + resting baseline.
class _HrSparkline extends CustomPainter {
  const _HrSparkline(this.snap);

  final HrDaySnapshot snap;

  @override
  void paint(Canvas canvas, Size size) {
    final buckets = snap.buckets;
    if (buckets.isEmpty) return;

    final lo = snap.minBpm.toDouble() - 4;
    final hi = snap.maxBpm.toDouble() + 4;
    double yFor(double v) => size.height - ((v - lo) / (hi - lo)) * size.height;

    final n = buckets.length;
    final barW = size.width / n;

    for (var i = 0; i < n; i++) {
      final b = buckets[i];
      final x = i * barW;
      final yTop = yFor(b.maxBpm.toDouble());
      final yBot = yFor(b.minBpm.toDouble());
      final rect = Rect.fromLTWH(x + 0.5, yTop, max(barW - 1, 1), max(yBot - yTop, 2));
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent, AppColors.secondary],
        ).createShader(rect)
        ..color = Colors.white.withValues(alpha: 0.7);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1)), paint);
    }

    if (snap.restingBpm != null) {
      final ry = yFor(snap.restingBpm!.toDouble());
      final p = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, ry), Offset(min(x + 3, size.width), ry), p);
      }
    }
  }

  @override
  bool shouldRepaint(_HrSparkline old) => old.snap != snap;
}
