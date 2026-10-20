import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/ai/orchestration/app_checkpoint_store.dart';
import 'package:repforge/services/ai/orchestration/repforge_agents.dart';
import 'package:repforge/services/ai/orchestration/agent_change_review.dart';
import 'package:repforge/services/ai/sql_query_service.dart';
import 'package:repforge/services/backup_codec.dart';
import 'package:repforge/services/interfaces/storage_service_interface.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/viewmodels/routine_optimizer_view_model.dart';
import 'package:repforge/viewmodels/ai_coach_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_utils/mock_storage_service.dart';

class ScriptedModel implements ModelProvider {
  final List<List<ModelEvent>> replies;
  final List<ModelRequest> requests = [];
  final int? failAt;
  ScriptedModel(this.replies, {this.failAt});
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    if (requests.length == failAt) {
      throw const OrchestrationException(
        'model_transport',
        'Gemini is temporarily unavailable.',
      );
    }
    yield* Stream.fromIterable(replies.removeAt(0));
  }
}

List<ModelEvent> question() => [
  ModelToolCall(
    ToolCall(
      id: 'question-1',
      name: 'ask_user_questions',
      arguments: {
        'preamble': 'One question before changing your routine.',
        'questions': [
          {
            'question': 'Your goal?',
            'options': ['Strength', 'Hypertrophy'],
          },
        ],
      },
    ),
  ),
  ModelFinished(ModelFinishReason.toolCalls),
];
List<ModelEvent> write() => [
  ModelToolCall(
    ToolCall(
      id: 'write-1',
      name: 'create_routine',
      arguments: {'name': 'Reviewed routine', 'exercise_names': <String>[]},
    ),
  ),
  ModelFinished(ModelFinishReason.toolCalls),
];
List<ModelEvent> done() => [
  const ModelText('Review complete.'),
  ModelFinished(ModelFinishReason.stop),
];

Future<(ConversationManager, RepForgeAgentSession)> session(
  IStorageService storage,
  RepForgeAgents agents, {
  String? id,
  String kind = 'optimizer',
}) async {
  final conversations = ConversationManager(storage, kind: kind);
  await conversations.loadConversations();
  if (id == null) {
    await conversations.appendMessage(
      ChatMessage(role: 'user', text: 'Review my routine'),
    );
  } else {
    conversations.selectConversation(id);
  }
  final provider = WorkoutProvider(
    storage,
    programManager: ProgramManager(storage),
  );
  await provider.init();
  final tools = CoachToolService(
    workoutProvider: provider,
    prManager: PRManager(storage),
  );
  return (
    conversations,
    agents.session(
      conversations: conversations,
      settings: SettingsProvider(storage),
      tools: tools,
    ),
  );
}

Future<void> until(
  RepForgeAgentSession session,
  bool Function() condition,
) async {
  if (condition()) return;
  final ready = Completer<void>();
  void listener() {
    if (condition() && !ready.isCompleted) ready.complete();
  }

  session.addListener(listener);
  try {
    await ready.future.timeout(const Duration(seconds: 5));
  } finally {
    session.removeListener(listener);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'retry after an approved write resumes the model without repeating the write',
    () async {
      final storage = MockStorageService();
      final model = ScriptedModel([write(), done()], failAt: 2);
      final host = RepForgeAgents(
        model: model,
        store: AppCheckpointStore(storage),
      );
      final (_, run) = await session(storage, host, kind: 'coach');
      await run.send('Create a routine');
      await run.submit(run.pendingInput!, true);
      expect(run.state.status, RunStatus.failed);
      expect(run.canRetry, true);
      expect(await storage.getAllRoutines(), hasLength(1));
      await run.retry();
      expect(run.state.status, RunStatus.completed);
      expect(await storage.getAllRoutines(), hasLength(1));
      expect(
        model.requests.last.messages.where((m) => m.role == 'tool'),
        hasLength(1),
      );
      run.dispose();
    },
  );

  test(
    'proposal review keeps all writes visible through each approval and restoration',
    () async {
      final storage = MockStorageService();
      final model = ScriptedModel([
        [
          ModelToolCall(
            ToolCall(
              id: 'one',
              name: 'create_routine',
              arguments: {'name': 'One', 'exercise_names': <String>[]},
            ),
          ),
          ModelToolCall(
            ToolCall(
              id: 'two',
              name: 'create_routine',
              arguments: {'name': 'Two', 'exercise_names': <String>[]},
            ),
          ),
          ModelFinished(ModelFinishReason.toolCalls),
        ],
        done(),
      ]);
      final host = RepForgeAgents(
        model: model,
        store: AppCheckpointStore(storage),
      );
      final (conversations, run) = await session(storage, host, kind: 'coach');
      await run.send('Create two routines');
      expect(run.changeReview!.position, 1);
      expect(run.changeReview!.changes.map((c) => c.status), [
        AgentChangeStatus.review,
        AgentChangeStatus.waiting,
      ]);
      expect(await run.submit(run.pendingInput!, true), true);
      expect(run.changeReview!.position, 2);
      expect(run.changeReview!.changes.map((c) => c.status), [
        AgentChangeStatus.applied,
        AgentChangeStatus.review,
      ]);
      run.dispose();
      final (_, reopened) = await session(
        storage,
        RepForgeAgents(model: model, store: AppCheckpointStore(storage)),
        id: conversations.active!.id,
        kind: 'coach',
      );
      await reopened.restore();
      expect(reopened.changeReview!.changes, hasLength(2));
      expect(reopened.changeReview!.position, 2);
      expect(await reopened.submit(reopened.pendingInput!, false), true);
      expect(reopened.state.status, RunStatus.completed);
      expect(reopened.changeReview, null);
      expect((await storage.getAllRoutines()).map((r) => r.name), ['One']);
      reopened.dispose();
    },
  );

  test('failed shared checkpoint initialization can be retried', () async {
    final directory = await Directory.systemTemp.createTemp(
      'checkpoint-retry-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final storage = _TransientStorage('${directory.path}/app.db');
    await storage.init();
    addTearDown(storage.close);
    final store = AppCheckpointStore(storage);
    final failed = [store.load('one'), store.load('two')];
    await Future.wait([
      for (final future in failed) expectLater(future, throwsStateError),
    ]);
    expect(storage.attempts, 1);
    expect(await store.load('one'), null);
    expect(storage.attempts, 2);
    expect(await store.load('two'), null);
    expect(storage.attempts, 2);
  });

  test('coach can leave, restore and delete a pending approval', () async {
    final storage = MockStorageService();
    final model = ScriptedModel([write(), done()]);
    final provider = WorkoutProvider(
      storage,
      programManager: ProgramManager(storage),
    );
    await provider.init();
    final view = AiCoachViewModel(
      ai: GeminiAiService(),
      coachTools: CoachToolService(
        workoutProvider: provider,
        prManager: PRManager(storage),
      ),
      conversations: ConversationManager(storage),
      settings: SettingsProvider(storage),
      agents: RepForgeAgents(model: model, store: AppCheckpointStore(storage)),
    );
    addTearDown(view.dispose);
    await view.sendMessage('Propose a routine');
    final id = view.activeConversationId!;
    final approval = view.pendingInput!.request.id;
    final count = view.messages.length;
    await view.sendMessage('Blocked while awaiting approval');
    expect(view.messages, hasLength(count));
    view.newConversation();
    expect(view.activeConversationId, null);
    await view.sendMessage('New conversation');
    expect(view.activeConversationId, isNot(id));
    final restored = Completer<void>();
    void changed() {
      if (view.pendingInput?.request.id == approval && !restored.isCompleted) {
        restored.complete();
      }
    }

    view.addListener(changed);
    view.selectConversation(id);
    await restored.future.timeout(const Duration(seconds: 3));
    view.removeListener(changed);
    await Future<void>.delayed(Duration.zero);
    expect(view.activeConversationId, id);
    await view.deleteConversation(id);
    expect(view.conversations.any((c) => c.id == id), false);
    expect(view.pendingInput, null);
    expect(model.requests, hasLength(2));
  });

  test('optimizer can leave, restore and delete pending questions', () async {
    final storage = MockStorageService();
    final model = ScriptedModel([question(), done()]);
    final provider = WorkoutProvider(
      storage,
      programManager: ProgramManager(storage),
    );
    await provider.init();
    final view = RoutineOptimizerViewModel(
      ai: GeminiAiService(),
      coachTools: CoachToolService(
        workoutProvider: provider,
        prManager: PRManager(storage),
      ),
      conversations: ConversationManager(storage, kind: 'optimizer'),
      settings: SettingsProvider(storage),
      agents: RepForgeAgents(model: model, store: AppCheckpointStore(storage)),
    );
    addTearDown(view.dispose);
    await view.startForRoutine(
      Routine(id: 'one', name: 'Push', exerciseIds: []),
    );
    final id = view.activeConversationId!;
    final questionId = view.pendingInput!.request.id;
    await view.startForRoutine(
      Routine(id: 'two', name: 'Pull', exerciseIds: []),
    );
    expect(view.activeConversationId, isNot(id));
    final restored = Completer<void>();
    void changed() {
      if (view.pendingInput?.request.id == questionId &&
          !restored.isCompleted) {
        restored.complete();
      }
    }

    view.addListener(changed);
    view.selectConversation(id);
    await restored.future.timeout(const Duration(seconds: 3));
    view.removeListener(changed);
    await Future<void>.delayed(Duration.zero);
    await view.deleteConversation(id);
    expect(view.conversations.any((c) => c.id == id), false);
    expect(view.pendingInput, null);
    expect(model.requests, hasLength(2));
  });

  test(
    'opening the optimizer restores an unfinished review of the same routine',
    () async {
      final storage = MockStorageService();
      final model = ScriptedModel([question(), done()]);
      final routine = Routine(id: 'routine', name: 'Push Day', exerciseIds: []);
      final provider = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await provider.init();
      final tools = CoachToolService(
        workoutProvider: provider,
        prManager: PRManager(storage),
      );
      RoutineOptimizerViewModel view() => RoutineOptimizerViewModel(
        ai: GeminiAiService(),
        coachTools: tools,
        conversations: ConversationManager(storage, kind: 'optimizer'),
        settings: SettingsProvider(storage),
        agents: RepForgeAgents(
          model: model,
          store: AppCheckpointStore(storage),
        ),
      );
      final original = view();
      await original.startForRoutine(routine);
      final id = original.activeConversationId;
      final interruptId = original.pendingInput!.request.id;
      original.dispose();
      final reopened = view();
      addTearDown(reopened.dispose);
      await reopened.initializeForRoutine(routine);
      expect(reopened.activeConversationId, id);
      expect(reopened.pendingInput!.request.id, interruptId);
      expect(model.requests, hasLength(1));
      await reopened.submitAnswers([
        const AnswerSpec(question: 'Your goal?', selected: ['Strength']),
      ]);
      expect(reopened.isLoading, false);
      expect(reopened.messages.last.text, 'Review complete.');
    },
  );

  test(
    'SQLite optimizer survives process recreation, validates answers, and executes a write only after exact approval',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'repforge-agent-',
      );
      final path = '${directory.path}/app.db';
      var storage = SqliteStorageService(databasePathOverride: path);
      await storage.init();
      final firstModel = ScriptedModel([question()]);
      final firstHost = RepForgeAgents(
        model: firstModel,
        store: AppCheckpointStore(storage),
      );
      final (firstConversations, first) = await session(storage, firstHost);
      await first.send('Review my routine');
      final id = firstConversations.active!.id;
      final originalQuestion = first.pendingInput!;
      expect(first.state.checkpoint!.status, RunStatus.suspended);
      expect(firstModel.requests, hasLength(1));
      expect(
        firstModel.requests.single.messages.where((m) => m.role == 'user'),
        hasLength(1),
      );
      first.dispose();
      await storage.close();

      storage = SqliteStorageService(databasePathOverride: path);
      await storage.init();
      addTearDown(() async {
        await storage.close();
        await directory.delete(recursive: true);
      });
      final secondModel = ScriptedModel([write(), done()]);
      final secondHost = RepForgeAgents(
        model: secondModel,
        store: AppCheckpointStore(storage),
      );
      final (conversations, restored) = await session(
        storage,
        secondHost,
        id: id,
      );
      await restored.restore();
      expect(restored.pendingInput!.request.id, originalQuestion.request.id);
      expect(secondModel.requests, isEmpty);
      expect(
        await restored.submit(restored.pendingInput!, {
          'answers': [
            {
              'question': 'Your goal?',
              'selected': ['Invalid'],
            },
          ],
        }),
        false,
      );
      expect(restored.pendingInput!.request.id, originalQuestion.request.id);
      final answer = restored.pendingInput!;
      expect(
        await restored.submit(answer, {
          'answers': [
            {
              'question': 'Your goal?',
              'selected': ['Strength'],
            },
          ],
        }),
        true,
      );
      final approval = restored.pendingInput!;
      expect(approval.request.kind, 'tool_approval');
      expect(
        (await storage.getAllRoutines()).where(
          (r) => r.name == 'Reviewed routine',
        ),
        isEmpty,
      );
      expect(await restored.submit(answer, true), false);
      final accepted = restored.submit(approval, true);
      expect(await restored.submit(approval, true), false);
      expect(await accepted, true);
      expect(
        (await storage.getAllRoutines()).where(
          (r) => r.name == 'Reviewed routine',
        ),
        hasLength(1),
      );
      expect(restored.state.status, RunStatus.completed);
      final text = conversations.activeMessages.map((m) => m.text).join('|');
      expect(text, contains('Your goal?: Strength'));
      expect(text, contains('Review complete.'));
      final messagesBeforeRestore = conversations.activeMessages.length;
      await restored.restore();
      expect(conversations.activeMessages.length, messagesBeforeRestore);
      expect(
        secondModel.requests.last.messages
            .where((m) => m.role == 'tool')
            .map((m) => m.callId),
        containsAll(['question-1', 'write-1']),
      );
      expect(
        (await SqlQueryService(
          path,
        ).runQuery('SELECT * FROM repforge_ai_runs'))['error'],
        contains('restricted'),
      );
      await secondHost.forget('optimizer', id);
      await conversations.deleteConversation(id);
      expect(await secondHost.store.load('optimizer:$id'), null);
    },
  );

  test(
    'declining a proposed mutation skips it and continues the model',
    () async {
      final storage = MockStorageService();
      final model = ScriptedModel([write(), done()]);
      final host = RepForgeAgents(
        model: model,
        store: AppCheckpointStore(storage),
      );
      final (_, run) = await session(storage, host, kind: 'coach');
      await run.send('Suggest a routine');
      expect(run.pendingInput!.request.kind, 'tool_approval');
      expect(await run.submit(run.pendingInput!, false), true);
      expect(
        (await storage.getAllRoutines()).where(
          (r) => r.name == 'Reviewed routine',
        ),
        isEmpty,
      );
      expect(run.state.status, RunStatus.completed);
      expect(model.requests.last.messages.last.result, {
        'approved': false,
        'skipped': true,
      });
    },
  );

  test(
    'reattaching a screen retains the pending question without a new request',
    () async {
      final storage = MockStorageService();
      final model = ScriptedModel([question(), done()]);
      final host = RepForgeAgents(
        model: model,
        store: AppCheckpointStore(storage),
      );
      final (conversations, first) = await session(storage, host);
      await first.send('Review');
      final id = conversations.active!.id;
      final (_, reopened) = await session(storage, host, id: id);
      expect(identical(first, reopened), true);
      await reopened.restore();
      expect(
        reopened.pendingQuestions!.questions.single.question,
        'Your goal?',
      );
      expect(model.requests, hasLength(1));
    },
  );

  test(
    'background execution projects to its original conversation after selecting another chat',
    () async {
      final storage = MockStorageService();
      final output = StreamController<ModelEvent>();
      final model = ControlledModel(output.stream);
      final host = RepForgeAgents(model: model, store: MemoryCheckpointStore());
      final (conversations, run) = await session(storage, host, kind: 'coach');
      final firstId = conversations.active!.id;
      final sending = run.send('Review');
      await until(run, () => run.state.isRunning);
      conversations.startNewConversation();
      await conversations.appendMessage(
        ChatMessage(role: 'user', text: 'Another chat'),
      );
      final activeId = conversations.active!.id;
      output.add(const ModelText('Original reply'));
      output.add(ModelFinished(ModelFinishReason.stop));
      await output.close();
      await sending;
      expect(conversations.active!.id, activeId);
      expect(conversations.activeMessages, hasLength(1));
      final original = await storage.getConversation(firstId);
      expect(original!.messages.last.text, 'Original reply');
    },
  );

  test('portable backups ignore executable checkpoint settings', () {
    final data = decodeBackup(
      jsonEncode({
        'settings': {
          'aiCheckpoint:optimizer:old': 'execution',
          'weightUnit': 'kg',
        },
      }),
    );
    expect(data['settings'], {'weightUnit': 'kg'});
  });
}

class ControlledModel implements ModelProvider {
  final Stream<ModelEvent> output;
  ControlledModel(this.output);
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) => output;
}

class _TransientStorage extends SqliteStorageService {
  int attempts = 0;
  _TransientStorage(String path) : super(databasePathOverride: path);
  @override
  Database get database {
    if (attempts++ == 0) throw StateError('Transient initialization failure');
    return super.database;
  }
}
