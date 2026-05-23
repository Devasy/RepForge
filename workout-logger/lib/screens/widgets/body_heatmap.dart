import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Stylised human body silhouette with muscle heat overlays.
/// [muscleVolumes] maps muscle group id → relative volume 0–1.
class BodyHeatmapWidget extends StatelessWidget {
  const BodyHeatmapWidget({
    super.key,
    this.muscleVolumes = const {},
    this.width = 74,
    this.height = 148,
  });

  final Map<String, double> muscleVolumes;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _BodyPainter(muscleVolumes: muscleVolumes),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter({required this.muscleVolumes});
  final Map<String, double> muscleVolumes;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 74;
    final sy = size.height / 148;

    final baseFill = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..style = PaintingStyle.fill;
    final baseStroke = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    // ── Body outline shapes ──────────────────────────────────────
    // Head
    canvas.drawCircle(Offset(37 * sx, 12 * sy), 9 * sx, baseFill);
    canvas.drawCircle(Offset(37 * sx, 12 * sy), 9 * sx, baseStroke);

    // Torso
    final torso = Path()
      ..moveTo(22 * sx, 24 * sy)
      ..lineTo(52 * sx, 24 * sy)
      ..lineTo(54 * sx, 50 * sy)
      ..lineTo(52 * sx, 72 * sy)
      ..lineTo(22 * sx, 72 * sy)
      ..lineTo(20 * sx, 50 * sy)
      ..close();
    canvas.drawPath(torso, baseFill);
    canvas.drawPath(torso, baseStroke);

    // Left arm
    final leftArm = Path()
      ..moveTo(20 * sx, 28 * sy)
      ..lineTo(12 * sx, 32 * sy)
      ..lineTo(8 * sx, 60 * sy)
      ..lineTo(12 * sx, 70 * sy)
      ..lineTo(18 * sx, 50 * sy)
      ..close();
    canvas.drawPath(leftArm, baseFill);
    canvas.drawPath(leftArm, baseStroke);

    // Right arm
    final rightArm = Path()
      ..moveTo(54 * sx, 28 * sy)
      ..lineTo(62 * sx, 32 * sy)
      ..lineTo(66 * sx, 60 * sy)
      ..lineTo(62 * sx, 70 * sy)
      ..lineTo(56 * sx, 50 * sy)
      ..close();
    canvas.drawPath(rightArm, baseFill);
    canvas.drawPath(rightArm, baseStroke);

    // Left leg
    final leftLeg = Path()
      ..moveTo(24 * sx, 73 * sy)
      ..lineTo(34 * sx, 73 * sy)
      ..lineTo(33 * sx, 110 * sy)
      ..lineTo(30 * sx, 140 * sy)
      ..lineTo(23 * sx, 140 * sy)
      ..lineTo(22 * sx, 105 * sy)
      ..close();
    canvas.drawPath(leftLeg, baseFill);
    canvas.drawPath(leftLeg, baseStroke);

    // Right leg
    final rightLeg = Path()
      ..moveTo(40 * sx, 73 * sy)
      ..lineTo(50 * sx, 73 * sy)
      ..lineTo(52 * sx, 105 * sy)
      ..lineTo(51 * sx, 140 * sy)
      ..lineTo(44 * sx, 140 * sy)
      ..lineTo(41 * sx, 110 * sy)
      ..close();
    canvas.drawPath(rightLeg, baseFill);
    canvas.drawPath(rightLeg, baseStroke);

    // ── Heat overlays ────────────────────────────────────────────
    _drawHeat(canvas: canvas, sx: sx, sy: sy, muscle: 'chest',
        path: _ellipse(cx: 37, cy: 38, rx: 13, ry: 9, sx: sx, sy: sy), color: AppColors.primary, baseOpacity: 0.55);
    _drawHeat(canvas: canvas, sx: sx, sy: sy, muscle: 'shoulders',
        path: _circle(cx: 22, cy: 28, r: 5, sx: sx, sy: sy), color: AppColors.primary, baseOpacity: 0.42);
    _drawHeat(canvas: canvas, sx: sx, sy: sy, muscle: 'shoulders',
        path: _circle(cx: 52, cy: 28, r: 5, sx: sx, sy: sy), color: AppColors.primary, baseOpacity: 0.42);
    _drawHeat(canvas: canvas, sx: sx, sy: sy, muscle: 'biceps',
        path: _ellipse(cx: 14, cy: 46, rx: 3.5, ry: 8, sx: sx, sy: sy), color: AppColors.secondary, baseOpacity: 0.45);
    _drawHeat(canvas: canvas, sx: sx, sy: sy, muscle: 'biceps',
        path: _ellipse(cx: 60, cy: 46, rx: 3.5, ry: 8, sx: sx, sy: sy), color: AppColors.secondary, baseOpacity: 0.45);
    _drawHeat(canvas: canvas, sx: sx, sy: sy, muscle: 'quads',
        path: _ellipse(cx: 28, cy: 92, rx: 5, ry: 11, sx: sx, sy: sy), color: AppColors.warning, baseOpacity: 0.18);
    _drawHeat(canvas: canvas, sx: sx, sy: sy, muscle: 'quads',
        path: _ellipse(cx: 46, cy: 92, rx: 5, ry: 11, sx: sx, sy: sy), color: AppColors.warning, baseOpacity: 0.18);
  }

  void _drawHeat({
    required Canvas canvas,
    required double sx,
    required double sy,
    required String muscle,
    required Path path,
    required Color color,
    required double baseOpacity,
  }) {
    final vol = muscleVolumes[muscle] ?? 0.0;
    final opacity = (baseOpacity * vol).clamp(0.0, 1.0);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: opacity));
  }

  Path _ellipse({
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required double sx,
    required double sy,
  }) {
    return Path()
      ..addOval(Rect.fromCenter(
        center: Offset(cx * sx, cy * sy),
        width: rx * 2 * sx,
        height: ry * 2 * sy,
      ));
  }

  Path _circle({required double cx, required double cy, required double r, required double sx, required double sy}) =>
      _ellipse(cx: cx, cy: cy, rx: r, ry: r, sx: sx, sy: sy);

  @override
  bool shouldRepaint(_BodyPainter old) =>
      !mapEquals(old.muscleVolumes, muscleVolumes);
}
