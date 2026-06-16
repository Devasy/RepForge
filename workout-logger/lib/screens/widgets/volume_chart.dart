import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class VolumeChart extends StatelessWidget {
  const VolumeChart({
    super.key,
    required this.data,
    this.color,
    this.height = 130,
    this.labels = const [],
  });

  final List<double> data;
  final Color? color;
  final double height;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _VolumeCurvePainter(data: data, color: c),
          ),
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map((l) => Text(
                      l,
                      style: TextStyle(fontFamily: 'GeistMono', 
                        fontSize: 9,
                        color: AppColors.textFaint,
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _VolumeCurvePainter extends CustomPainter {
  const _VolumeCurvePainter({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;
    final w = size.width;
    final h = size.height;

    final pts = List.generate(data.length, (i) {
      final x = i / (data.length - 1) * w;
      final y = h - ((data[i] - minVal) / range) * (h - 16) - 8;
      return Offset(x, y);
    });

    // Build smooth bezier path
    final smooth = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1];
      final p1 = pts[i];
      final cx = (p0.dx + p1.dx) / 2;
      smooth.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // Filled area
    final area = Path()..addPath(smooth, Offset.zero);
    area.lineTo(w, h);
    area.lineTo(0, h);
    area.close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.4),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Gridlines
    for (int i = 0; i < 4; i++) {
      final y = h * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..color = const Color(0x0AFFFFFF)
          ..strokeWidth = 1,
      );
    }

    // Line stroke
    canvas.drawPath(
      smooth,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Data point dots
    for (int i = 0; i < pts.length; i++) {
      final isLast = i == pts.length - 1;
      canvas.drawCircle(
        pts[i],
        isLast ? 4 : 2.5,
        Paint()..color = isLast ? Colors.white : color,
      );
      if (isLast) {
        canvas.drawCircle(
          pts[i],
          4,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_VolumeCurvePainter old) =>
      old.data != data || old.color != color;
}
