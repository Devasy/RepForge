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
    final trimmed = text.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return null;

    try {
      final decoded = jsonDecode(trimmed);
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
        return props['title'] is String &&
            props['value'] is String &&
            _optionalString(props, 'subtitle') &&
            _oneOf(props['trend'], const ['up', 'down', 'neutral']);
      case 'DynamicChart':
        final typeOk = _oneOf(props['type'], const ['line', 'bar', 'pie']);
        final titleOk = props['title'] is String;
        final labelsOk = _stringList(props['labels']) != null;
        final singleValOk = _numList(props['values']) != null;
        final seriesOk = props['series'] is List &&
            (props['series'] as List).isNotEmpty &&
            (props['series'] as List).every((s) =>
                s is Map<String, dynamic> &&
                s['name'] is String &&
                _numList(s['values']) != null);
        return typeOk && titleOk && labelsOk && (singleValOk || seriesOk);
      case 'DataListGroup':
        final items = props['items'];
        return props['title'] is String &&
            items is List &&
            items.every((item) {
              if (item is! Map<String, dynamic>) return false;
              return item['primaryText'] is String &&
                  item['secondaryText'] is String &&
                  item['trailingValue'] is String;
            });
      case 'FilterChips':
        final options = _stringList(props['options']);
        return options != null &&
            props['activeOption'] is String &&
            options.contains(props['activeOption']);
      case 'GridContainer':
        final columns = props['columns'];
        final children = props['children'];
        return (columns == 1 || columns == 2) &&
            children is List &&
            children.every(
              (child) =>
                  child is Map<String, dynamic> && fromJson(child) != null,
            );
      case 'ScatterPlot':
        final points = props['points'];
        final pointsOk = points is List &&
            points.isNotEmpty &&
            points.every((p) => p is Map<String, dynamic> && p['x'] is num && p['y'] is num);
        final corrOk = !props.containsKey('correlation') || props['correlation'] is num;
        final trendOk = !props.containsKey('trendline') ||
            (props['trendline'] is Map<String, dynamic> &&
                (props['trendline'] as Map)['slope'] is num &&
                (props['trendline'] as Map)['intercept'] is num);
        return props['title'] is String &&
            props['xLabel'] is String &&
            props['yLabel'] is String &&
            pointsOk &&
            corrOk &&
            trendOk;
      case 'RadarChart':
        final axesOk = _stringList(props['axes']) != null;
        final series = props['series'];
        final seriesOk = series is List &&
            series.isNotEmpty &&
            series.every((s) =>
                s is Map<String, dynamic> &&
                s['name'] is String &&
                _numList(s['values']) != null);
        return props['title'] is String && axesOk && seriesOk;
      case 'MetricGauge':
        final valOk = props['value'] is num;
        final minOk = !props.containsKey('min') || props['min'] is num;
        final maxOk = !props.containsKey('max') || props['max'] is num;
        final unitOk = _optionalString(props, 'unit');
        final statusOk = _optionalString(props, 'status');
        return props['title'] is String && valOk && minOk && maxOk && unitOk && statusOk;
    }
    return false;
  }

  static bool _optionalString(Map<String, dynamic> props, String key) =>
      !props.containsKey(key) || props[key] is String;

  static bool _oneOf(Object? value, List<String> options) =>
      value is String && options.contains(value);

  static List<String>? _stringList(Object? value) {
    if (value is! List || value.any((item) => item is! String)) return null;
    return value.cast<String>();
  }

  static List<double>? _numList(Object? value) {
    if (value is! List || value.any((item) => item is! num)) return null;
    return value.map((item) => (item as num).toDouble()).toList();
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
      (props['labels'] as List?)?.cast<String>() ?? const [];

  List<double> get numericValues =>
      (props['values'] as List?)
          ?.map((value) => (value as num).toDouble())
          .toList() ??
      const [];
}
