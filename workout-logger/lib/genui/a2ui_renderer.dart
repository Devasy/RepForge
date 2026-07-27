import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'a2ui_component.dart';

/// Renders an [A2UiComponent] tree as Flutter widgets.
///
/// All components are rendered locally without any server round-trip.
/// The [A2UiComponent] model is populated from the JSON returned by the
/// Gemini coach, so this widget is purely presentational.
class A2UiRenderer extends StatelessWidget {
  const A2UiRenderer({super.key, required this.component});

  final A2UiComponent component;

  @override
  Widget build(BuildContext context) => _renderComponent(component);

  static Widget _renderComponent(A2UiComponent component) {
    return switch (component.component) {
      'StatCard' => _A2StatCard(data: component.props),
      'DynamicChart' => _A2DynamicChart(data: component.props),
      'DataListGroup' => _A2DataListGroup(data: component.props),
      'FilterChips' => _A2FilterChips(data: component.props),
      'GridContainer' => _A2GridContainer(
        component: component,
        data: component.props,
      ),
      'ScatterPlot' => _A2ScatterPlot(data: component.props),
      'RadarChart' => _A2RadarChart(data: component.props),
      'MetricGauge' => _A2MetricGauge(data: component.props),
      _ => const SizedBox.shrink(),
    };
  }
}

// ─── Grid ────────────────────────────────────────────────────────────────────

class _A2GridContainer extends StatelessWidget {
  const _A2GridContainer({required this.component, required this.data});

  final A2UiComponent component;
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final columns = (data['columns'] as num).toInt();
    final children = component.children;

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveColumns = constraints.maxWidth < 340 ? 1 : columns;
        if (effectiveColumns == 1) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                A2UiRenderer._renderComponent(children[i]),
                if (i < children.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        }
        // 2-column grid
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += 2) {
          final left = children[i];
          final right = i + 1 < children.length ? children[i + 1] : null;
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: A2UiRenderer._renderComponent(left)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: right != null
                        ? A2UiRenderer._renderComponent(right)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
          if (i + 2 < children.length) {
            rows.add(const SizedBox(height: AppSpacing.sm));
          }
        }
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }
}

// ─── StatCard ─────────────────────────────────────────────────────────────────

class _A2StatCard extends StatelessWidget {
  const _A2StatCard({required this.data});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final trend = data['trend'] as String;
    final trendColor = switch (trend) {
      'up' => AppColors.success,
      'down' => AppColors.error,
      _ => AppColors.textMuted,
    };
    final trendIcon = switch (trend) {
      'up' => Icons.trending_up_rounded,
      'down' => Icons.trending_down_rounded,
      _ => Icons.trending_flat_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['title'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(trendIcon, color: trendColor, size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              data['value'] as String,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (data['subtitle'] case final String subtitle) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── DynamicChart ─────────────────────────────────────────────────────────────

class _A2DynamicChart extends StatelessWidget {
  const _A2DynamicChart({required this.data});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'line';
    final labels = (data['labels'] as List?)?.cast<String>() ?? const [];

    final seriesList = _extractSeries(data);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data['title'] as String? ?? 'Chart',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (type == 'pie' && data['subtitle'] is String)
                Text(
                  data['subtitle'] as String,
                  style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
                ),
            ],
          ),
          if (seriesList.length > 1 && type != 'pie') ...[
            const SizedBox(height: 6),
            _buildLegend(seriesList),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 195,
            child: seriesList.isEmpty || labels.isEmpty
                ? const Center(
                    child: Text(
                      'No chart data available',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : switch (type) {
                    'bar' => _barChart(seriesList, labels),
                    'pie' => _pieChart(seriesList, labels),
                    _ => _lineChart(seriesList, labels),
                  },
          ),
        ],
      ),
    );
  }

  static List<_SeriesData> _extractSeries(Map<String, Object?> data) {
    if (data['series'] case final List rawSeries when rawSeries.isNotEmpty) {
      final result = <_SeriesData>[];
      for (final item in rawSeries) {
        if (item is Map<String, Object?>) {
          final name = item['name'] as String? ?? 'Series';
          final vals = (item['values'] as List?)
                  ?.map((v) => (v as num).toDouble())
                  .toList() ??
              const [];
          result.add(_SeriesData(name: name, values: vals));
        }
      }
      if (result.isNotEmpty) return result;
    }

    if (data['values'] case final List rawVals when rawVals.isNotEmpty) {
      final vals = rawVals.map((v) => (v as num).toDouble()).toList();
      return [_SeriesData(name: data['title'] as String? ?? 'Value', values: vals)];
    }

    return const [];
  }

  Widget _buildLegend(List<_SeriesData> series) {
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (var i = 0; i < series.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 3,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                series[i].name,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _lineChart(List<_SeriesData> series, List<String> labels) {
    var maxY = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > maxY) maxY = v;
      }
    }

    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.15,
        gridData: _gridData(),
        borderData: FlBorderData(show: false),
        titlesData: _titlesData(labels),
        lineBarsData: [
          for (var idx = 0; idx < series.length; idx++)
            LineChartBarData(
              spots: [
                for (var i = 0; i < series[idx].values.length; i++)
                  FlSpot(i.toDouble(), series[idx].values[i]),
              ],
              isCurved: true,
              color: colors[idx % colors.length],
              barWidth: 3,
              dotData: FlDotData(show: series[idx].values.length < 10),
              belowBarData: BarAreaData(
                show: series.length == 1,
                color: colors[idx % colors.length].withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _barChart(List<_SeriesData> series, List<String> labels) {
    var maxY = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > maxY) maxY = v;
      }
    }

    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
    ];

    final numGroups = labels.length;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.15,
        gridData: _gridData(),
        borderData: FlBorderData(show: false),
        titlesData: _titlesData(labels),
        barGroups: [
          for (var groupIdx = 0; groupIdx < numGroups; groupIdx++)
            BarChartGroupData(
              x: groupIdx,
              barRods: [
                for (var sIdx = 0; sIdx < series.length; sIdx++)
                  if (groupIdx < series[sIdx].values.length)
                    BarChartRodData(
                      toY: series[sIdx].values[groupIdx],
                      width: series.length > 1 ? 8 : 14,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      color: colors[sIdx % colors.length],
                    ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _pieChart(List<_SeriesData> series, List<String> labels) {
    final values = series.isNotEmpty && series[0].values.isNotEmpty
        ? series[0].values
        : <double>[];
    final total = values.fold<double>(0, (sum, v) => sum + v);
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
    ];

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (var i = 0; i < values.length; i++)
                  PieChartSectionData(
                    value: values[i],
                    color: colors[i % colors.length],
                    radius: 44,
                    title: total <= 0
                        ? ''
                        : '${(values[i] / total * 100).round()}%',
                    titleStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < labels.length && i < values.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${labels[i]} (${values[i].round()})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
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

class _SeriesData {
  final String name;
  final List<double> values;
  const _SeriesData({required this.name, required this.values});
}

  FlGridData _gridData() => FlGridData(
    show: true,
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) => const FlLine(
      color: AppColors.glassBorder,
      strokeWidth: 1,
    ),
  );

  FlTitlesData _titlesData(List<String> labels) => FlTitlesData(
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
              style: const TextStyle(color: AppColors.textFaint, fontSize: 10),
            ),
          );
        },
      ),
    ),
  );

// ─── DataListGroup ────────────────────────────────────────────────────────────

class _A2DataListGroup extends StatelessWidget {
  const _A2DataListGroup({required this.data});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List).cast<Map<String, Object?>>();
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              data['title'] as String,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _A2ListRow(item: items[i], showDivider: i < items.length - 1),
        ],
      ),
    );
  }
}

class _A2ListRow extends StatelessWidget {
  const _A2ListRow({required this.item, required this.showDivider});

  final Map<String, Object?> item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.divider))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['primaryText'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['secondaryText'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            item['trailingValue'] as String,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FilterChips ──────────────────────────────────────────────────────────────

class _A2FilterChips extends StatelessWidget {
  const _A2FilterChips({required this.data});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final options = (data['options'] as List).cast<String>();
    final active = data['activeOption'] as String;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final option in options)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: option == active
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.glass3,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: option == active
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.glassBorder,
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                color: option == active
                    ? AppColors.primary
                    : AppColors.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── ScatterPlot ──────────────────────────────────────────────────────────────

class _A2ScatterPlot extends StatelessWidget {
  const _A2ScatterPlot({required this.data});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Scatter Plot';
    final xLabel = data['xLabel'] as String? ?? 'X';
    final yLabel = data['yLabel'] as String? ?? 'Y';
    final rawPoints = (data['points'] as List?) ?? const [];
    final correlation = (data['correlation'] as num?)?.toDouble();

    final spots = <ScatterSpot>[];
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;

    for (final p in rawPoints) {
      if (p is Map<String, Object?>) {
        final x = (p['x'] as num).toDouble();
        final y = (p['y'] as num).toDouble();
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;

        spots.add(
          ScatterSpot(x, y),
        );
      }
    }

    if (spots.isEmpty) {
      minX = 0; maxX = 10; minY = 0; maxY = 10;
    } else {
      final xMargin = (maxX - minX) * 0.1;
      final yMargin = (maxY - minY) * 0.1;
      minX = (minX - (xMargin == 0 ? 1 : xMargin)).floorToDouble();
      maxX = (maxX + (xMargin == 0 ? 1 : xMargin)).ceilToDouble();
      minY = (minY - (yMargin == 0 ? 1 : yMargin)).floorToDouble();
      maxY = (maxY + (yMargin == 0 ? 1 : yMargin)).ceilToDouble();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (correlation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (correlation.abs() >= 0.5
                            ? AppColors.primary
                            : AppColors.secondary)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                      color: (correlation.abs() >= 0.5
                              ? AppColors.primary
                              : AppColors.secondary)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'r = ${correlation >= 0 ? "+" : ""}${correlation.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: correlation.abs() >= 0.5
                          ? AppColors.primary
                          : AppColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$yLabel vs. $xLabel',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 195,
            child: ScatterChart(
              ScatterChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                scatterSpots: spots,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (val) =>
                      const FlLine(color: AppColors.glassBorder, strokeWidth: 1),
                  getDrawingVerticalLine: (val) =>
                      const FlLine(color: AppColors.glassBorder, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: Text(xLabel, style: const TextStyle(color: AppColors.textFaint, fontSize: 10)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) => Text(
                        val.round().toString(),
                        style: const TextStyle(color: AppColors.textFaint, fontSize: 10),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(yLabel, style: const TextStyle(color: AppColors.textFaint, fontSize: 10)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) => Text(
                        val.round().toString(),
                        style: const TextStyle(color: AppColors.textFaint, fontSize: 10),
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

// ─── RadarChart ───────────────────────────────────────────────────────────────

class _A2RadarChart extends StatelessWidget {
  const _A2RadarChart({required this.data});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Radar Chart';
    final axes = (data['axes'] as List?)?.cast<String>() ?? const [];
    final rawSeries = (data['series'] as List?) ?? const [];

    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
    ];

    final dataSets = <RadarDataSet>[];
    final seriesNames = <String>[];

    for (var i = 0; i < rawSeries.length; i++) {
      final s = rawSeries[i];
      if (s is Map<String, Object?>) {
        final name = s['name'] as String? ?? 'Series ${i + 1}';
        final vals = (s['values'] as List?)
                ?.map((v) => (v as num).toDouble())
                .toList() ??
            const [];

        seriesNames.add(name);
        dataSets.add(
          RadarDataSet(
            fillColor: colors[i % colors.length].withValues(alpha: 0.2),
            borderColor: colors[i % colors.length],
            entryRadius: 3,
            borderWidth: 2,
            dataEntries: [
              for (final v in vals) RadarEntry(value: v),
            ],
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (seriesNames.length > 1) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                for (var i = 0; i < seriesNames.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        seriesNames[i],
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 200,
            child: dataSets.isEmpty || axes.isEmpty
                ? const Center(
                    child: Text(
                      'No radar data available',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : RadarChart(
                    RadarChartData(
                      dataSets: dataSets,
                      radarBorderData: const BorderSide(color: AppColors.glassBorder),
                      gridBorderData: const BorderSide(color: AppColors.glassBorder, width: 0.8),
                      tickBorderData: const BorderSide(color: Colors.transparent),
                      ticksTextStyle: const TextStyle(color: Colors.transparent),
                      getTitle: (index, angle) {
                        if (index < axes.length) {
                          return RadarChartTitle(
                            text: axes[index],
                            positionPercentageOffset: 0.1,
                          );
                        }
                        return const RadarChartTitle(text: '');
                      },
                      titleTextStyle: const TextStyle(
                        color: AppColors.textMuted,
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

// ─── MetricGauge ──────────────────────────────────────────────────────────────

class _A2MetricGauge extends StatelessWidget {
  const _A2MetricGauge({required this.data});

  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Metric';
    final val = (data['value'] as num).toDouble();
    final min = (data['min'] as num?)?.toDouble() ?? 0.0;
    final max = (data['max'] as num?)?.toDouble() ?? 100.0;
    final unit = data['unit'] as String? ?? '';
    final status = data['status'] as String?;

    final progress = ((val - min) / (max - min)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 120,
            width: 120,
            child: CustomPaint(
              painter: _GaugeArcPainter(progress: progress),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        unit,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (status != null && status.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  color: AppColors.primary,
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
  final double progress;
  _GaugeArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = AppColors.glass3
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugeArcPainter oldDelegate) => oldDelegate.progress != progress;
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

BoxDecoration _panelDecoration() => BoxDecoration(
  color: AppColors.card,
  borderRadius: BorderRadius.circular(AppRadius.lg),
  border: Border.all(color: AppColors.glassBorder),
);