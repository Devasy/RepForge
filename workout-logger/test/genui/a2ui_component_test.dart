import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/a2ui_component.dart';

void main() {
  group('A2UiComponent', () {
    test('parses a valid dashboard payload', () {
      final component = A2UiComponent.tryParse('''
{
  "component": "GridContainer",
  "props": {
    "columns": 2,
    "children": [
      {
        "component": "StatCard",
        "props": {
          "title": "Volume",
          "value": "12k kg",
          "subtitle": "Last 7 days",
          "trend": "up"
        }
      },
      {
        "component": "DynamicChart",
        "props": {
          "type": "bar",
          "title": "Weekly Sets",
          "labels": ["Mon", "Wed"],
          "values": [12, 15]
        }
      }
    ]
  }
}
''');

      expect(component, isNotNull);
      expect(component!.component, 'GridContainer');
      expect(component.children, hasLength(2));
    });

    test('rejects unknown component names', () {
      final component = A2UiComponent.tryParse(
        '{"component":"HeroCard","props":{"title":"Nope"}}',
      );

      expect(component, isNull);
    });

    test('rejects invalid prop shapes', () {
      final component = A2UiComponent.tryParse(
        '{"component":"DynamicChart","props":{"type":"line","title":"Bad","labels":["A"],"values":["1"]}}',
      );

      expect(component, isNull);
    });

    test('ignores normal markdown replies', () {
      expect(A2UiComponent.tryParse('**Nice work.** Keep going.'), isNull);
    });

    test('parses ScatterPlot, RadarChart, and MetricGauge components', () {
      final scatter = A2UiComponent.tryParse('''
{
  "component": "ScatterPlot",
  "props": {
    "title": "Sleep vs Volume",
    "xLabel": "Sleep Hours",
    "yLabel": "Volume (kg)",
    "correlation": 0.82,
    "trendline": {"slope": 150.0, "intercept": 500.0},
    "points": [{"x": 7.5, "y": 1600}]
  }
}
''');
      expect(scatter, isNotNull);
      expect(scatter!.component, 'ScatterPlot');

      final radar = A2UiComponent.tryParse('''
{
  "component": "RadarChart",
  "props": {
    "title": "Holistic Recovery",
    "axes": ["Readiness", "Sleep", "Volume", "Intensity"],
    "series": [{"name": "Current", "values": [85, 90, 75, 80]}]
  }
}
''');
      expect(radar, isNotNull);
      expect(radar!.component, 'RadarChart');

      final gauge = A2UiComponent.tryParse('''
{
  "component": "MetricGauge",
  "props": {
    "title": "Readiness Score",
    "value": 88,
    "min": 0,
    "max": 100,
    "unit": "/ 100",
    "status": "Optimal"
  }
}
''');
      expect(gauge, isNotNull);
      expect(gauge!.component, 'MetricGauge');
    });

    test('parses flat child components without props wrapper', () {
      final dashboard = A2UiComponent.tryParse('''
{
  "component": "GridContainer",
  "props": {
    "columns": 1,
    "children": [
      {
        "component": "DynamicChart",
        "type": "line",
        "title": "Biceps vs Triceps Volume",
        "labels": ["07-06", "07-09"],
        "series": [
          {"name": "Biceps", "values": [0, 645]},
          {"name": "Triceps", "values": [2390, 0]}
        ]
      },
      {
        "component": "StatCard",
        "title": "Recent Volume",
        "value": "1,085 kg",
        "trend": "up"
      }
    ]
  }
}
''');
      expect(dashboard, isNotNull);
      expect(dashboard!.component, 'GridContainer');
      expect(dashboard.children, hasLength(2));
      expect(dashboard.children[0].component, 'DynamicChart');
      expect(dashboard.children[1].component, 'StatCard');
    });
  });
}
