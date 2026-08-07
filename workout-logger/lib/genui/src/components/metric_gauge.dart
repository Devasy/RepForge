import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../a2ui_node.dart';
import '../a2ui_panels.dart';
import '../a2ui_spec.dart';
import '../a2ui_theme.dart';

@immutable
class MetricGaugeProps {
  const MetricGaugeProps({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.status,
  });

  final String title;

  /// Null when the model supplied nothing parseable — the renderer shows an
  /// empty panel rather than drawing an arc from a bogus number.
  final double? value;
  final double min;
  final double max;
  final String unit;
  final String? status;

  /// Fill fraction in `[0, 1]`. Returns 0 for a degenerate range so a NaN
  /// sweep angle can never reach the canvas.
  double get progress {
    final v = value;
    if (v == null) return 0;
    final span = max - min;
    if (span <= 0) return 0;
    final raw = (v - min) / span;
    if (raw.isNaN || raw.isInfinite) return 0;
    return raw.clamp(0.0, 1.0);
  }
}

/// A radial gauge for a bounded score such as readiness or recovery.
class MetricGaugeSpec extends A2UiSpec<MetricGaugeProps> {
  const MetricGaugeSpec();

  @override
  String get name => 'MetricGauge';

  @override
  List<String> get aliases => const ['Gauge', 'Dial', 'ScoreGauge'];

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema:
            'MetricGauge {title, value: number, min?, max?, unit?, status?}',
        purpose:
            'A bounded score shown as a dial. Use when the number has a natural '
            'floor and ceiling.',
        example: {
          'component': 'MetricGauge',
          'props': {
            'title': 'Readiness',
            'value': 82,
            'min': 0,
            'max': 100,
            'unit': 'pts',
            'status': 'Optimal',
          },
        },
      );

  @override
  MetricGaugeProps parseProps(A2UiNode node) {
    final p = node.props;
    final status = p.textOrNull('status');
    return MetricGaugeProps(
      title: p.text('title', or: 'Metric'),
      value: p.numberOrNull('value'),
      min: p.number('min', or: 0),
      max: p.number('max', or: 100),
      unit: p.text('unit'),
      status: (status == null || status.isEmpty) ? null : status,
    );
  }

  @override
  Widget buildWidget(
    BuildContext context,
    MetricGaugeProps props,
    A2UiTheme theme,
  ) {
    final value = props.value;
    if (value == null) {
      return A2UiEmptyPanel(
        message: '${props.title}: No value available',
        theme: theme,
      );
    }

    final display =
        value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

    return A2UiPanel(
      theme: theme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            props.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing),
          SizedBox(
            height: 120,
            width: 120,
            child: CustomPaint(
              painter: _GaugeArcPainter(
                progress: props.progress,
                track: theme.border,
                from: theme.accent,
                to: theme.seriesColor(1),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      display,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (props.unit.isNotEmpty)
                      Text(
                        props.unit,
                        style: TextStyle(color: theme.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (props.status case final String status) ...[
            SizedBox(height: theme.spacing / 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(theme.pillRadius),
                border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GaugeArcPainter extends CustomPainter {
  const _GaugeArcPainter({
    required this.progress,
    required this.track,
    required this.from,
    required this.to,
  });

  final double progress;
  final Color track;
  final Color from;
  final Color to;

  static const double _startAngle = math.pi * 0.75;
  static const double _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..shader = LinearGradient(colors: [from, to]).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, bg);
    canvas.drawArc(rect, _startAngle, _sweepAngle * progress, false, fg);
  }

  @override
  bool shouldRepaint(_GaugeArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
}
