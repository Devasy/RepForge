import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/agent_run_controls.dart';
import 'package:repforge/services/ai/orchestration/agent_change_review.dart';
import 'dart:async';

void main() {
  testWidgets(
    'keeps the proposal on screen between approvals with accurate counters',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final first = ToolCall(
        id: 'one',
        name: 'create_routine',
        arguments: {'name': 'First'},
      );
      final second = ToolCall(
        id: 'two',
        name: 'update_routine',
        arguments: {'routine_name': 'Second'},
      );
      PendingAgentInput target(ToolCall call) => PendingAgentInput(
        threadId: 'coach',
        runId: 'run',
        revision: 3,
        request: InputRequest(
          callId: call.id,
          kind: 'tool_approval',
          responseSchema: ValueSchema.boolean(),
        ),
      );
      final response = Completer<bool>();
      var submissions = 0;
      Future<void> render(
        AgentChangeStatus firstStatus,
        AgentChangeStatus secondStatus,
        PendingAgentInput? pending,
      ) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentRunControls(
              pending: pending,
              needsRecovery: false,
              isRunning: pending == null,
              review: AgentChangeReview(
                id: 'batch',
                position: secondStatus == AgentChangeStatus.review ? 2 : 1,
                changes: [
                  AgentChange(first, firstStatus),
                  AgentChange(second, secondStatus),
                ],
              ),
              onStop: () => Future<void>.value(),
              onSubmit: (_, _) {
                submissions++;
                return response.future;
              },
            ),
          ),
        ),
      );
      await render(
        AgentChangeStatus.review,
        AgentChangeStatus.waiting,
        target(first),
      );
      expect(find.text('Review changes 1/2'), findsOneWidget);
      expect(find.textContaining('Second'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.tap(find.text('Approve'));
      expect(submissions, 1);
      await render(AgentChangeStatus.applying, AgentChangeStatus.waiting, null);
      expect(find.text('Review changes 1/2'), findsOneWidget);
      expect(find.textContaining('Second'), findsOneWidget);
      expect(find.text('Applying…'), findsOneWidget);
      response.complete(true);
      await tester.pump();
      await render(
        AgentChangeStatus.applied,
        AgentChangeStatus.review,
        target(second),
      );
      expect(find.text('Review changes 2/2'), findsOneWidget);
      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );

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
              onStop: () => Future<void>.value(),
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
            onStop: () {
              stopped = true;
              return Future<void>.value();
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
