import 'package:flutter/material.dart';

import '../a2ui_node.dart';
import '../a2ui_panels.dart';
import '../a2ui_spec.dart';
import '../a2ui_theme.dart';

/// Direction badge shown on a [StatCardSpec].
enum A2UiTrend {
  up,
  down,
  neutral;

  /// Accepts the canonical words plus the synonyms models reach for, so
  /// `improving` and `declining` do not silently render as neutral.
  static A2UiTrend parse(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'up':
      case 'improving':
      case 'positive':
      case 'rising':
      case 'increasing':
      case 'better':
        return A2UiTrend.up;
      case 'down':
      case 'declining':
      case 'decline':
      case 'negative':
      case 'falling':
      case 'decreasing':
      case 'worse':
        return A2UiTrend.down;
      default:
        return A2UiTrend.neutral;
    }
  }
}

@immutable
class StatCardProps {
  const StatCardProps({
    required this.title,
    required this.value,
    required this.trend,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final A2UiTrend trend;
}

/// A single headline number with an optional caption and direction badge.
class StatCardSpec extends A2UiSpec<StatCardProps> {
  const StatCardSpec();

  @override
  String get name => 'StatCard';

  @override
  List<String> get aliases => const ['Stat', 'KpiCard', 'Kpi', 'MetricCard'];

  @override
  A2UiDoc get doc => const A2UiDoc(
        schema:
            'StatCard {title, value, unit?, subtitle?, trend?: up|down|neutral}',
        purpose: 'One headline number. Use for totals, averages and deltas.',
        example: {
          'component': 'StatCard',
          'props': {
            'title': 'Weekly Volume',
            'value': 12400,
            'unit': 'kg',
            'subtitle': 'Last 7 days',
            'trend': 'up',
          },
        },
      );

  @override
  StatCardProps parseProps(A2UiNode node) {
    final p = node.props;

    final rawValue = p.textOrNull('value');
    final unit = p.textOrNull('unit');
    final String value;
    if (rawValue == null) {
      value = '—';
    } else if (unit == null ||
        unit.isEmpty ||
        rawValue.trimRight().endsWith(unit)) {
      // Only a trailing-suffix match counts as "already present" — a naive
      // substring check would false-positive on e.g. value "10 reps" with
      // unit "s" (a substring of "reps"), silently dropping a real unit.
      value = rawValue;
    } else {
      value = '$rawValue $unit';
    }

    final subtitle = p.textOrNull('subtitle');

    return StatCardProps(
      title: p.text('title', or: 'Metric'),
      value: value,
      subtitle: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
      trend: A2UiTrend.parse(p.textOrNull('trend')),
    );
  }

  @override
  Widget buildWidget(
    BuildContext context,
    StatCardProps props,
    A2UiTheme theme,
  ) {
    final (icon, color) = switch (props.trend) {
      A2UiTrend.up => (Icons.trending_up_rounded, theme.positive),
      A2UiTrend.down => (Icons.trending_down_rounded, theme.negative),
      A2UiTrend.neutral => (Icons.trending_flat_rounded, theme.textMuted),
    };

    return A2UiPanel(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  props.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          SizedBox(height: theme.spacing / 2),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              props.value,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (props.subtitle case final String subtitle) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textFaint, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
