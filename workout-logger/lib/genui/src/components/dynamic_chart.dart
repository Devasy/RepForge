import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../a2ui_node.dart';
import '../a2ui_panels.dart';
import '../a2ui_series.dart';
import '../a2ui_spec.dart';
import '../a2ui_theme.dart';

enum A2UiChartType {
  line,
  bar,
  pie;

  /// Normalizes separators and common model spellings (`LineChart`,
  /// `bar_chart`, `donut`) onto the three supported types, defaulting to line.
  static A2UiChartType parse(String? raw) {
    final t = raw?.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ?? '';
    if (t.contains('pie') || t.contains('donut') || t.contains('doughnut')) {
      return A2UiChartType.pie;
    }
    if (t.contains('bar') || t.contains('column') || t.contains('histogram')) {
      return A2UiChartType.bar;
    }
    return A2UiChartType.line;
  }
}

@immutable
class DynamicChartProps {
  const DynamicChartProps({
    required this.title,
    required this.type,
    required this.labels,
    required this.series,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final A2UiChartType type;

  /// Always at least as long as the longest series, padded with empty strings,
  /// so axis label lookup by index can never go out of range.
  final List<String> labels;
  final List<A2UiSeries> series;

  bool get hasData => series.isNotEmpty;
}

/// Line, bar or pie over the shared `{labels, series}` shape.
class DynamicChartSpec extends A2UiSpec<DynamicChartProps> {
  const DynamicChartSpec();

  @override
  String get name => 'DynamicChart';

  @override
  List<String> get aliases => const [
        'Chart',
        'LineChart',
        'BarChart',
        'PieChart',
        'TimeSeries',
      ];

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema: 'DynamicChart {type: line|bar|pie, title, labels: [string], '
            'series: [{name, values: [number]}]}  '
            '// or values: [number] for a single series',
        purpose:
            'Trends over time (line), category comparisons (bar), or a share '
            'breakdown (pie). Use multiple series to compare.',
        example: {
          'component': 'DynamicChart',
          'props': {
            'type': 'line',
            'title': 'Biceps vs Triceps Volume',
            'labels': ['07-06', '07-09', '07-12'],
            'series': [
              {'name': 'Biceps', 'values': [640, 720, 810]},
              {'name': 'Triceps', 'values': [1200, 1150, 1290]},
            ],
          },
        },
      );

  @override
  DynamicChartProps parseProps(A2UiNode node) {
    final p = node.props;
    final title = p.text('title', or: 'Chart');
    final series = A2UiSeries.extract(p, fallbackName: title);

    var longest = 0;
    for (final s in series) {
      if (s.values.length > longest) longest = s.values.length;
    }
    final labels = p.stringList('labels');
    final padded = [
      ...labels,
      for (var i = labels.length; i < longest; i++) '',
    ];

    final subtitle = p.textOrNull('subtitle');

    return DynamicChartProps(
      title: title,
      subtitle: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
      type: A2UiChartType.parse(p.textOrNull('type')),
      labels: padded,
      series: series,
    );
  }

  @override
  Widget buildWidget(
    BuildContext context,
    DynamicChartProps props,
    A2UiTheme theme,
  ) {
    if (!props.hasData) {
      return A2UiEmptyPanel(
        message: '${props.title}: No chart data available',
        theme: theme,
      );
    }

    final showLegend =
        props.series.length > 1 && props.type != A2UiChartType.pie;

    return A2UiPanel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          A2UiPanelTitle(
            title: props.title,
            trailing: props.type == A2UiChartType.pie ? props.subtitle : null,
            theme: theme,
          ),
          if (showLegend) ...[
            const SizedBox(height: 6),
            A2UiLegend(
              names: [for (final s in props.series) s.name],
              theme: theme,
            ),
          ],
          SizedBox(height: theme.spacing),
          SizedBox(
            height: 195,
            child: switch (props.type) {
              A2UiChartType.bar => _bar(props, theme),
              A2UiChartType.pie => _pie(props, theme),
              A2UiChartType.line => _line(props, theme),
            },
          ),
        ],
      ),
    );
  }

  Widget _line(DynamicChartProps props, A2UiTheme theme) {
    final (minY, maxY) = _yBounds(props.series);
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: a2uiGridData(theme),
        borderData: FlBorderData(show: false),
        titlesData: a2uiTitlesData(props.labels, theme),
        lineBarsData: [
          for (var i = 0; i < props.series.length; i++)
            LineChartBarData(
              spots: [
                for (var x = 0; x < props.series[i].values.length; x++)
                  FlSpot(x.toDouble(), props.series[i].values[x]),
              ],
              isCurved: true,
              color: theme.seriesColor(i),
              barWidth: 3,
              dotData: FlDotData(show: props.series[i].values.length < 10),
              belowBarData: BarAreaData(
                show: props.series.length == 1,
                color: theme.seriesColor(i).withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(DynamicChartProps props, A2UiTheme theme) {
    final (minY, maxY) = _yBounds(props.series);
    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        gridData: a2uiGridData(theme),
        borderData: FlBorderData(show: false),
        titlesData: a2uiTitlesData(props.labels, theme),
        barGroups: [
          for (var group = 0; group < props.labels.length; group++)
            BarChartGroupData(
              x: group,
              barRods: [
                for (var i = 0; i < props.series.length; i++)
                  if (group < props.series[i].values.length)
                    BarChartRodData(
                      toY: props.series[i].values[group],
                      width: props.series.length > 1 ? 8 : 14,
                      borderRadius: BorderRadius.circular(6),
                      color: theme.seriesColor(i),
                    ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _pie(DynamicChartProps props, A2UiTheme theme) {
    final rawValues = props.series.first.values;
    // A pie slice needs a positive share of the whole; negative or zero
    // entries have no geometric meaning. Filter them out, but keep each
    // surviving entry's ORIGINAL index so theme.seriesColor(i) and
    // props.labels[i] — both indexed by original position — stay aligned.
    final positive = <int>[
      for (var i = 0; i < rawValues.length; i++)
        if (rawValues[i] > 0) i,
    ];
    if (positive.isEmpty) {
      return A2UiEmptyPanel(
        message: '${props.title}: No positive values to chart',
        theme: theme,
      );
    }
    final total = positive.fold<double>(0, (sum, i) => sum + rawValues[i]);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (final i in positive)
                  PieChartSectionData(
                    value: rawValues[i],
                    color: theme.seriesColor(i),
                    radius: 44,
                    title: '${(rawValues[i] / total * 100).round()}%',
                    titleStyle: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: theme.spacing / 2),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in positive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.seriesColor(i),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${i < props.labels.length ? props.labels[i] : ''} '
                            '(${rawValues[i].round()})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: theme.textMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Y-axis bounds for [series], shared by `_line` and `_bar` so both charts
/// agree on the same visible range.
///
/// When every value is non-negative, the axis starts at 0 (existing
/// behavior), with a 15% headroom margin above the max — clamped to a
/// minimum span of 1 so an all-zero series doesn't collapse to a
/// zero-height axis.
///
/// When any value is negative, both bounds are derived from the true min
/// and max (via [A2UiSeries.minValue]/[A2UiSeries.maxValue], which return
/// real negative extrema rather than clamping to 0) so every data point —
/// including an all-negative series — falls within the visible range with
/// a margin, instead of silently rendering off-chart.
(double, double) _yBounds(List<A2UiSeries> series) {
  final max = A2UiSeries.maxValue(series);
  final min = A2UiSeries.minValue(series);
  if (min >= 0) {
    return (0, max <= 0 ? 1 : max * 1.15);
  }
  final minY = min * 1.15;
  final maxY = max <= 0 ? max * 0.85 : max * 1.15;
  return (minY, maxY);
}

/// Horizontal-only grid lines in the theme's border colour.
FlGridData a2uiGridData(A2UiTheme theme) => FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: theme.border, strokeWidth: 1),
    );

/// Bottom axis labelled from [labels] by index, with a bounds check so an
/// out-of-range tick renders nothing rather than throwing.
FlTitlesData a2uiTitlesData(List<String> labels, A2UiTheme theme) =>
    FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 34),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= labels.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                labels[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.textFaint, fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
