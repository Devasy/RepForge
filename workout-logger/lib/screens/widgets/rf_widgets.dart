// Shared RepForge UI widgets — soft-futurist design system

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

// ─── GlassCard ───────────────────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Color? gradientStart;
  final Color? gradientEnd;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double? ambientRadius;
  final Color? ambientColor;
  final Alignment ambientAlignment;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.gradientStart,
    this.gradientEnd,
    this.borderColor,
    this.onTap,
    this.ambientRadius,
    this.ambientColor,
    this.ambientAlignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(AppRadius.xl);
    Widget card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradientStart ?? const Color(0x09FFFFFF),
            gradientEnd ?? const Color(0x04FFFFFF),
          ],
        ),
        border: Border.all(color: borderColor ?? AppColors.border),
        borderRadius: br,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (ambientRadius != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: ambientAlignment,
                  child: Container(
                    width: ambientRadius! * 2,
                    height: ambientRadius! * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (ambientColor ?? AppColors.accentSoft).withOpacity(0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          child: card,
        ),
      );
    }

    return card;
  }
}

// ─── AnimatedCounter ─────────────────────────────────────────────────────────

class AnimatedCounter extends StatelessWidget {
  final double value;
  final int decimals;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.decimals = 0,
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = decimals == 0
            ? '${v.round()}$suffix'
            : '${v.toStringAsFixed(decimals)}$suffix';
        return Text(
          text,
          style: style ??
              GoogleFonts.geistMono(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
                letterSpacing: -0.04,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        );
      },
    );
  }
}

// ─── RFSparkline ─────────────────────────────────────────────────────────────

class RFSparkline extends StatelessWidget {
  final List<double> data;
  final double width;
  final double height;
  final Color color;
  final bool fill;

  const RFSparkline({
    super.key,
    required this.data,
    this.width = 56,
    this.height = 20,
    this.color = AppColors.accent,
    this.fill = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparklinePainter(data, color, fill)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool fill;
  _SparklinePainter(this.data, this.color, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce(math.min);
    final max = data.reduce(math.max);
    final range = (max - min).abs() < 0.001 ? 1.0 : max - min;

    final pts = List.generate(data.length, (i) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - ((data[i] - min) / range) * (size.height - 4) - 2;
      return Offset(x, y);
    });

    final linePath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }

    if (fill) {
      final fillPath = Path.from(linePath)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.20), color.withOpacity(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.data != data || old.color != color;
}

// ─── ActivityHeatmap ─────────────────────────────────────────────────────────

class ActivityHeatmap extends StatelessWidget {
  final List<DateTime> workoutDates;
  final int weeks;

  const ActivityHeatmap({
    super.key,
    required this.workoutDates,
    this.weeks = 14,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Count workouts per day
    final counts = <DateTime, int>{};
    for (final d in workoutDates) {
      final day = DateTime(d.year, d.month, d.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: weeks * 10.0 + (weeks - 1) * 3,
          child: Row(
            children: List.generate(7, (col) {
              return Expanded(
                child: Column(
                  children: List.generate(weeks, (row) {
                    final daysBack = (6 - col) + (weeks - 1 - row) * 7;
                    final day = today.subtract(Duration(days: daysBack));
                    final count = counts[day] ?? 0;
                    final opacity = count == 0
                        ? 0.05
                        : (0.2 + count * 0.2).clamp(0.0, 1.0);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: count == 0
                                ? AppColors.surface
                                : AppColors.accent.withOpacity(opacity),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: count >= 2
                                ? [BoxShadow(color: AppColors.accentSoft, blurRadius: 4)]
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Less', style: _legendStyle),
            Row(
              children: List.generate(5, (i) => Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: i == 0
                      ? AppColors.surface
                      : AppColors.accent.withOpacity(0.2 + i * 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
            Text('More', style: _legendStyle),
          ],
        ),
      ],
    );
  }

  static final _legendStyle = GoogleFonts.geist(
    fontSize: 10,
    color: AppColors.fg4,
  );
}

// ─── BodyHeatmap ─────────────────────────────────────────────────────────────
// Stylized SVG-style human body diagram rendered with CustomPainter.

class BodyHeatmap extends StatelessWidget {
  final Map<String, double> muscleIntensity; // muscleId → 0..1

  const BodyHeatmap({super.key, this.muscleIntensity = const {}});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 144,
      child: CustomPaint(
        painter: _BodyPainter(muscleIntensity),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  final Map<String, double> intensity;
  _BodyPainter(this.intensity);

  Paint _bodyPaint() => Paint()
    ..color = AppColors.surface3
    ..style = PaintingStyle.fill;

  Paint _outlinePaint() => Paint()
    ..color = AppColors.border
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7;

  Paint _heatPaint(String muscleId, double defaultOpacity) {
    final v = intensity[muscleId] ?? defaultOpacity;
    final color = AppColors.getMuscleColor(muscleId);
    return Paint()
      ..color = color.withOpacity(v.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 74;
    final sy = size.height / 148;

    void circle(double cx, double cy, double r, Paint paint) {
      canvas.drawCircle(Offset(cx * sx, cy * sy), r * math.min(sx, sy), paint);
    }

    void oval(double cx, double cy, double rx, double ry, Paint paint) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx * sx, cy * sy),
          width: rx * 2 * sx,
          height: ry * 2 * sy,
        ),
        paint,
      );
    }

    void path(List<Offset> pts, Paint paint) {
      if (pts.isEmpty) return;
      final p = Path()..moveTo(pts[0].dx * sx, pts[0].dy * sy);
      for (int i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx * sx, pts[i].dy * sy);
      }
      p.close();
      canvas.drawPath(p, paint);
    }

    // ── Body shape (base) ──
    circle(37, 12, 9, _bodyPaint());
    path([const Offset(22,24),const Offset(52,24),const Offset(54,50),const Offset(52,72),const Offset(22,72),const Offset(20,50)], _bodyPaint());
    path([const Offset(20,28),const Offset(12,32),const Offset(8,60),const Offset(12,70),const Offset(18,50)], _bodyPaint());
    path([const Offset(54,28),const Offset(62,32),const Offset(66,60),const Offset(62,70),const Offset(56,50)], _bodyPaint());
    path([const Offset(24,73),const Offset(34,73),const Offset(33,110),const Offset(30,140),const Offset(23,140),const Offset(22,105)], _bodyPaint());
    path([const Offset(40,73),const Offset(50,73),const Offset(52,105),const Offset(51,140),const Offset(44,140),const Offset(41,110)], _bodyPaint());

    // ── Outlines ──
    circle(37, 12, 9, _outlinePaint());
    path([const Offset(22,24),const Offset(52,24),const Offset(54,50),const Offset(52,72),const Offset(22,72),const Offset(20,50)], _outlinePaint());
    path([const Offset(20,28),const Offset(12,32),const Offset(8,60),const Offset(12,70),const Offset(18,50)], _outlinePaint());
    path([const Offset(54,28),const Offset(62,32),const Offset(66,60),const Offset(62,70),const Offset(56,50)], _outlinePaint());

    // ── Heat overlays ──
    oval(37, 38, 13, 9, _heatPaint('chest', 0.55));
    circle(22, 28, 5, _heatPaint('shoulders', 0.42));
    circle(52, 28, 5, _heatPaint('shoulders', 0.42));
    oval(14, 46, 3.5, 8, _heatPaint('biceps', 0.45));
    oval(60, 46, 3.5, 8, _heatPaint('biceps', 0.45));
    oval(37, 58, 10, 9, _heatPaint('back', 0.30));
    oval(28, 92, 5, 11, _heatPaint('quads', 0.18));
    oval(46, 92, 5, 11, _heatPaint('quads', 0.18));
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.intensity != intensity;
}

// ─── MuscleVolumeBar ─────────────────────────────────────────────────────────

class MuscleVolumeBar extends StatelessWidget {
  final String name;
  final double pct; // 0..1
  final Color color;
  final String? value;

  const MuscleVolumeBar({
    super.key,
    required this.name,
    required this.pct,
    required this.color,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name,
                style: GoogleFonts.geist(
                    fontSize: 11, color: AppColors.fg2)),
            if (value != null)
              Text(value!,
                  style: GoogleFonts.geistMono(
                      fontSize: 11, color: AppColors.fg3,
                      fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 4,
            color: AppColors.surface2,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── RFPillTag ───────────────────────────────────────────────────────────────

class RFPillTag extends StatelessWidget {
  final String label;
  final Color color;
  final String? trailing;
  final bool outlined;

  const RFPillTag({
    super.key,
    required this.label,
    required this.color,
    this.trailing,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.12),
        border: Border.all(color: outlined ? color : color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.geist(
                  fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            Text(trailing!,
                style: GoogleFonts.geistMono(
                    fontSize: 11, color: color.withOpacity(0.6))),
          ],
        ],
      ),
    );
  }
}

// ─── RestTimerRing ───────────────────────────────────────────────────────────

class RestTimerRing extends StatelessWidget {
  final int remaining;
  final int total;
  final double size;

  const RestTimerRing({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (total - remaining) / total : 0.0;
    final mm = (remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (remaining % 60).toString().padLeft(2, '0');

    // Color transitions: green (just started) → violet → amber (running low)
    final Color ringColor;
    if (progress < 0.5) {
      ringColor = Color.lerp(AppColors.success, AppColors.accent, progress * 2)!;
    } else {
      ringColor = Color.lerp(AppColors.accent, AppColors.warn, (progress - 0.5) * 2)!;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress, ringColor),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$mm:$ss',
                style: GoogleFonts.geistMono(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w300,
                  color: AppColors.fg,
                  letterSpacing: -0.04,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'REST',
                style: GoogleFonts.geist(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.fg3,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Track
    canvas.drawCircle(center, radius, Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);

    // Arc
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Glow
    if (progress > 0 && progress < 1) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = color.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── RFSectionHeader ─────────────────────────────────────────────────────────

class RFSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? subtitle;

  const RFSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (subtitle != null) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle!,
                  style: GoogleFonts.geist(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg3,
                    letterSpacing: 0.5,
                  )),
              const SizedBox(height: 2),
              Text(title, style: GoogleFonts.geist(
                fontSize: 26, fontWeight: FontWeight.w600,
                color: AppColors.fg, letterSpacing: -0.04,
              )),
            ],
          ),
        ] else
          Text(title,
              style: GoogleFonts.geist(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.fg)),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: GoogleFonts.geist(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: AppColors.accent)),
          ),
      ],
    );
  }
}

// ─── Segmented progress bar ───────────────────────────────────────────────────

class SegmentedProgressBar extends StatelessWidget {
  final int total;
  final int current; // 0-based current index

  const SegmentedProgressBar({
    super.key,
    required this.total,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isDone = i < current;
        final isCurrent = i == current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 3 : 0),
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isDone
                  ? AppColors.accent
                  : isCurrent
                      ? AppColors.accentSoft
                      : AppColors.surface2,
              boxShadow: isDone || isCurrent
                  ? [BoxShadow(color: AppColors.accentSoft, blurRadius: 4)]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

// ─── PRBadge ─────────────────────────────────────────────────────────────────

class PRBadge extends StatelessWidget {
  const PRBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.15),
        border: Border.all(color: AppColors.success.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        'PR',
        style: GoogleFonts.geist(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.success,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Stat box (for session summary) ──────────────────────────────────────────

class RFStatBox extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final String? sub;

  const RFStatBox({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.color,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.geist(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: AppColors.fg4, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: GoogleFonts.geistMono(
                    fontSize: 24, fontWeight: FontWeight.w600, color: color,
                    letterSpacing: -0.04,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(unit!,
                    style: GoogleFonts.geist(
                        fontSize: 11, color: AppColors.fg4)),
              ],
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: GoogleFonts.geist(fontSize: 11, color: AppColors.fg3)),
          ],
        ],
      ),
    );
  }
}
