import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/debug_log_buffer.dart';

void main() {
  group('DebugLogBuffer', () {
    late DebugLogBuffer buffer;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      originalDebugPrint = debugPrint;
      buffer = DebugLogBuffer.instance;
      buffer.clear();
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
      buffer.clear();
    });

    test('initial lines list is empty', () {
      expect(buffer.lines, isEmpty);
    });

    test('attach intercepts debugPrint and appends timestamped message', () {
      DebugLogBuffer.attach();

      bool notified = false;
      buffer.addListener(() {
        notified = true;
      });

      debugPrint('Test log message');

      expect(buffer.lines, hasLength(1));
      expect(buffer.lines.first, contains('Test log message'));
      expect(buffer.lines.first, matches(RegExp(r'^\[\d{2}:\d{2}:\d{2}\] Test log message$')));
      expect(notified, isTrue);
    });

    test('clear wipes all logs and notifies listeners', () {
      DebugLogBuffer.attach();
      debugPrint('Message 1');
      debugPrint('Message 2');
      expect(buffer.lines, hasLength(2));

      bool notified = false;
      buffer.addListener(() {
        notified = true;
      });

      buffer.clear();

      expect(buffer.lines, isEmpty);
      expect(notified, isTrue);
    });

    test('lines is unmodifiable', () {
      expect(() => buffer.lines.add('direct add'), throwsUnsupportedError);
    });
  });
}
