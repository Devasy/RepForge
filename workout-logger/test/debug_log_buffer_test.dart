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

    test('repeated attachment captures each message only once', () {
      DebugLogBuffer.attach();
      DebugLogBuffer.attach();
      debugPrint('Once');
      expect(buffer.lines, hasLength(1));
    });

    test('redacts protected API keys and bounds line and buffer sizes', () {
      buffer.protect('fixture-secret-key');
      buffer.write('[AI] https://example.test?key=fixture-secret-key&alt=sse');
      expect(buffer.lines.join(), isNot(contains('fixture-secret-key')));
      expect(buffer.lines.join(), contains('[redacted]'));
      buffer.write('x' * 5000);
      expect(buffer.lines.last.length, lessThan(2100));
      for (var i = 0; i < 600; i++) {
        buffer.write('Line $i');
      }
      expect(buffer.lines, hasLength(500));
      expect(buffer.lines.last, contains('Line 599'));
    });

    test('initial lines list is empty', () {
      expect(buffer.lines, isEmpty);
    });

    test(
      'new protected secrets redact existing lines and notify once',
      () async {
        buffer.write('late-buffer-secret');
        await Future<void>.delayed(Duration.zero);
        var notifications = 0;
        void changed() => notifications++;
        buffer.addListener(changed);
        addTearDown(() => buffer.removeListener(changed));
        buffer.protect('late-buffer-secret');
        await Future<void>.delayed(Duration.zero);
        expect(notifications, 1);
        expect(buffer.lines.join(), isNot(contains('late-buffer-secret')));
        buffer.protect('late-buffer-secret');
        buffer.protect('  ');
        await Future<void>.delayed(Duration.zero);
        expect(notifications, 1);
      },
    );

    test(
      'attach intercepts debugPrint and appends timestamped message',
      () async {
        DebugLogBuffer.attach();

        bool notified = false;
        buffer.addListener(() {
          notified = true;
        });

        debugPrint('Test log message');
        await Future<void>.delayed(Duration.zero);

        expect(buffer.lines, hasLength(1));
        expect(buffer.lines.first, contains('Test log message'));
        expect(
          buffer.lines.first,
          matches(RegExp(r'^\[\d{2}:\d{2}:\d{2}\] Test log message$')),
        );
        expect(notified, isTrue);
      },
    );

    test('clear wipes all logs and notifies listeners', () async {
      DebugLogBuffer.attach();
      debugPrint('Message 1');
      debugPrint('Message 2');
      expect(buffer.lines, hasLength(2));

      bool notified = false;
      buffer.addListener(() {
        notified = true;
      });

      buffer.clear();
      await Future<void>.delayed(Duration.zero);

      expect(buffer.lines, isEmpty);
      expect(notified, isTrue);
    });

    test('lines is unmodifiable', () {
      expect(() => buffer.lines.add('direct add'), throwsUnsupportedError);
    });
  });
}
