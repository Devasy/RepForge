import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../a2ui_node.dart';
import '../a2ui_panels.dart';
import '../a2ui_series.dart';
import '../a2ui_spec.dart';
import '../a2ui_theme.dart';

@immutable
class RadarChartProps {
  const RadarChartProps({
    required this.title,
    required this.labels,
    required this.series,
  });

  final String title;
  final List<String> labels;

  /// Every series is exactly [labels].length long — fl_chart requires a uniform
  /// entry count across datasets, so normalization happens at parse time.
  final List<A2UiSeries> series;

  /// fl_chart's radar needs at least three axes to form a polygon.
  bool get hasData => labels.length >= 3 && series.isNotEmpty;
}

/// Multi-axis balance view over the shared `{labels, series}` shape.
class RadarChartSpec extends A2UiSpec<RadarChartProps> {
  const RadarChartSpec();

  @override
  String get name => 'RadarChart';

  @override
  List<String> get aliases => const ['Radar', 'SpiderChart', 'BalanceChart'];

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema: 'RadarChart {title, labels: [string], '
            'series: [{name, values: [number]}]}',
        purpose:
            'Balance across 3+ comparable axes. Use for holistic summaries '
            'where every axis shares a scale.',
        example: {
          'component': 'RadarChart',
          'props': {
            'title': 'Recovery Balance',
            'labels': ['Readiness', 'Sleep', 'Volume', 'Intensity'],
            'series': [
              {'name': 'This week', 'values': [85, 90, 75, 80]},
              {'name': 'Baseline', 'values': [70, 70, 70, 70]},
            ],
          },
        },
      );

  @override
  RadarChartProps parseProps(A2UiNode node) {
    final p = node.props;
    final labels = p.stringList('labels');
    final raw = A2UiSeries.extract(p);

    // fl_chart throws when datasets disagree on entry count, so pad or truncate
    // every series to the axis count before it can reach the widget.
    final normalized = [
      for (final s in raw)
        A2UiSeries(
          name: s.name,
          values: [
            for (var i = 0; i < labels.length; i++)
              i < s.values.length ? s.values[i] : 0.0,
          ],
        ),
    ];

    return RadarChartProps(
      title: p.text('title', or: 'Radar Chart'),
      labels: labels,
      series: normalized,
    );
  }

  @override
  Widget buildWidget(
    BuildContext context,
    RadarChartProps props,
    A2UiTheme theme,
  ) {
    if (!props.hasData) {
      return A2UiEmptyPanel(
        message: '${props.title}: No radar data available',
        theme: theme,
      );
    }

    return A2UiPanel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          A2UiPanelTitle(title: props.title, theme: theme),
          if (props.series.length > 1) ...[
            const SizedBox(height: 6),
            A2UiLegend(
              names: [for (final s in props.series) s.name],
              theme: theme,
              dots: true,
            ),
          ],
          SizedBox(height: theme.spacing),
          SizedBox(
            height: 200,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  for (var i = 0; i < props.series.length; i++)
                    RadarDataSet(
                      fillColor:
                          theme.seriesColor(i).withValues(alpha: 0.2),
                      borderColor: theme.seriesColor(i),
                      entryRadius: 3,
                      borderWidth: 2,
                      dataEntries: [
                        for (final v in props.series[i].values)
                          RadarEntry(value: v),
                      ],
                    ),
                ],
                radarBorderData: BorderSide(color: theme.border),
                gridBorderData: BorderSide(color: theme.border, width: 0.8),
                tickBorderData: const BorderSide(color: Color(0x00000000)),
                ticksTextStyle: const TextStyle(color: Color(0x00000000)),
                getTitle: (index, angle) => RadarChartTitle(
                  text: index < props.labels.length ? props.labels[index] : '',
                  positionPercentageOffset: 0.1,
                ),
                titleTextStyle: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
