/// A never-throwing, alias-aware, coercing view over a component's raw props.
///
/// Model-generated JSON is unreliable: keys arrive in the wrong case, numbers
/// arrive as strings, optional keys go missing. Every accessor here degrades to
/// a documented fallback instead of throwing, so renderer widgets can be
/// written against typed data with no defensive casting.
class A2UiProps {
  const A2UiProps(this.raw);

  final Map<String, Object?> raw;

  static const A2UiProps empty = A2UiProps(<String, Object?>{});

  /// Semantic aliases, keyed by the canonical name a component asks for.
  ///
  /// Resolution is per-requested-key, so the same alias may appear under more
  /// than one canonical key (`data` means `values` to a chart and `items` to a
  /// list) without ambiguity — each component only asks for keys it owns.
  static const Map<String, List<String>> keyAliases = {
    'title': ['name', 'label', 'heading', 'header'],
    'subtitle': ['caption', 'description', 'sub', 'summary'],
    'value': ['val', 'amount', 'number', 'metric', 'score'],
    'unit': ['units', 'suffix'],
    'labels': ['axes', 'categories', 'xLabels', 'xAxis', 'x'],
    'values': ['data', 'ys', 'y', 'points'],
    'series': ['datasets', 'lines', 'groups'],
    'items': ['rows', 'entries', 'records', 'data'],
    'children': ['components', 'elements', 'content', 'items'],
    'points': ['data', 'coordinates', 'coords', 'pairs'],
    'options': ['chips', 'choices', 'tags', 'filters'],
    'activeOption': ['active', 'selected', 'selectedOption', 'current'],
    'type': ['chartType', 'kind', 'variant'],
    'trend': ['direction', 'change'],
    'status': ['state', 'badge'],
    'columns': ['cols', 'columnCount'],
    'xLabel': ['xTitle', 'xAxisLabel'],
    'yLabel': ['yTitle', 'yAxisLabel'],
    'primaryText': ['primary', 'title', 'name', 'left'],
    'secondaryText': ['secondary', 'subtitle', 'detail', 'description'],
    'trailingValue': ['trailing', 'value', 'right', 'amount'],
    'correlation': ['r', 'pearson', 'pearsonR'],
    'min': ['minimum', 'minValue'],
    'max': ['maximum', 'maxValue'],
  };

  /// Strips case, underscores, hyphens and spaces so `x_label`, `X Label` and
  /// `XLABEL` all collapse to the same lookup token.
  static String normalizeKey(String key) {
    final buf = StringBuffer();
    for (final rune in key.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '_' || ch == '-' || ch == ' ') continue;
      buf.write(ch.toLowerCase());
    }
    return buf.toString();
  }

  /// Resolves [key] against the raw map: exact hit, then normalized hit, then
  /// each semantic alias in declaration order. Returns null when nothing
  /// matches or the matched value is null.
  Object? lookup(String key) {
    final direct = raw[key];
    if (direct != null) return direct;

    final wanted = normalizeKey(key);
    for (final entry in raw.entries) {
      if (entry.value == null) continue;
      if (normalizeKey(entry.key) == wanted) return entry.value;
    }

    for (final alias in keyAliases[key] ?? const <String>[]) {
      final aliasWanted = normalizeKey(alias);
      for (final entry in raw.entries) {
        if (entry.value == null) continue;
        if (normalizeKey(entry.key) == aliasWanted) return entry.value;
      }
    }
    return null;
  }

  bool has(String key) => lookup(key) != null;

  String? textOrNull(String key) {
    final v = lookup(key);
    if (v == null) return null;
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    return null;
  }

  String text(String key, {String or = ''}) => textOrNull(key) ?? or;

  double? numberOrNull(String key) => _toNumber(lookup(key));

  double number(String key, {double or = 0}) => numberOrNull(key) ?? or;

  int integer(String key, {int or = 0}) => numberOrNull(key)?.toInt() ?? or;

  List<String> stringList(String key) {
    final v = lookup(key);
    if (v is! List) return const [];
    return [
      for (final item in v)
        if (item != null) item.toString(),
    ];
  }

  List<double> numberList(String key) {
    final v = lookup(key);
    if (v is! List) return const [];
    return [
      for (final item in v)
        if (_toNumber(item) case final double n) n,
    ];
  }

  List<A2UiProps> objectList(String key) {
    final v = lookup(key);
    if (v is! List) return const [];
    return [
      for (final item in v)
        if (item is Map) A2UiProps(_asStringKeyed(item)),
    ];
  }

  A2UiProps object(String key) {
    final v = lookup(key);
    if (v is Map) return A2UiProps(_asStringKeyed(v));
    return empty;
  }

  static Map<String, Object?> _asStringKeyed(Map<Object?, Object?> input) => {
        for (final entry in input.entries) entry.key.toString(): entry.value,
      };

  static double? _toNumber(Object? value) {
    if (value is num) {
      if (value.isNaN || value.isInfinite) return null;
      return value.toDouble();
    }
    if (value is String) {
      final cleaned = value.replaceAll(',', '').replaceAll('%', '').trim();
      final parsed = double.tryParse(cleaned);
      if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
      return parsed;
    }
    if (value is bool) return value ? 1 : 0;
    return null;
  }
}
