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
    _drawHeat(canvas, sx, sy, 'chest',
        _ellipse(37, 38, 13, 9, sx, sy), AppColors.primary, 0.55);
    _drawHeat(canvas, sx, sy, 'shoulders',
        _circle(22, 28, 5, sx, sy), AppColors.primary, 0.42);
    _drawHeat(canvas, sx, sy, 'shoulders',
        _circle(52, 28, 5, sx, sy), AppColors.primary, 0.42);
    _drawHeat(canvas, sx, sy, 'biceps',
        _ellipse(14, 46, 3.5, 8, sx, sy), AppColors.secondary, 0.45);
    _drawHeat(canvas, sx, sy, 'biceps',
        _ellipse(60, 46, 3.5, 8, sx, sy), AppColors.secondary, 0.45);
    _drawHeat(canvas, sx, sy, 'quads',
        _ellipse(28, 92, 5, 11, sx, sy), AppColors.warning, 0.18);
    _drawHeat(canvas, sx, sy, 'quads',
        _ellipse(46, 92, 5, 11, sx, sy), AppColors.warning, 0.18);
  }

  void _drawHeat(Canvas canvas, double sx, double sy, String muscle,
      Path path, Color color, double baseOpacity) {
    final vol = muscleVolumes[muscle] ?? 0.5;
    final opacity = (baseOpacity * (0.5 + vol * 0.5)).clamp(0.0, 1.0);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: opacity));
  }

  Path _ellipse(double cx, double cy, double rx, double ry, double sx,
      double sy) {
    return Path()
      ..addOval(Rect.fromCenter(
        center: Offset(cx * sx, cy * sy),
        width: rx * 2 * sx,
        height: ry * 2 * sy,
      ));
  }

  Path _circle(double cx, double cy, double r, double sx, double sy) =>
      _ellipse(cx, cy, r, r, sx, sy);

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.muscleVolumes != muscleVolumes;
}
