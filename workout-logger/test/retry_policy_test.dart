// Unit tests for RetryPolicy

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:repforge/services/ai/retry_policy.dart';

void main() {
  group('RetryPolicy', () {
    test('parseRetryAfter returns correct durations', () {
      const policy = RetryPolicy(maxWait: Duration(seconds: 60));

      // Seconds parsing
      expect(
        policy.parseRetryAfter({'retry-after': '12'}),
        const Duration(seconds: 12),
      );
      expect(
        policy.parseRetryAfter({'Retry-After': '5'}),
        const Duration(seconds: 5),
      );

      // Capped at maxWait
      expect(
        policy.parseRetryAfter({'retry-after': '120'}),
        const Duration(seconds: 60),
      );

      // Empty or missing
      expect(policy.parseRetryAfter({}), null);
      expect(policy.parseRetryAfter({'retry-after': ''}), null);
      expect(policy.parseRetryAfter({'retry-after': 'abc'}), null);
    });

    test('backoff calculates exponential doubling capped at maxBackoff', () {
      const policy = RetryPolicy(maxBackoff: Duration(seconds: 8));

      expect(policy.backoff(0), const Duration(seconds: 1));
      expect(policy.backoff(1), const Duration(seconds: 2));
      expect(policy.backoff(2), const Duration(seconds: 4));
      expect(policy.backoff(3), const Duration(seconds: 8));
      expect(policy.backoff(4), const Duration(seconds: 8));
    });

    test('execute succeeds immediately when status is 200', () async {
      const policy = RetryPolicy(maxRetries: 2);
      int calls = 0;

      final response = await policy.execute(
        makeRequest: () async {
          calls++;
          return http.StreamedResponse(
            Stream.value([1, 2, 3]),
            200,
          );
        },
      );

      expect(calls, 1);
      expect(response.statusCode, 200);
    });

    test('execute retries on 429 then succeeds', () async {
      const policy = RetryPolicy(
        maxRetries: 2,
        // Shorten backoff for fast testing
        maxBackoff: Duration(milliseconds: 1),
      );
      int calls = 0;
      final statuses = <RetryStatus>[];

      final response = await policy.execute(
        makeRequest: () async {
          calls++;
          if (calls == 1) {
            return http.StreamedResponse(
              Stream.value(<int>[]),
              429,
              headers: {'retry-after': '0'},
            );
          }
          return http.StreamedResponse(Stream.value([100]), 200);
        },
        onStatus: statuses.add,
      );

      expect(calls, 2);
      expect(response.statusCode, 200);
      expect(statuses, hasLength(3)); // Waiting, Attempting, Success
      expect(statuses[0], isA<RetryWaiting>());
      expect((statuses[0] as RetryWaiting).attempt, 1);
      expect(statuses[1], isA<RetryAttempting>());
      expect(statuses[2], isA<RetrySuccess>());
    });

    test('execute fails immediately on non-retryable 400 error', () async {
      const policy = RetryPolicy(maxRetries: 2);
      int calls = 0;

      expect(
        () => policy.execute(
          makeRequest: () async {
            calls++;
            return http.StreamedResponse(
              Stream.value(<int>[]),
              400,
            );
          },
        ),
        throwsException,
      );
      expect(calls, 1);
    });

    test('execute throws Exception after exhausting retries', () async {
      const policy = RetryPolicy(
        maxRetries: 2,
        maxWait: Duration(milliseconds: 10),
        pollInterval: Duration(milliseconds: 5),
        maxBackoff: Duration(milliseconds: 1),
      );
      int calls = 0;

      await expectLater(
        policy.execute(
          makeRequest: () async {
            calls++;
            return http.StreamedResponse(
              Stream.value(<int>[]),
              429,
              headers: {'retry-after': '0'},
            );
          },
        ),
        throwsException,
      );
      expect(calls, greaterThanOrEqualTo(3));
    });
  });
}
