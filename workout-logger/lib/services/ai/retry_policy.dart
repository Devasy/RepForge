// retry_policy.dart — Reusable HTTP retry logic with Retry-After parsing.
//
// Handles 429 (rate limit) and 5xx (server overload) responses with:
// - Retry-After header parsing (seconds or HTTP-date)
// - Exponential backoff fallback: 1s → 2s → 4s → 8s (capped at maxBackoff)
// - Wait-and-resume: after exhausting fast retries, polls every pollInterval
//   until maxWait is reached
// - Status callback so the UI can show countdown / retry state

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Whether an HTTP status code is worth retrying.
bool isRetryableStatus(int code) => code == 429 || (code >= 500 && code < 600);

/// Extract a human-readable error message from a Gemini error body.
/// Falls back to a generic "request failed (HTTP $code)" if unparseable.
String parseErrorMessage(int code, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is Map) {
      final msg = (decoded['error'] as Map)['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
  } catch (_) {
    // Body wasn't JSON — fall through.
  }
  return 'request failed (HTTP $code).';
}

/// Status updates emitted during retry attempts so the UI can show feedback.
sealed class RetryStatus {
  const RetryStatus();
}

/// About to wait before retrying.
class RetryWaiting extends RetryStatus {
  final Duration waitDuration;
  final String reason;
  final int attempt;
  final int maxAttempts;
  const RetryWaiting(this.waitDuration, this.reason, this.attempt, this.maxAttempts);

  @override
  String toString() =>
      'RetryWaiting(${waitDuration.inSeconds}s, "$reason", $attempt/$maxAttempts)';
}

/// A retry attempt is starting.
class RetryAttempting extends RetryStatus {
  final int attempt;
  final int maxAttempts;
  const RetryAttempting(this.attempt, this.maxAttempts);

  @override
  String toString() => 'RetryAttempting($attempt/$maxAttempts)';
}

/// The request succeeded.
class RetrySuccess extends RetryStatus {
  final http.StreamedResponse response;
  const RetrySuccess(this.response);
}

/// All retries exhausted.
class RetryExhausted extends RetryStatus {
  final String lastError;
  final int statusCode;
  const RetryExhausted(this.lastError, this.statusCode);

  @override
  String toString() => 'RetryExhausted($statusCode, "$lastError")';
}

/// Configurable retry policy for HTTP requests to the Gemini API.
///
/// Designed for free-tier API keys where rate limits are tight. More patient
/// than typical retry policies: up to [maxRetries] fast retries with backoff,
/// then a slow-poll phase up to [maxWait] total elapsed time.
class RetryPolicy {
  /// Maximum number of immediate retry attempts (after the first failure).
  final int maxRetries;

  /// Maximum total time to spend retrying (including slow-poll phase).
  final Duration maxWait;

  /// Maximum backoff duration for a single retry.
  final Duration maxBackoff;

  /// Interval between slow-poll attempts after fast retries are exhausted.
  final Duration pollInterval;

  const RetryPolicy({
    this.maxRetries = 4,
    this.maxWait = const Duration(seconds: 120),
    this.maxBackoff = const Duration(seconds: 30),
    this.pollInterval = const Duration(seconds: 30),
  });

  /// Parse the `Retry-After` header from an HTTP response.
  ///
  /// Returns a [Duration] if the header is present and parseable (either as
  /// seconds or an HTTP-date). Returns `null` if missing or unparseable.
  Duration? parseRetryAfter(Map<String, String> headers) {
    final value = headers['retry-after'] ?? headers['Retry-After'];
    if (value == null || value.isEmpty) return null;

    // Try as seconds first (most common for Gemini 429s).
    final seconds = int.tryParse(value);
    if (seconds != null) {
      return Duration(seconds: math.min(seconds, maxWait.inSeconds));
    }

    // Try as HTTP-date.
    try {
      final date = _parseHttpDate(value);
      final diff = date.difference(DateTime.now());
      if (diff.isNegative) return Duration.zero;
      return diff > maxWait ? maxWait : diff;
    } catch (_) {
      return null;
    }
  }

  /// Exponential backoff: 1s, 2s, 4s, 8s… capped at [maxBackoff].
  Duration backoff(int attempt) {
    final ms = 1000 * (1 << attempt);
    return Duration(milliseconds: math.min(ms, maxBackoff.inMilliseconds));
  }

  /// Execute an HTTP request with retry logic.
  ///
  /// [makeRequest] creates a fresh request (must be callable multiple times).
  /// [onStatus] receives retry status events for UI feedback.
  ///
  /// Returns the successful [http.StreamedResponse], or throws on exhaustion.
  Future<http.StreamedResponse> execute({
    required Future<http.StreamedResponse> Function() makeRequest,
    void Function(RetryStatus status)? onStatus,
  }) async {
    final stopwatch = Stopwatch()..start();

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        onStatus?.call(RetryAttempting(attempt, maxRetries));
      }

      final response = await makeRequest();

      if (response.statusCode == 200) {
        onStatus?.call(RetrySuccess(response));
        return response;
      }

      final body = await response.stream.bytesToString();

      if (!isRetryableStatus(response.statusCode)) {
        // Non-retryable error — fail immediately.
        throw Exception(parseErrorMessage(response.statusCode, body));
      }

      if (attempt < maxRetries) {
        // Determine wait duration: Retry-After header > backoff.
        final retryAfter = parseRetryAfter(response.headers);
        final wait = retryAfter ?? backoff(attempt);
        final reason = response.statusCode == 429
            ? 'Rate limit reached'
            : 'Server busy (${response.statusCode})';

        onStatus?.call(RetryWaiting(wait, reason, attempt + 1, maxRetries));
        await Future<void>.delayed(wait);
      } else {
        // Fast retries exhausted. Enter slow-poll phase if we have time left.
        while (stopwatch.elapsed < maxWait) {
          final remaining = maxWait - stopwatch.elapsed;
          final wait = remaining < pollInterval ? remaining : pollInterval;
          final reason = response.statusCode == 429
              ? 'Rate limit — waiting for next available slot'
              : 'Server busy — waiting to retry';

          onStatus?.call(RetryWaiting(wait, reason, attempt + 1, maxRetries));
          await Future<void>.delayed(wait);

          // Try again.
          final retryResponse = await makeRequest();
          if (retryResponse.statusCode == 200) {
            onStatus?.call(RetrySuccess(retryResponse));
            return retryResponse;
          }

          // Drain the failed response body.
          await retryResponse.stream.bytesToString();
          if (!isRetryableStatus(retryResponse.statusCode)) {
            final errBody = body; // already drained above
            throw Exception(
                parseErrorMessage(retryResponse.statusCode, errBody));
          }
        }

        // Completely exhausted.
        final error = parseErrorMessage(response.statusCode, body);
        onStatus?.call(RetryExhausted(error, response.statusCode));
        throw Exception(
          'API unavailable after ${stopwatch.elapsed.inSeconds}s of retrying: $error',
        );
      }
    }

    // Should be unreachable, but satisfy the analyzer.
    throw StateError('Retry loop exited unexpectedly');
  }

  /// Parse a subset of HTTP-date formats (RFC 7231 §7.1.1.1).
  DateTime _parseHttpDate(String value) {
    // Try the preferred IMF-fixdate: Sun, 06 Nov 1994 08:49:37 GMT
    return DateTime.parse(value);
  }
}
