import 'dart:convert';
import 'package:ai_orchestration_gemini/src/gemini_quota.dart';
import 'package:test/test.dart';

String quotaBody(List<Map<String, Object?>> violations) => jsonEncode({
  'error': {
    'message': 'private request details',
    'details': [
      {
        '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
        'violations': violations,
      },
    ],
  },
});

void main() {
  test('search-only quota is distinguished from generation and mixed limits', () {
    final search = {
      'quotaMetric': 'generativelanguage.googleapis.com/grounding_requests',
      'quotaId': 'GroundingRequestsPerDay',
      'quotaValue': '0',
    };
    final generation = {
      'quotaMetric':
          'generativelanguage.googleapis.com/generate_requests_per_model_per_day',
      'quotaId': 'GenerateRequestsPerDay',
    };
    final parsed = GeminiQuota.parse(quotaBody([search]));
    expect(parsed.searchOnly, isTrue);
    expect(parsed.kind, 'search');
    expect(parsed.zeroLimit, isTrue);
    expect(parsed.daily, isTrue);
    expect(GeminiQuota.parse(quotaBody([generation])).kind, 'generation');
    expect(
      GeminiQuota.parse(quotaBody([search, generation])).searchOnly,
      isFalse,
    );
    expect(GeminiQuota.parse(quotaBody([search, {}])).searchOnly, isFalse);
  });

  test(
    'malformed and unstructured quota errors do not infer search limits',
    () {
      for (final body in [
        'not JSON',
        '{}',
        'null',
        '{"error":null}',
        '{"error":{"details":"invalid"}}',
      ]) {
        final quota = GeminiQuota.parse(body);
        expect(quota.searchOnly, isFalse);
        expect(quota.kind, 'unknown');
        expect(quota.zeroLimit, isFalse);
      }
      final quota = GeminiQuota.parse(
        quotaBody([
          {
            'quotaMetric': 'private user text with spaces',
            'quotaId': 'private\nkey',
          },
        ]),
      );
      expect(quota.metrics, ['unknown']);
      expect(quota.ids, isEmpty);
    },
  );
}
