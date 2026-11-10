import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/ai/orchestration/app_checkpoint_store.dart';
import 'package:repforge/services/ai/orchestration/repforge_agents.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/program_tool_fixture.dart';
import 'repforge_orchestration_test.dart' as harness;

List<ModelEvent> proposal() => [
  ModelToolCall(
    ToolCall(
      id: 'program',
      name: 'create_training_program',
      arguments: {'program': programToolFixture()},
    ),
  ),
  ModelFinished(ModelFinishReason.toolCalls),
];
void main() {
  for (final decision in ['approve', 'decline', 'cancel']) {
    test(
      'coach $decision persists only the exact explicitly approved program',
      () async {
        final storage = MockStorageService();
        final model = harness.ScriptedModel([proposal(), harness.done()]);
        final host = RepForgeAgents(
          model: model,
          store: AppCheckpointStore(storage),
        );
        final (conversations, run) = await harness.session(
          storage,
          host,
          kind: 'coach',
        );
        addTearDown(run.dispose);
        await conversations.appendMessage(
          ChatMessage(
            role: 'user',
            text: 'Create a program using the context we already discussed',
          ),
        );
        await run.send(
          'Create a program using the context we already discussed',
        );
        expect(run.pendingInput?.request.kind, 'tool_approval');
        expect(await storage.getAllTrainingPrograms(), isEmpty);
        expect(
          model.requests.first.messages.any(
            (m) => m.role == 'user' && m.text.contains('Review my routine'),
          ),
          isTrue,
        );
        final input = run.pendingInput!;
        if (decision == 'cancel') {
          await run.cancel();
        } else {
          await run.submit(input, decision == 'approve');
        }
        expect(
          await storage.getAllTrainingPrograms(),
          hasLength(decision == 'approve' ? 1 : 0),
        );
        expect(await storage.getSetting('programs.followedId'), isNull);
        if (decision == 'approve') {
          expect(await run.submit(input, true), isFalse);
          final plan = (await storage.getAllTrainingPrograms()).single;
          expect(plan.weeks.first.days.first.exercises.single.restSeconds, 90);
        }
      },
    );
  }
  test(
    'approved create then failed model request can retry without duplicate program',
    () async {
      final storage = MockStorageService();
      final model = harness.ScriptedModel([
        proposal(),
        harness.done(),
      ], failAt: 2);
      final host = RepForgeAgents(
        model: model,
        store: AppCheckpointStore(storage),
      );
      final (_, run) = await harness.session(storage, host, kind: 'coach');
      addTearDown(run.dispose);
      await run.send('Create my program');
      await run.submit(run.pendingInput!, true);
      expect(run.state.status, RunStatus.failed);
      expect(await storage.getAllTrainingPrograms(), hasLength(1));
      await run.retry();
      expect(run.state.status, RunStatus.completed);
      expect(await storage.getAllTrainingPrograms(), hasLength(1));
    },
  );
  for (final decision in ['approve', 'decline', 'cancel']) {
    test('following a program requires separate $decision decision', () async {
      final storage = MockStorageService();
      await storage.saveTrainingProgram(
        TrainingProgram.fromJson({
          ...programToolFixture(),
          'id': 'saved-plan',
          'phases': [],
        }),
      );
      final model = harness.ScriptedModel([
        [
          ModelToolCall(
            ToolCall(
              id: 'follow',
              name: 'follow_training_program',
              arguments: {
                'program_id': 'saved-plan',
                'expected_followed_program_id': null,
              },
            ),
          ),
          ModelFinished(ModelFinishReason.toolCalls),
        ],
        harness.done(),
      ]);
      final host = RepForgeAgents(
        model: model,
        store: AppCheckpointStore(storage),
      );
      final (_, run) = await harness.session(storage, host, kind: 'coach');
      addTearDown(run.dispose);
      await run.send('Follow my saved plan');
      expect(run.pendingInput?.request.kind, 'tool_approval');
      expect(await storage.getSetting('programs.followedId'), isNull);
      if (decision == 'cancel') {
        await run.cancel();
      } else {
        await run.submit(run.pendingInput!, decision == 'approve');
      }
      expect(
        await storage.getSetting('programs.followedId'),
        decision == 'approve' ? 'saved-plan' : null,
      );
      expect(await storage.getAllTrainingPrograms(), hasLength(1));
    });
  }
}
