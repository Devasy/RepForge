import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../a2ui_node.dart';
import '../a2ui_panels.dart';
import '../a2ui_spec.dart';
import '../a2ui_theme.dart';

@immutable
class A2UiPoint {
  const A2UiPoint(this.x, this.y);
  final double x;
  final double y;
}

@immutable
class ScatterPlotProps {
  const ScatterPlotProps({
    required this.title,
    required this.xLabel,
    required this.yLabel,
    required this.points,
    this.correlation,
  });

  final String title;
  final String xLabel;
  final String yLabel;
  final List<A2UiPoint> points;
  final double? correlation;

  bool get hasData => points.isNotEmpty;

  /// Axis bounds with a 10% margin, widened to ±1 when every point shares a
  /// coordinate so fl_chart never receives a zero-span axis.
  ({double minX, double maxX, double minY, double maxY}) get bounds {
    if (points.isEmpty) {
      return (minX: 0, maxX: 10, minY: 0, maxY: 10);
    }
    var minX = points.first.x, maxX = points.first.x;
    var minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    final xMargin = (maxX - minX) * 0.1;
    final yMargin = (maxY - minY) * 0.1;
    return (
      minX: (minX - (xMargin == 0 ? 1 : xMargin)).floorToDouble(),
      maxX: (maxX + (xMargin == 0 ? 1 : xMargin)).ceilToDouble(),
      minY: (minY - (yMargin == 0 ? 1 : yMargin)).floorToDouble(),
      maxY: (maxY + (yMargin == 0 ? 1 : yMargin)).ceilToDouble(),
    );
  }
}

/// Paired x/y observations with an optional correlation badge.
class ScatterPlotSpec extends A2UiSpec<ScatterPlotProps> {
  const ScatterPlotSpec();

  @override
  String get name => 'ScatterPlot';

  @override
  List<String> get aliases => const ['Scatter', 'XYPlot', 'Correlation'];

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema: 'ScatterPlot {title, xLabel, yLabel, '
            'points: [{x: number, y: number}], correlation?: number}',
        purpose:
            'Relationship between two measures. Use when showing whether one '
            'metric moves with another.',
        example: {
          'component': 'ScatterPlot',
          'props': {
            'title': 'Sleep vs Training Volume',
            'xLabel': 'Sleep Hours',
            'yLabel': 'Volume (kg)',
            'correlation': 0.62,
            'points': [
              {'x': 6.2, 'y': 8200},
              {'x': 7.4, 'y': 11500},
              {'x': 8.1, 'y': 12900},
            ],
          },
        },
      );

  @override
  ScatterPlotProps parseProps(A2UiNode node) {
    final p = node.props;
    final points = <A2UiPoint>[];
    for (final raw in p.objectList('points')) {
      final x = raw.numberOrNull('x');
      final y = raw.numberOrNull('y');
      if (x == null || y == null) continue;
      points.add(A2UiPoint(x, y));
    }

    return ScatterPlotProps(
      title: p.text('title', or: 'Scatter Plot'),
      xLabel: p.text('xLabel', or: 'X'),
      yLabel: p.text('yLabel', or: 'Y'),
      points: points,
      correlation: p.numberOrNull('correlation'),
    );
  }

  @override
  Widget buildWidget(
    BuildContext context,
    ScatterPlotProps props,
    A2UiTheme theme,
  ) {
    if (!props.hasData) {
      return A2UiEmptyPanel(
        message: '${props.title}: No paired data available',
        theme: theme,
      );
    }

    final b = props.bounds;
    final r = props.correlation;
    final strong = r != null && r.abs() >= 0.5;
    final badgeColor = strong ? theme.accent : theme.seriesColor(1);

    return A2UiPanel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: A2UiPanelTitle(title: props.title, theme: theme),
              ),
              if (r != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'r = ${r >= 0 ? '+' : ''}${r.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${props.yLabel} vs. ${props.xLabel}',
            style: TextStyle(color: theme.textMuted, fontSize: 11),
          ),
          SizedBox(height: theme.spacing),
          SizedBox(
            height: 195,
            child: ScatterChart(
              ScatterChartData(
                minX: b.minX,
                maxX: b.maxX,
                minY: b.minY,
                maxY: b.maxY,
                scatterSpots: [
                  for (final p in props.points) ScatterSpot(p.x, p.y),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: theme.border, strokeWidth: 1),
                  getDrawingVerticalLine: (_) =>
                      FlLine(color: theme.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(
                      props.xLabel,
                      style: TextStyle(color: theme.textFaint, fontSize: 10),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) => Text(
                        v.round().toString(),
                        style:
                            TextStyle(color: theme.textFaint, fontSize: 10),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(
                      props.yLabel,
                      style: TextStyle(color: theme.textFaint, fontSize: 10),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) => Text(
                        v.round().toString(),
                        style:
                            TextStyle(color: theme.textFaint, fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
