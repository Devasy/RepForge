import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/ai_failure.dart';

void main() {
  test('explicit HTTP status takes precedence over unrelated access text', () {
    expect(
      AiFailure.from('api key 403', statusCode: 503).message,
      contains('busy'),
    );
    expect(
      AiFailure.from('api key 401', statusCode: 429).message,
      contains('usage limit'),
    );
    expect(AiFailure.from('Gemini API key not configured').canRetry, isFalse);
    expect(AiFailure.from('model is unavailable').canRetry, isFalse);
  });

  test('access errors require settings rather than retry', () {
    final failure = AiFailure.from(
      'internal provider diagnostics',
      statusCode: 403,
    );
    expect(failure.message, contains('Settings'));
    expect(failure.message, isNot(contains('diagnostics')));
    expect(failure.canRetry, isFalse);
  });
  test('busy, quota, timeout and interruption have clear explanations', () {
    expect(AiFailure.from('high demand').message, contains('busy'));
    expect(AiFailure.from('quota').message, contains('usage limit'));
    expect(AiFailure.from('TimeoutException').message, contains('too long'));
    expect(
      AiFailure.from('software caused connection abort').message,
      contains('internet'),
    );
    expect(
      AiFailure.from('unexpected private payload').message,
      isNot(contains('private')),
    );
  });
}
