import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/ai_failure.dart';

void main() {
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
