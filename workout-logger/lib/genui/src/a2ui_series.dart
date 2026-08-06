import 'a2ui_props.dart';

/// One named run of numbers plotted against a shared categorical axis.
///
/// This is the single categorical shape in A2UI: line, bar, pie and radar all
/// consume it, so a model that learns `{labels, series}` once can drive four
/// components.
class A2UiSeries {
  const A2UiSeries({required this.name, required this.values});

  final String name;
  final List<double> values;

  /// Pulls series out of [props], accepting either the full
  /// `series:[{name, values}]` form or the `values:[...]` shorthand.
  ///
  /// Entries with no parseable numbers are dropped, so callers can treat a
  /// non-empty result as renderable.
  static List<A2UiSeries> extract(
    A2UiProps props, {
    String fallbackName = 'Value',
  }) {
    final rawSeries = props.objectList('series');
    if (rawSeries.isNotEmpty) {
      final out = <A2UiSeries>[];
      for (var i = 0; i < rawSeries.length; i++) {
        final values = rawSeries[i].numberList('values');
        if (values.isEmpty) continue;
        out.add(A2UiSeries(
          name: rawSeries[i].text('name', or: 'Series ${i + 1}'),
          values: values,
        ));
      }
      if (out.isNotEmpty) return out;
    }

    final flat = props.numberList('values');
    if (flat.isNotEmpty) {
      return [A2UiSeries(name: fallbackName, values: flat)];
    }

    return const [];
  }

  /// Largest value across [series], or 0 when there is nothing to plot.
  static double maxValue(List<A2UiSeries> series) {
    var max = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > max) max = v;
      }
    }
    return max;
  }
}
