import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/genui/a2ui.dart';
import 'package:repforge/screens/ai_coach_screen.dart';

Future<void> pump(
  WidgetTester tester,
  String text, {
  bool streaming = false,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CoachMessageContent(text: text, streaming: streaming),
        ),
      ),
    ));

void main() {
  const dashboard =
      '{"component":"StatCard","props":{"title":"Volume","value":"12k"}}';

  group('completed messages', () {
    testWidgets('renders a dashboard payload as widgets', (tester) async {
      await pump(tester, dashboard);
      expect(find.byType(A2UiRenderer), findsOneWidget);
      expect(find.text('Volume'), findsOneWidget);
      expect(find.textContaining('component'), findsNothing);
    });

    testWidgets('renders prose as markdown', (tester) async {
      await pump(tester, '**Nice work.** Keep going.');
      expect(find.byType(A2UiRenderer), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a fenced payload as widgets', (tester) async {
      await pump(tester, '```json\n$dashboard\n```');
      expect(find.byType(A2UiRenderer), findsOneWidget);
    });
  });

  group('streaming messages', () {
    testWidgets('shows a building indicator instead of partial JSON',
        (tester) async {
      await pump(tester, '{"component":"Stat', streaming: true);
      expect(find.textContaining('Building'), findsOneWidget);
      expect(find.textContaining('"component"'), findsNothing);
      expect(find.byType(A2UiRenderer), findsNothing);
    });

    testWidgets('still shows a complete payload as widgets mid-stream',
        (tester) async {
      await pump(tester, dashboard, streaming: true);
      expect(find.byType(A2UiRenderer), findsOneWidget);
    });

    testWidgets('streams prose live', (tester) async {
      await pump(tester, 'Your bench is trend', streaming: true);
      expect(find.textContaining('Building'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('memoization', () {
    testWidgets('does not reparse when rebuilt with the same text',
        (tester) async {
      await pump(tester, dashboard);
      final first = tester.widget<A2UiRenderer>(find.byType(A2UiRenderer)).node;
      await tester.pump();
      final second = tester.widget<A2UiRenderer>(find.byType(A2UiRenderer)).node;
      expect(identical(first, second), isTrue);
    });
  });
}
