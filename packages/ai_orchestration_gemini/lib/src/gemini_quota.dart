import 'dart:convert';

class GeminiQuota {
  const GeminiQuota(this.metrics, this.ids, this.zeroLimit);
  final List<String> metrics;
  final List<String> ids;
  final bool zeroLimit;

  bool get searchOnly => metrics.isNotEmpty && metrics.every(_searchMetric);
  bool get daily => [...metrics, ...ids].any((value) {
    final text = value.toLowerCase();
    return text.contains('per_day') || text.contains('perday');
  });
  String get kind => searchOnly
      ? 'search'
      : metrics.any((value) => value.contains('generate_'))
      ? 'generation'
      : 'unknown';

  static bool _searchMetric(String value) {
    final text = value.toLowerCase();
    return text.contains('grounding') ||
        text.contains('grounded') ||
        text.contains('search');
  }

  static GeminiQuota parse(String body) {
    final metrics = <String>[];
    final ids = <String>[];
    var zero = false;
    try {
      final data = jsonDecode(body);
      final error = data is Map ? data['error'] : null;
      final details = error is Map ? error['details'] : null;
      for (final detail in details is List ? details : const []) {
        if (detail is! Map ||
            detail['@type'] != 'type.googleapis.com/google.rpc.QuotaFailure') {
          continue;
        }
        final violations = detail['violations'];
        for (final violation in violations is List ? violations : const []) {
          if (violation is! Map) continue;
          final metric = _identifier(violation['quotaMetric']);
          final id = _identifier(violation['quotaId']);
          metrics.add(metric ?? 'unknown');
          if (id != null) ids.add(id);
          if (num.tryParse('${violation['quotaValue']}') == 0) zero = true;
        }
      }
    } catch (_) {
      // Malformed provider diagnostics must not obscure the original failure.
    }
    return GeminiQuota(
      List.unmodifiable(metrics),
      List.unmodifiable(ids),
      zero,
    );
  }

  static String? _identifier(Object? value) =>
      value is String && RegExp(r'^[a-zA-Z0-9_./:-]{1,180}$').hasMatch(value)
      ? value
      : null;
}
