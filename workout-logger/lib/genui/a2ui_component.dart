import 'dart:convert';

const allowedA2UiComponents = {
  'StatCard',
  'DynamicChart',
  'DataListGroup',
  'FilterChips',
  'GridContainer',
  'ScatterPlot',
  'RadarChart',
  'MetricGauge',
};

class A2UiComponent {
  const A2UiComponent({
    required this.component,
    required this.props,
  });

  final String component;
  final Map<String, dynamic> props;

  static A2UiComponent? tryParse(String text) {
    var trimmed = text.trim();
    if (trimmed.startsWith('```')) {
      final firstLineEnd = trimmed.indexOf('\n');
      if (firstLineEnd != -1) {
        trimmed = trimmed.substring(firstLineEnd + 1);
      }
      if (trimmed.endsWith('```')) {
        trimmed = trimmed.substring(0, trimmed.length - 3).trim();
      }
    }
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || firstBrace >= lastBrace) return null;
    final jsonSubstring = trimmed.substring(firstBrace, lastBrace + 1);

    try {
      final decoded = jsonDecode(jsonSubstring);
      if (decoded is! Map<String, dynamic>) return null;
      return fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static A2UiComponent? fromJson(Map<String, dynamic> json) {
    final component = json['component'];
    if (component is! String || !allowedA2UiComponents.contains(component)) {
      return null;
    }

    final Map<String, dynamic> props;
    if (json['props'] is Map<String, dynamic>) {
      props = Map<String, dynamic>.from(json['props'] as Map<String, dynamic>);
    } else {
      props = Map<String, dynamic>.from(json)..remove('component');
    }

    if (!_validProps(component, props)) return null;
    return A2UiComponent(component: component, props: props);
  }

  static bool _validProps(String component, Map<String, dynamic> props) {
    switch (component) {
      case 'StatCard':
        final hasTitle = props['title'] is String || props['title'] is num;
        final hasVal = props['value'] is String || props['value'] is num;
        return hasTitle && hasVal;
      case 'DynamicChart':
        final typeOk = !props.containsKey('type') || _oneOf(props['type'], const ['line', 'bar', 'pie']);
        final titleOk = props['title'] is String || props['title'] is num || !props.containsKey('title');
        final labelsOk = _stringList(props['labels']) != null;
        final singleValOk = _numList(props['values']) != null;
        final seriesOk = props['series'] is List &&
            (props['series'] as List).isNotEmpty;
        return typeOk && titleOk && labelsOk && (singleValOk || seriesOk);
      case 'DataListGroup':
        final items = props['items'];
        return (props['title'] is String || !props.containsKey('title')) && items is List;
      case 'FilterChips':
        final options = _stringList(props['options']);
        return options != null;
      case 'GridContainer':
        final children = props['children'];
        return children is List &&
            children.every(
              (child) =>
                  child is Map<String, dynamic> && fromJson(child) != null,
            );
      case 'ScatterPlot':
        final points = props['points'];
        return points is List && points.isNotEmpty;
      case 'RadarChart':
        final axesOk = _stringList(props['axes']) != null;
        final series = props['series'];
        return axesOk && series is List && series.isNotEmpty;
      case 'MetricGauge':
        return (props['value'] is num || props['value'] is String);
    }
    return false;
  }

  static bool _optionalStringOrNum(Map<String, dynamic> props, String key) =>
      !props.containsKey(key) || props[key] is String || props[key] is num;

  static bool _oneOf(Object? value, List<String> options) =>
      value is String && options.contains(value);

  static List<String>? _stringList(Object? value) {
    if (value is! List) return null;
    return value.map((item) => item?.toString() ?? '').toList();
  }

  static List<double>? _numList(Object? value) {
    if (value is! List) return null;
    return value
        .map((item) => item is num
            ? item.toDouble()
            : (double.tryParse(item?.toString() ?? '') ?? 0.0))
        .toList();
  }

  List<A2UiComponent> get children {
    final raw = props['children'];
    if (component != 'GridContainer' || raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .whereType<A2UiComponent>()
        .toList();
  }

  List<String> get stringLabels =>
      (props['labels'] as List?)?.map((item) => item?.toString() ?? '').toList() ?? const [];

  List<double> get numericValues =>
      (props['values'] as List?)
          ?.map((value) => value is num
              ? value.toDouble()
              : (double.tryParse(value?.toString() ?? '') ?? 0.0))
          .toList() ??
      const [];
}
