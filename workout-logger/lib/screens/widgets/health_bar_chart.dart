// health_bar_chart.dart — aggregated vertical bar chart for the Week / Month /
// Year tabs of the Sleep & Heart-rate detail screens.
//
// Two public widgets share one interactive painter:
//   • SleepBarsChart — stacked sleep-stage duration bars + 8h goal line.
//   • HrRangeChart   — daily/monthly min–max range bars + resting-HR markers.
// Both highlight bars that fall on a logged-workout day.

import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/sleep_hr_models.dart';
import '../../theme/app_theme.dart';
import 'sleep_hr_charts.dart' show kSleepStageColors;

/// Default sleep goal used for the dashed reference line (8h).
const int kSleepGoalMinutes = 480;

// ── Shared bar model ──────────────────────────────────────────────────────────

class _Segment {
  final Color color;
  final double from;
  final double to;
  const _Segment(this.color, this.from, this.to);
}

class _AggBar {
  final String label;
  final List<_Segment> segments; // drawn against the value axis
  final double? marker; // e.g. resting-HR dot
  final bool isWorkout;
  final bool hasData;
  final List<String> tooltip;

  const _AggBar({
    required this.label,
    required this.segments,
    required this.tooltip,
    this.marker,
    this.isWorkout = false,
    this.hasData = true,
  });
}

String _hm(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

// ── Sleep stacked bars ────────────────────────────────────────────────────────

class SleepBarsChart extends StatelessWidget {
  const SleepBarsChart({
    super.key,
    required this.bars,
    required this.workoutDays,
    this.goalMinutes = kSleepGoalMinutes,
    this.height = 180,
  });

  final List<SleepDayBar> bars;
  final Set<String> workoutDays;
  final int goalMinutes;
  final double height;

  @override
  Widget build(BuildContext context) {
    final aggBars = bars.map((b) {
      final light = b.lightMin.toDouble();
      final rem = b.remMin.toDouble();
      final deep = b.deepMin.toDouble();
      // Stack order from baseline up: deep, rem, light.
      final segs = <_Segment>[
        _Segment(kSleepStageColors['deep']!, 0, deep),
        _Segment(kSleepStageColors['rem']!, deep, deep + rem),
        _Segment(kSleepStageColors['light']!, deep + rem, deep + rem + light),
      ];
      return _AggBar(
        label: _labelFor(b.date),
        segments: segs,
        hasData: b.totalMinutes > 0,
        isWorkout: workoutDays.contains(_key(b.date)),
        tooltip: [
          _labelFor(b.date),
          '${_hm(b.totalMinutes)} total',
          'Deep ${_hm(b.deepMin)} · REM ${_hm(b.remMin)}',
          'Light ${_hm(b.lightMin)}',
        ],
      );
    }).toList();

    final maxTotal = bars.fold<int>(0, (m, b) => max(m, b.totalMinutes));
    final axisMax = (max(maxTotal, goalMinutes) / 60).ceil() * 60.0 + 30;

    return _AggBarChart(
      bars: aggBars,
      axisMin: 0,
      axisMax: axisMax,
      gridStep: 120, // every 2h
      axisLabel: (v) => '${v ~/ 60}h',
      goalLine: goalMinutes.toDouble(),
      height: height,
    );
  }

  String _labelFor(DateTime d) =>
      d.day == 1 && _isMonthBar(d) ? _months[d.month - 1] : '${d.day}';

  // Year bars use the first-of-month date; show month initials there.
  bool _isMonthBar(DateTime d) => bars.length == 12;

  static const _months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
}

// ── HR range bars ─────────────────────────────────────────────────────────────

class HrRangeChart extends StatelessWidget {
  const HrRangeChart({
    super.key,
    required this.bars,
    required this.workoutDays,
    this.height = 180,
  });

  final List<HrRangeBar> bars;
  final Set<String> workoutDays;
  final double height;

  @override
  Widget build(BuildContext context) {
    final withData = bars.where((b) => b.maxBpm > 0).toList();
    final dataMin = withData.isEmpty
        ? 40
        : withData.map((b) => b.minBpm).reduce((a, b) => a < b ? a : b);
    final dataMax = withData.isEmpty
        ? 160
        : withData.map((b) => b.maxBpm).reduce((a, b) => a > b ? a : b);
    final axisMin = (dataMin / 10).floor() * 10.0 - 5;
    final axisMax = (dataMax / 10).ceil() * 10.0 + 5;

    final aggBars = bars.map((b) {
      final hasData = b.maxBpm > 0;
      return _AggBar(
        label: b.label,
        hasData: hasData,
        isWorkout: workoutDays.contains(_key(b.date)),
        marker: b.restingBpm?.toDouble(),
        segments: hasData
            ? [_Segment(AppColors.primary, b.minBpm.toDouble(), b.maxBpm.toDouble())]
            : const [],
        tooltip: hasData
            ? [
                b.label,
                '${b.minBpm}–${b.maxBpm} bpm',
                if (b.restingBpm != null) 'resting ${b.restingBpm}',
              ]
            : [b.label, 'no data'],
      );
    }).toList();

    return _AggBarChart(
      bars: aggBars,
      axisMin: axisMin,
      axisMax: axisMax,
      gridStep: 30,
      axisLabel: (v) => '${v.round()}',
      rangeGradient: true,
      height: height,
    );
  }
}

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── All-day HR (Day tab) ──────────────────────────────────────────────────────

/// ~30-minute min–max HR bars across one day, with a dashed resting line.
class HrDayChart extends StatefulWidget {
  const HrDayChart({super.key, required this.snapshot, this.height = 180});

  final HrDaySnapshot snapshot;
  final double height;

  @override
  State<HrDayChart> createState() => _HrDayChartState();
}

class _HrDayChartState extends State<HrDayChart> {
  int? _hovered;
  static const _padLeft = 26.0;

  int? _indexAt(Offset local, double width) {
    final buckets = widget.snapshot.buckets;
    final chartW = width - _padLeft - 4;
    final x = local.dx - _padLeft;
    if (x < 0 || x > chartW || buckets.isEmpty) return null;
    return (x / chartW * buckets.length).floor().clamp(0, buckets.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            onTapDown: (d) => setState(() => _hovered = _indexAt(d.localPosition, width)),
            onTapUp: (_) => setState(() => _hovered = null),
            onPanUpdate: (d) => setState(() => _hovered = _indexAt(d.localPosition, width)),
            onPanEnd: (_) => setState(() => _hovered = null),
            onPanCancel: () => setState(() => _hovered = null),
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _HrDayPainter(widget.snapshot, _hovered),
            ),
          );
        },
      ),
    );
  }
}

class _HrDayPainter extends CustomPainter {
  _HrDayPainter(this.snap, this.hovered);
  final HrDaySnapshot snap;
  final int? hovered;

  static const _padLeft = 26.0;
  static const _padTop = 8.0;
  static const _padBottom = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final buckets = snap.buckets;
    if (buckets.isEmpty) return;

    final axisMin = (snap.minBpm / 10).floor() * 10.0 - 5;
    final axisMax = (snap.maxBpm / 10).ceil() * 10.0 + 5;
    final chartW = size.width - _padLeft - 4;
    final chartH = size.height - _padTop - _padBottom;

    double yFor(double v) =>
        _padTop + chartH - ((v - axisMin) / (axisMax - axisMin)) * chartH;

    final gridPaint = Paint()
      ..color = AppColors.glassBorder
      ..strokeWidth = 0.5;
    final yStyle = GoogleFonts.geistMono(color: AppColors.textFaint, fontSize: 8);
    for (var v = (axisMin / 30).ceil() * 30.0; v <= axisMax; v += 30) {
      final y = yFor(v);
      canvas.drawLine(Offset(_padLeft, y), Offset(size.width - 4, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${v.round()}', style: yStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_padLeft - tp.width - 3, y - tp.height / 2));
    }

    final slotW = chartW / buckets.length;
    final barW = (slotW - 1).clamp(1.4, slotW);

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final x = _padLeft + i * slotW;
      final dim = hovered != null && hovered != i;
      final rect = Rect.fromLTWH(x + 0.5, yFor(b.maxBpm.toDouble()), barW,
          max(yFor(b.minBpm.toDouble()) - yFor(b.maxBpm.toDouble()), 2));
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent, AppColors.secondary],
        ).createShader(rect)
        ..color = Colors.white.withValues(alpha: dim ? 0.3 : 0.8);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1.5)), paint);
    }

    // Resting line.
    if (snap.restingBpm != null) {
      final ry = yFor(snap.restingBpm!.toDouble());
      final p = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      for (var x = _padLeft; x < size.width - 4; x += 8) {
        canvas.drawLine(Offset(x, ry), Offset(x + 5, ry), p);
      }
    }

    // X-axis time labels (12a / 6a / 12p / 6p / 11p).
    final labelStyle = GoogleFonts.geistMono(color: AppColors.textFaint, fontSize: 8);
    const marks = ['12a', '6a', '12p', '6p', '11p'];
    for (var i = 0; i < marks.length; i++) {
      final x = _padLeft + (i / (marks.length - 1)) * chartW;
      final tp = TextPainter(
        text: TextSpan(text: marks[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((x - tp.width / 2).clamp(0, size.width - tp.width), size.height - _padBottom + 5));
    }

    // Tooltip.
    if (hovered != null) {
      final b = buckets[hovered!];
      final t = b.windowStart.toUtc().add(const Duration(hours: 5, minutes: 30));
      final h12 = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
      final mm = t.minute.toString().padLeft(2, '0');
      final ap = t.hour < 12 ? 'AM' : 'PM';
      final lines = ['$h12:$mm $ap', '${b.minBpm}–${b.maxBpm} bpm', 'avg ${b.avgBpm.round()}'];
      final lineStyle = GoogleFonts.geistMono(color: Colors.white, fontSize: 9.5);
      final painters = lines
          .map((l) => TextPainter(text: TextSpan(text: l, style: lineStyle), textDirection: TextDirection.ltr)..layout())
          .toList();
      const padH = 8.0, padV = 6.0, lineH = 14.0;
      final ttW = painters.map((p) => p.width).reduce(max) + padH * 2;
      final ttH = painters.length * lineH + padV * 2;
      final cx = _padLeft + hovered! * slotW + slotW / 2;
      final ttX = (cx - ttW / 2).clamp(_padLeft, size.width - 4 - ttW);
      const ttY = _padTop + 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(ttX, ttY, ttW, ttH), const Radius.circular(6)),
        Paint()..color = const Color(0xFF1E1E2E),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(ttX, ttY, ttW, ttH), const Radius.circular(6)),
        Paint()
          ..color = AppColors.secondary.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      for (var i = 0; i < painters.length; i++) {
        painters[i].paint(canvas, Offset(ttX + padH, ttY + padV + i * lineH));
      }
    }
  }

  @override
  bool shouldRepaint(_HrDayPainter old) => old.snap != snap || old.hovered != hovered;
}

// ── Interactive chart shell + painter ─────────────────────────────────────────

class _AggBarChart extends StatefulWidget {
  const _AggBarChart({
    required this.bars,
    required this.axisMin,
    required this.axisMax,
    required this.gridStep,
    required this.axisLabel,
    required this.height,
    this.goalLine,
    this.rangeGradient = false,
  });

  final List<_AggBar> bars;
  final double axisMin;
  final double axisMax;
  final double gridStep;
  final String Function(double) axisLabel;
  final double? goalLine;
  final bool rangeGradient;
  final double height;

  @override
  State<_AggBarChart> createState() => _AggBarChartState();
}

class _AggBarChartState extends State<_AggBarChart> {
  int? _hovered;

  static const _padLeft = 26.0;

  int? _indexAt(Offset local, double width) {
    final chartW = width - _padLeft - 4;
    final x = local.dx - _padLeft;
    if (x < 0 || x > chartW || widget.bars.isEmpty) return null;
    final idx = (x / chartW * widget.bars.length).floor();
    return idx.clamp(0, widget.bars.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bars.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No data for this range.',
            style: GoogleFonts.geist(color: AppColors.textFaint, fontSize: 12),
          ),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            onTapDown: (d) => setState(() => _hovered = _indexAt(d.localPosition, width)),
            onTapUp: (_) => setState(() => _hovered = null),
            onPanUpdate: (d) => setState(() => _hovered = _indexAt(d.localPosition, width)),
            onPanEnd: (_) => setState(() => _hovered = null),
            onPanCancel: () => setState(() => _hovered = null),
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _AggPainter(
                bars: widget.bars,
                axisMin: widget.axisMin,
                axisMax: widget.axisMax,
                gridStep: widget.gridStep,
                axisLabel: widget.axisLabel,
                goalLine: widget.goalLine,
                rangeGradient: widget.rangeGradient,
                hovered: _hovered,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AggPainter extends CustomPainter {
  _AggPainter({
    required this.bars,
    required this.axisMin,
    required this.axisMax,
    required this.gridStep,
    required this.axisLabel,
    required this.goalLine,
    required this.rangeGradient,
    required this.hovered,
  });

  final List<_AggBar> bars;
  final double axisMin;
  final double axisMax;
  final double gridStep;
  final String Function(double) axisLabel;
  final double? goalLine;
  final bool rangeGradient;
  final int? hovered;

  static const _padLeft = 26.0;
  static const _padTop = 8.0;
  static const _padBottom = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _padLeft - 4;
    final chartH = size.height - _padTop - _padBottom;
    final n = bars.length;
    final slotW = chartW / n;
    final gap = (slotW * 0.32).clamp(2.0, 7.0);
    final barW = slotW - gap;

    double yFor(double v) =>
        _padTop + chartH - ((v - axisMin) / (axisMax - axisMin)) * chartH;

    // Grid + Y labels.
    final gridPaint = Paint()
      ..color = AppColors.glassBorder
      ..strokeWidth = 0.5;
    final yStyle = GoogleFonts.geistMono(color: AppColors.textFaint, fontSize: 8);
    for (var v = (axisMin / gridStep).ceil() * gridStep; v <= axisMax; v += gridStep) {
      final y = yFor(v);
      canvas.drawLine(Offset(_padLeft, y), Offset(size.width - 4, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: axisLabel(v), style: yStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_padLeft - tp.width - 3, y - tp.height / 2));
    }

    // Goal line (sleep).
    if (goalLine != null && goalLine! >= axisMin && goalLine! <= axisMax) {
      final gy = yFor(goalLine!);
      final p = Paint()
        ..color = kSleepStageColors['awake']!.withValues(alpha: 0.8)
        ..strokeWidth = 1;
      for (var x = _padLeft; x < size.width - 4; x += 7) {
        canvas.drawLine(Offset(x, gy), Offset(x + 4, gy), p);
      }
    }

    final baselineY = yFor(axisMin);
    final labelStyle = GoogleFonts.geistMono(color: AppColors.textFaint, fontSize: 8);
    final labelEvery = n > 16 ? 5 : (n > 10 ? 2 : 1);

    for (var i = 0; i < n; i++) {
      final bar = bars[i];
      final x = _padLeft + i * slotW + gap / 2;
      final dim = hovered != null && hovered != i;

      if (bar.hasData) {
        for (final seg in bar.segments) {
          final yTop = yFor(seg.to);
          final yBot = yFor(seg.from);
          final paint = Paint()..style = PaintingStyle.fill;
          if (rangeGradient) {
            paint.shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.accent, AppColors.secondary],
            ).createShader(Rect.fromLTWH(x, yTop, barW, max(yBot - yTop, 2)));
            paint.color = Colors.white.withValues(alpha: dim ? 0.3 : 0.85);
          } else {
            paint.color = seg.color.withValues(alpha: dim ? 0.3 : 0.88);
          }
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, yTop, barW, max(yBot - yTop, 2)),
              const Radius.circular(2),
            ),
            paint,
          );
        }

        // Resting marker dot.
        if (bar.marker != null) {
          final my = yFor(bar.marker!);
          canvas.drawCircle(
            Offset(x + barW / 2, my),
            2.6,
            Paint()..color = AppColors.secondary.withValues(alpha: dim ? 0.4 : 1),
          );
          canvas.drawCircle(
            Offset(x + barW / 2, my),
            2.6,
            Paint()
              ..color = AppColors.background
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
      }

      // Workout-day highlight underline.
      if (bar.isWorkout) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 1, baselineY + 2, barW + 2, 2.5),
            const Radius.circular(1),
          ),
          Paint()..color = AppColors.accent.withValues(alpha: 0.9),
        );
      }

      // X label (subset).
      if (i % labelEvery == 0) {
        final tp = TextPainter(
          text: TextSpan(text: bar.label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(x + barW / 2 - tp.width / 2, size.height - _padBottom + 5),
        );
      }
    }

    // Tooltip.
    if (hovered != null) {
      _paintTooltip(canvas, size, hovered!, slotW, yFor);
    }
  }

  void _paintTooltip(Canvas canvas, Size size, int idx, double slotW, double Function(double) yFor) {
    final bar = bars[idx];
    final lineStyle = GoogleFonts.geistMono(color: Colors.white, fontSize: 9.5);
    final painters = bar.tooltip
        .map((l) => TextPainter(
              text: TextSpan(text: l, style: lineStyle),
              textDirection: TextDirection.ltr,
            )..layout())
        .toList();

    const padH = 8.0, padV = 6.0, lineH = 14.0;
    final ttW = painters.map((p) => p.width).reduce(max) + padH * 2;
    final ttH = painters.length * lineH + padV * 2;

    final barCx = _padLeft + idx * slotW + slotW / 2;
    var ttX = (barCx - ttW / 2).clamp(_padLeft, size.width - 4 - ttW);
    var ttY = _padTop + 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ttX, ttY, ttW, ttH), const Radius.circular(6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ttX, ttY, ttW, ttH), const Radius.circular(6)),
      Paint()..color = const Color(0xFF1E1E2E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ttX, ttY, ttW, ttH), const Radius.circular(6)),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var i = 0; i < painters.length; i++) {
      painters[i].paint(canvas, Offset(ttX + padH, ttY + padV + i * lineH));
    }
  }

  @override
  bool shouldRepaint(_AggPainter old) => old.bars != bars || old.hovered != hovered;
}
