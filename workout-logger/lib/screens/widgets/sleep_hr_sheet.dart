// SleepHrSheet — full overnight-HR detail shown in a bottom sheet.
//
// Sections (top → bottom):
//   1. Handle + title + subtitle (times in IST)
//   2. Key stat chips (P5 / P95 / Deep avg / REM avg)
//   3. Interactive 10-minute bar chart — tap/drag to see segment tooltip
//   4. Stage timeline strip + legend
//   5. "HR range by stage" horizontal distribution chart

import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/sleep_hr_models.dart';
import '../../theme/app_theme.dart';
import 'sleep_hr_card.dart' show kSleepStageColors;

class SleepHrSheet extends StatelessWidget {
  const SleepHrSheet({super.key, required this.snapshot});

  final SleepHrSnapshot snapshot;

  static const _stageOrder = ['awake', 'rem', 'light', 'deep'];
  static const _stageLabels = {
    'awake': 'Awake',
    'rem': 'REM',
    'light': 'Light',
    'deep': 'Deep',
  };

  static DateTime _toIst(DateTime dt) =>
      dt.toUtc().add(const Duration(hours: 5, minutes: 30));

  static String _fmtTime(DateTime dt) {
    final h = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final remAvg  = snapshot.statsFor('rem')?.avgBpm;
    final deepAvg = snapshot.statsFor('deep')?.avgBpm;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // Title
                  Text(
                    'Sleep heart rate',
                    style: GoogleFonts.geist(
                      color: AppColors.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Last night · ${_fmtTime(_toIst(snapshot.sleepStart))} – '
                    '${_fmtTime(_toIst(snapshot.sleepEnd))} IST',
                    style: GoogleFonts.geist(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // Stat pills row
                  Row(
                    children: [
                      _StatPill(label: 'P5',  value: '${snapshot.p5Bpm} bpm',  color: AppColors.success),
                      const SizedBox(width: 6),
                      _StatPill(label: 'P95', value: '${snapshot.p95Bpm} bpm', color: AppColors.primary),
                      if (deepAvg != null) ...[
                        const SizedBox(width: 6),
                        _StatPill(
                          label: 'Deep avg',
                          value: '${deepAvg.round()} bpm',
                          color: kSleepStageColors['deep']!,
                        ),
                      ],
                      if (remAvg != null) ...[
                        const SizedBox(width: 6),
                        _StatPill(
                          label: 'REM avg',
                          value: '${remAvg.round()} bpm',
                          color: kSleepStageColors['rem']!,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Interactive bar chart
                  Text(
                    'Heart rate during sleep · 10-min bars',
                    style: GoogleFonts.geist(
                      color: AppColors.textFaint, fontSize: 11, letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InteractiveBarChart(segments: snapshot.segments),
                  const SizedBox(height: 6),

                  // Stage timeline strip
                  _StageTimelineStrip(segments: snapshot.segments),
                  const SizedBox(height: 8),

                  // Legend
                  _Legend(),
                  const SizedBox(height: 24),

                  // HR range by stage
                  Text(
                    'HR range by stage',
                    style: GoogleFonts.geist(
                      color: AppColors.textFaint, fontSize: 11, letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StageDistributionChart(
                    stats: snapshot.stageStats,
                    stageOrder: _stageOrder,
                    stageLabels: _stageLabels,
                  ),
                  const SizedBox(height: 10),
                  _DistLegend(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat pill ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glass2,
          border: Border.all(color: AppColors.glassBorder),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 9, letterSpacing: 0.5),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.geistMono(color: color, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Interactive bar chart ─────────────────────────────────────────────────────

class _InteractiveBarChart extends StatefulWidget {
  const _InteractiveBarChart({required this.segments});
  final List<SleepHrSegment> segments;

  @override
  State<_InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<_InteractiveBarChart> {
  int? _hoveredIndex;

  static const _chartHeight = 160.0;
  static const _padLeft = 28.0;

  int? _indexAt(Offset local, double width) {
    final chartW = width - _padLeft - 4;
    final x = local.dx - _padLeft;
    if (x < 0 || x > chartW) return null;
    final idx = (x / chartW * widget.segments.length).floor();
    return idx.clamp(0, widget.segments.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _chartHeight,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            onTapDown: (d) => setState(
              () => _hoveredIndex = _indexAt(d.localPosition, width),
            ),
            onTapUp: (_) => setState(() => _hoveredIndex = null),
            onPanUpdate: (d) => setState(
              () => _hoveredIndex = _indexAt(d.localPosition, width),
            ),
            onPanEnd: (_) => setState(() => _hoveredIndex = null),
            onPanCancel: () => setState(() => _hoveredIndex = null),
            child: CustomPaint(
              size: Size(width, _chartHeight),
              painter: _BarChartPainter(
                segments: widget.segments,
                hoveredIndex: _hoveredIndex,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Bar chart CustomPainter ───────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.segments, this.hoveredIndex});

  final List<SleepHrSegment> segments;
  final int? hoveredIndex;

  static const _padLeft   = 28.0;
  static const _padTop    = 6.0;
  static const _padBottom = 22.0;

  static DateTime _toIst(DateTime dt) =>
      dt.toUtc().add(const Duration(hours: 5, minutes: 30));

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final allBpms = segments.expand((s) => [s.minBpm, s.maxBpm]);
    final rawMin  = allBpms.reduce(min).toDouble();
    final rawMax  = segments.map((s) => s.maxBpm).reduce((a, b) => a > b ? a : b).toDouble();
    final bpmMin  = (rawMin / 10).floor() * 10.0 - 5;
    final bpmMax  = (rawMax / 10).ceil()  * 10.0 + 5;

    final chartW = size.width - _padLeft - 4;
    final chartH = size.height - _padTop - _padBottom;
    final n      = segments.length;
    final barW   = chartW / n;

    double yFor(double bpm) =>
        _padTop + chartH - ((bpm - bpmMin) / (bpmMax - bpmMin)) * chartH;

    // Grid lines + Y labels
    final gridPaint = Paint()..color = AppColors.glassBorder..strokeWidth = 0.5;
    final yLabelStyle = GoogleFonts.geistMono(color: AppColors.textFaint, fontSize: 8);

    final gridBpms = <int>[];
    for (var b = (bpmMin ~/ 10) * 10; b <= bpmMax; b += 10) {
      gridBpms.add(b);
    }
    for (final bpm in gridBpms) {
      final y = yFor(bpm.toDouble());
      canvas.drawLine(Offset(_padLeft, y), Offset(size.width - 4, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '$bpm', style: yLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_padLeft - tp.width - 3, y - tp.height / 2));
    }

    // Bars
    for (var i = 0; i < n; i++) {
      final seg   = segments[i];
      final color = kSleepStageColors[seg.stage] ?? AppColors.primary;
      final alpha = (hoveredIndex == null || hoveredIndex == i) ? 0.78 : 0.28;
      final paint = Paint()..color = color.withValues(alpha: alpha)..style = PaintingStyle.fill;
      final x    = _padLeft + i * barW;
      final yTop = yFor(seg.maxBpm.toDouble());
      final yBot = yFor(seg.minBpm.toDouble());
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 0.5, yTop, barW - 1, max(yBot - yTop, 2)),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }

    // Moving-average trend line
    final avgPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final sl = segments.sublist(max(0, i - 4), i + 1);
      final ma = sl.map((s) => s.avgBpm).reduce((a, b) => a + b) / sl.length;
      final x  = _padLeft + i * barW + barW / 2;
      final y  = yFor(ma);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, avgPaint);

    // X-axis time labels every ~6 bars
    final xLabelStyle = GoogleFonts.geistMono(color: AppColors.textFaint, fontSize: 8);
    for (var i = 0; i < n; i += 6) {
      final t   = _toIst(segments[i].windowStart);
      final h   = t.hour == 0 ? 12 : t.hour > 12 ? t.hour - 12 : t.hour;
      final m   = t.minute.toString().padLeft(2, '0');
      final tp  = TextPainter(
        text: TextSpan(text: '$h:$m', style: xLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(_padLeft + i * barW + barW / 2 - tp.width / 2, size.height - _padBottom + 5),
      );
    }

    // Tooltip for hovered bar
    if (hoveredIndex != null) {
      final idx = hoveredIndex!;
      final seg = segments[idx];
      final color = kSleepStageColors[seg.stage] ?? AppColors.primary;
      final barX  = _padLeft + idx * barW;
      final yTop  = yFor(seg.maxBpm.toDouble());
      final yBot  = yFor(seg.minBpm.toDouble());

      // Highlight stroke on selected bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX + 0.5, yTop, barW - 1, max(yBot - yTop, 2)),
          const Radius.circular(1.5),
        ),
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5,
      );

      // Tooltip box
      final t     = _toIst(seg.windowStart);
      final tEnd  = _toIst(seg.windowStart.add(const Duration(minutes: 10)));
      final th    = t.hour == 0 ? 12 : t.hour > 12 ? t.hour - 12 : t.hour;
      final tm    = t.minute.toString().padLeft(2, '0');
      final eh    = tEnd.hour == 0 ? 12 : tEnd.hour > 12 ? tEnd.hour - 12 : tEnd.hour;
      final em    = tEnd.minute.toString().padLeft(2, '0');
      final stageName = const {
        'deep': 'Deep', 'rem': 'REM', 'light': 'Light', 'awake': 'Awake',
      }[seg.stage] ?? seg.stage;

      final lines = ['$th:$tm–$eh:$em IST', '${seg.minBpm}–${seg.maxBpm} bpm', stageName];
      final lineStyle = GoogleFonts.geistMono(color: Colors.white, fontSize: 9.5);
      final painters = lines.map((l) => TextPainter(
        text: TextSpan(text: l, style: lineStyle),
        textDirection: TextDirection.ltr,
      )..layout()).toList();

      const ttPadH = 8.0, ttPadV = 6.0, ttLineH = 14.0;
      final ttW = painters.map((p) => p.width).reduce(max) + ttPadH * 2;
      final ttH = painters.length * ttLineH + ttPadV * 2;

      // Position: above bar, clamped to chart bounds
      var ttX = barX + barW / 2 - ttW / 2;
      ttX = ttX.clamp(_padLeft, size.width - 4 - ttW);
      var ttY = yTop - ttH - 6;
      if (ttY < _padTop) ttY = yBot + 6;

      // Shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(ttX, ttY, ttW, ttH), const Radius.circular(6)),
        Paint()..color = Colors.black.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // Background
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(ttX, ttY, ttW, ttH), const Radius.circular(6)),
        Paint()..color = const Color(0xFF1E1E2E),
      );
      // Border
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(ttX, ttY, ttW, ttH), const Radius.circular(6)),
        Paint()..color = color.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 1,
      );

      // Text lines
      for (var i = 0; i < painters.length; i++) {
        final p = painters[i];
        // stage line gets stage colour
        if (i == 2) {
          final stagePainter = TextPainter(
            text: TextSpan(
              text: stageName,
              style: GoogleFonts.geistMono(color: color, fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          stagePainter.paint(canvas, Offset(ttX + ttPadH, ttY + ttPadV + i * ttLineH));
        } else {
          p.paint(canvas, Offset(ttX + ttPadH, ttY + ttPadV + i * ttLineH));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.segments != segments || old.hoveredIndex != hoveredIndex;
}

// ── Stage timeline strip ──────────────────────────────────────────────────────

class _StageTimelineStrip extends StatelessWidget {
  const _StageTimelineStrip({required this.segments});
  final List<SleepHrSegment> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 5,
      child: Row(
        children: segments.map((s) {
          final color = kSleepStageColors[s.stage] ?? AppColors.primary;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Deep',  kSleepStageColors['deep']!),
      ('REM',   kSleepStageColors['rem']!),
      ('Light', kSleepStageColors['light']!),
      ('Awake', kSleepStageColors['awake']!),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        ...items.map((e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: e.$2, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 4),
                Text(e.$1, style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 10)),
              ],
            )),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14, height: 10,
              child: CustomPaint(painter: _DashLinePainter()),
            ),
            const SizedBox(width: 4),
            Text('Avg trend', style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, y), Offset(min(x + 2.5, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashLinePainter _) => false;
}

// ── Stage distribution chart ──────────────────────────────────────────────────

class _StageDistributionChart extends StatelessWidget {
  const _StageDistributionChart({
    required this.stats,
    required this.stageOrder,
    required this.stageLabels,
  });

  final List<SleepStageStats> stats;
  final List<String> stageOrder;
  final Map<String, String> stageLabels;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return Text(
        'No stage HR data available.',
        style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 12),
      );
    }

    final allMin = stats.map((s) => s.minBpm).reduce(min).toDouble() - 4;
    final allMax = stats.map((s) => s.maxBpm).reduce(max).toDouble() + 4;

    final orderedStats = stageOrder
        .map((k) => stats.where((s) => s.stage == k).firstOrNull)
        .whereType<SleepStageStats>()
        .toList();

    return Column(
      children: [
        ...orderedStats.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DistRow(
                stats: s,
                label: stageLabels[s.stage] ?? s.stage,
                color: kSleepStageColors[s.stage] ?? AppColors.primary,
                bpmMin: allMin,
                bpmMax: allMax,
              ),
            )),
        _DistAxis(bpmMin: allMin, bpmMax: allMax),
      ],
    );
  }
}

class _DistRow extends StatelessWidget {
  const _DistRow({
    required this.stats,
    required this.label,
    required this.color,
    required this.bpmMin,
    required this.bpmMax,
  });

  final SleepStageStats stats;
  final String label;
  final Color color;
  final double bpmMin;
  final double bpmMax;

  @override
  Widget build(BuildContext context) {
    double pct(double bpm) => ((bpm - bpmMin) / (bpmMax - bpmMin)).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: GoogleFonts.geist(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 28,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  children: [
                    Positioned(
                      left: pct(stats.minBpm.toDouble()) * w,
                      width: (pct(stats.maxBpm.toDouble()) - pct(stats.minBpm.toDouble())) * w,
                      top: 7, height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    Positioned(
                      left: pct(stats.p25Bpm.toDouble()) * w,
                      width: (pct(stats.p75Bpm.toDouble()) - pct(stats.p25Bpm.toDouble())) * w,
                      top: 7, height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    Positioned(
                      left: pct(stats.avgBpm) * w - 4,
                      top: 10,
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.card, width: 1.5),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (pct(stats.avgBpm) * w - 16).clamp(0, w - 32),
                      top: 0,
                      child: Text(
                        '${stats.avgBpm.round()} bpm',
                        style: GoogleFonts.geistMono(
                          color: color, fontSize: 8, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DistAxis extends StatelessWidget {
  const _DistAxis({required this.bpmMin, required this.bpmMax});

  final double bpmMin;
  final double bpmMax;

  @override
  Widget build(BuildContext context) {
    final ticks = <int>[];
    for (var b = (bpmMin / 5).ceil() * 5; b <= bpmMax; b += 5) {
      ticks.add(b);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          double pct(double bpm) => ((bpm - bpmMin) / (bpmMax - bpmMin)).clamp(0.0, 1.0);
          return SizedBox(
            height: 16,
            child: Stack(
              children: ticks.map((t) => Positioned(
                    left: (pct(t.toDouble()) * w - 10).clamp(0, w - 20),
                    child: Text(
                      '$t',
                      style: GoogleFonts.geistMono(color: AppColors.textFaint, fontSize: 8),
                    ),
                  )).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ── Distribution legend ───────────────────────────────────────────────────────

class _DistLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _DistLi(
          swatch: Container(
            width: 16, height: 8,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          label: 'Min–max',
        ),
        _DistLi(
          swatch: Container(
            width: 16, height: 8,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          label: 'P25–P75',
        ),
        _DistLi(
          swatch: Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: AppColors.textSoft, shape: BoxShape.circle),
          ),
          label: 'Avg',
        ),
      ],
    );
  }
}

class _DistLi extends StatelessWidget {
  const _DistLi({required this.swatch, required this.label});
  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 10)),
      ],
    );
  }
}
