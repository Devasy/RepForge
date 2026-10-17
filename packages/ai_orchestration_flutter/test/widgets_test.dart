import 'dart:async';
import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';
import '../example/main.dart' as demo;

void main() {
  testWidgets(
    'example restores its approval after closing and reopening the panel',
    (tester) async {
      await tester.pumpWidget(const demo.BridgeExampleApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('Increase the demo counter by one.'), findsOneWidget);
      await tester.tap(find.text('Hide panel'));
      await tester.pumpAndSettle();
      expect(find.text('Increase the demo counter by one.'), findsNothing);
      await tester.tap(find.text('Show panel'));
      await tester.pumpAndSettle();
      expect(find.text('Increase the demo counter by one.'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Count: 1'), findsOneWidget);
      expect(find.text('Status: completed'), findsOneWidget);
    },
  );

  testWidgets(
    'run builder observes state without a state-management dependency',
    (tester) async {
      final controller = AgentController(
        runtime: AgentRuntime(store: MemoryCheckpointStore()),
        workflow: counterWorkflow(),
        threadId: 'counter',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AgentRunBuilder<int>(
            controller: controller,
            builder: (_, state) => Text('Count: ${state.data ?? 0}'),
          ),
        ),
      );
      expect(find.text('Count: 0'), findsOneWidget);
      await controller.start();
      await tester.pumpAndSettle();
      expect(find.text('Count: 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.isDisposed, false);
    },
  );

  testWidgets(
    'artifact registry validates type, version and payload before rendering',
    (tester) async {
      var renders = 0;
      ArtifactRenderIssue? issue;
      final registry = ArtifactRegistry(
        [
          ArtifactRenderer(
            type: 'expense.summary',
            version: 2,
            payloadSchema: ValueSchema.object(
              properties: {'total': ValueSchema.integer()},
              required: ['total'],
            ),
            builder: (_, artifact) {
              renders++;
              return Text('Total: ${artifact.payload['total']}');
            },
          ),
        ],
        fallbackBuilder: (_, _, failure) {
          issue = failure;
          return const Text('Unavailable');
        },
      );
      Future<void> show(Artifact artifact) => tester.pumpWidget(
        MaterialApp(
          home: AgentArtifactView(artifact: artifact, registry: registry),
        ),
      );
      await show(
        Artifact(
          id: 'report',
          type: 'expense.summary',
          version: 2,
          payload: {'total': 42},
        ),
      );
      expect(find.text('Total: 42'), findsOneWidget);
      await show(
        Artifact(
          id: 'report',
          type: 'expense.summary',
          version: 2,
          payload: {'total': 'not a number'},
        ),
      );
      expect(find.text('Unavailable'), findsOneWidget);
      expect(issue, ArtifactRenderIssue.invalidPayload);
      await show(
        Artifact(
          id: 'report',
          type: 'expense.summary',
          version: 1,
          payload: {'total': 42},
        ),
      );
      expect(issue, ArtifactRenderIssue.unsupportedTypeOrVersion);
      expect(renders, 1);
    },
  );

  test('artifact registration rejects duplicate type/version keys', () {
    final renderer = ArtifactRenderer(
      type: 'same',
      payloadSchema: ValueSchema.object(),
      builder: (_, _) => const SizedBox.shrink(),
    );
    expect(() => ArtifactRegistry([renderer, renderer]), throwsArgumentError);
  });

  testWidgets('approval buttons submit only the explicit selection', (
    tester,
  ) async {
    var writes = 0;
    final model = ScriptedModel([
      [
        ModelToolCall(ToolCall(id: 'write', name: 'save')),
        ModelFinished(ModelFinishReason.toolCalls),
      ],
      [const ModelText('Saved'), ModelFinished(ModelFinishReason.stop)],
    ]);
    final workflow = chatWorkflow(
      id: 'chat',
      modelId: 'demo',
      systemPrompt: 'Test',
      tools: ToolRegistry([
        CallbackTool('save', (_) {
          writes++;
          return ToolSuccess({'saved': true});
        }, effect: ToolEffect.write),
      ]),
      authorize: (_, _) => ToolAuthorization.requireApproval,
    );
    final controller = AgentController.chat(
      runtime: AgentRuntime(store: MemoryCheckpointStore(), model: model),
      workflow: workflow,
      threadId: 'chat',
    );
    addTearDown(controller.dispose);
    await controller.start(input: {'text': 'Save task'});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AgentRunBuilder<ChatState>(
                controller: controller,
                builder: (_, state) => Text(state.status?.name ?? 'idle'),
              ),
              AgentInputBuilder<ChatState>(
                controller: controller,
                builder: (_, pending, submit, busy) => AgentApprovalPrompt(
                  pending: pending,
                  onSubmit: submit,
                  isSubmitting: busy,
                  details: const Text('Save this task?'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save this task?'), findsOneWidget);
    expect(writes, 0);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('completed'), findsOneWidget);
    expect(find.text('Save this task?'), findsNothing);
  });

  testWidgets(
    'approval helper disables repeated taps and shows rejected submission',
    (tester) async {
      final response = Completer<bool>();
      final submitted = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentApprovalPrompt(
              pending: _approval(),
              details: const Text('Update item'),
              onSubmit: (value) {
                submitted.add(value);
                return response.future;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(submitted, [false]);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        null,
      );
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        null,
      );
      await tester.tap(find.text('Approve'));
      await tester.pump();
      expect(submitted, [false]);
      response.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.text('The response was not accepted. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'old async response does not mark a replacement question as failed',
    (tester) async {
      final response = Completer<bool>();
      final first = _approval(id: 'first');
      final second = _approval(id: 'second');
      Future<void> show(PendingAgentInput pending) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentApprovalPrompt(
              pending: pending,
              details: const Text('Action'),
              onSubmit: (_) => response.future,
            ),
          ),
        ),
      );
      await show(first);
      await tester.tap(find.text('Approve'));
      await tester.pump();
      await show(second);
      response.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.text('The response was not accepted. Please try again.'),
        findsNothing,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'pending callback can finish after the approval widget is removed',
    (tester) async {
      final response = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: AgentApprovalPrompt(
            pending: _approval(),
            details: const Text('Action'),
            onSubmit: (_) => response.future,
          ),
        ),
      );
      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(true);
      await tester.pump();
      expect(tester.takeException(), null);
    },
  );

  testWidgets('input builder captures the original interrupt identity', (
    tester,
  ) async {
    final controller = AgentController(
      runtime: AgentRuntime(store: MemoryCheckpointStore()),
      workflow: questionWorkflow(),
      threadId: 'q',
    );
    addTearDown(controller.dispose);
    AgentInputSubmit? captured;
    await controller.start();
    await tester.pumpWidget(
      MaterialApp(
        home: AgentInputBuilder<int>(
          controller: controller,
          builder: (_, pending, submit, busy) {
            captured ??= submit;
            return Text(pending.request.id);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = controller.state.pendingInput!.request.id;
    expect(await captured!('First'), true);
    await tester.pumpAndSettle();
    final second = controller.state.pendingInput!.request.id;
    expect(second, isNot(first));
    expect(await captured!('Old callback'), false);
    expect(controller.state.pendingInput!.request.id, second);
    expect(find.text(second), findsOneWidget);
  });
}

PendingAgentInput _approval({String id = 'approval'}) => PendingAgentInput(
  threadId: 'thread',
  runId: 'run',
  revision: 1,
  request: InputRequest(
    id: id,
    kind: 'tool_approval',
    responseSchema: ValueSchema.boolean(),
    payload: {'tool': 'save'},
  ),
);
