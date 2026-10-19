import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/agent_run_controls.dart';

void main() {
  testWidgets(
    'shows the proposed change and submits only an explicit approval',
    (tester) async {
      final pending = PendingAgentInput(
        threadId: 'coach:1',
        runId: 'run',
        revision: 3,
        request: InputRequest(
          kind: 'tool_approval',
          responseSchema: ValueSchema.boolean(),
          payload: {
            'tool': 'update_routine',
            'arguments': {
              'routine_name': 'Push Day',
              'add_exercise_names': ['Bench press'],
            },
          },
        ),
      );
      final responses = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentRunControls(
              pending: pending,
              needsRecovery: false,
              onStop: () async {},
              onSubmit: (target, response) async {
                expect(identical(target, pending), true);
                responses.add(response);
                return true;
              },
            ),
          ),
        ),
      );
      expect(find.text('Update routine'), findsOneWidget);
      expect(find.textContaining('Push Day'), findsOneWidget);
      expect(responses, isEmpty);
      await tester.tap(find.text('Approve'));
      await tester.pump();
      expect(responses, [true]);
    },
  );

  testWidgets('offers an explicit stop for interrupted running work', (
    tester,
  ) async {
    var stopped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentRunControls(
            pending: null,
            needsRecovery: true,
            onSubmit: (_, _) async => false,
            onStop: () async {
              stopped = true;
            },
          ),
        ),
      ),
    );
    expect(stopped, false);
    await tester.tap(find.text('Stop interrupted reply'));
    await tester.pump();
    expect(stopped, true);
  });
}
