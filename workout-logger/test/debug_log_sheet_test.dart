import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/debug_log_sheet.dart';
import 'package:repforge/services/debug_log_buffer.dart';

void main() {
  testWidgets('logs filter, pause, resume, copy and clear on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final buffer = DebugLogBuffer.instance;
    buffer.clear();
    addTearDown(buffer.clear);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    buffer.write('Other message');
    buffer.write('[AI] request_failed code=model_timeout');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DebugLogSheet(appVersion: '2.1.10-test')),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Other message'), findsOneWidget);
    await tester.tap(find.text('AI only'));
    await tester.pump();
    expect(find.textContaining('Other message'), findsNothing);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    buffer.write('[AI] fallback');
    await tester.pump();
    expect(find.textContaining('[AI] fallback'), findsNothing);
    await tester.tap(find.text('Copy AI logs'));
    await tester.pump();
    expect(copied, contains('2.1.10-test'));
    expect(copied, contains('model_timeout'));
    expect(copied, isNot(contains('Other message')));
    expect(copied, isNot(contains('fallback')));
    expect(find.text('Logs copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Logs copied'), findsNothing);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.textContaining('[AI] fallback'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.textContaining('No logs yet'), findsOneWidget);
    expect(buffer.lines, isEmpty);
    expect(tester.takeException(), null);
  });

  testWidgets(
    'copy feedback is inside the modal and paused logs redact late secrets',
    (tester) async {
      final buffer = DebugLogBuffer.instance;
      buffer.clear();
      addTearDown(buffer.clear);
      String? copied;
      var failCopy = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (failCopy) throw PlatformException(code: 'unavailable');
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      buffer.write('late-sheet-secret');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const DebugLogSheet(),
                ),
                child: const Text('Open logs'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open logs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pump();
      buffer.protect('late-sheet-secret');
      await tester.pump();
      expect(find.textContaining('late-sheet-secret'), findsNothing);
      expect(find.textContaining('[redacted]'), findsOneWidget);
      for (final failed in [false, true]) {
        failCopy = failed;
        await tester.tap(find.text('Copy All'));
        await tester.pump();
        final message = failed
            ? 'Could not copy logs. Please try again.'
            : 'Logs copied';
        expect(
          find.descendant(
            of: find.byType(DebugLogSheet),
            matching: find.text(message),
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        await tester.pump(const Duration(seconds: 3));
        expect(find.text(message), findsNothing);
      }
      expect(copied, isNot(contains('late-sheet-secret')));
      await tester.tap(find.byTooltip('Close logs'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
    },
  );

  testWidgets(
    'new logs arriving during build do not trigger setState during build',
    (tester) async {
      final buffer = DebugLogBuffer.instance;
      buffer.clear();
      addTearDown(buffer.clear);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: buffer,
              builder: (context, _) => Builder(
                builder: (_) {
                  buffer.write('Built');
                  return const Text('Ready');
                },
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
