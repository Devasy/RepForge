import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/widgets/agent_run_controls.dart';
import 'package:repforge/services/ai/orchestration/agent_change_review.dart';
import 'test_utils/program_tool_fixture.dart';

void main() {
  testWidgets(
    'program approval displays full readable prescription before approval',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final call = ToolCall(
        id: 'p',
        name: 'create_training_program',
        arguments: {'program': programToolFixture()},
      );
      final pending = PendingAgentInput(
        threadId: 'c',
        runId: 'r',
        revision: 1,
        request: InputRequest(
          callId: 'p',
          kind: 'tool_approval',
          responseSchema: ValueSchema.boolean(),
        ),
      );
      var applied = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentRunControls(
              pending: pending,
              review: AgentChangeReview(
                id: 'review',
                position: 1,
                changes: [AgentChange(call, AgentChangeStatus.review)],
              ),
              needsRecovery: false,
              onSubmit: (_, value) async {
                applied = value == true;
                return true;
              },
              onStop: () => Future<void>.value(),
            ),
          ),
        ),
      );
      expect(find.text('Create training program'), findsOneWidget);
      expect(find.text('Two week strength plan'), findsOneWidget);
      expect(find.textContaining('3 sets'), findsWidgets);
      expect(find.textContaining('8–10 reps'), findsWidgets);
      expect(find.textContaining('90s rest'), findsWidgets);
      expect(find.textContaining('Tempo: 2-1-1'), findsWidgets);
      expect(applied, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
