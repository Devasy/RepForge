import 'dart:async';
import 'dart:convert';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../models/models.dart';
import '../../gemini_context_builder.dart';
import '../../interfaces/ai_service_interface.dart';
import '../../managers/conversation_manager.dart';
import '../../settings_provider.dart';
import '../ai_failure.dart';
import '../coach_tool_service.dart';
import 'repforge_tools.dart';
import 'agent_change_review.dart';
import '../../debug_log_buffer.dart';

class RepForgeAgents {
  final ModelProvider model;
  final CheckpointStore store;
  final int Function() maxModelCalls;
  final String Function() modelId;
  final Map<String, RepForgeAgentSession> _sessions = {};
  RepForgeAgents({
    required this.model,
    required this.store,
    int Function()? maxModelCalls,
    String Function()? modelId,
  }) : maxModelCalls = maxModelCalls ?? (() => 5),
       modelId = modelId ?? (() => 'host-selected');

  factory RepForgeAgents.inMemory(IAiService ai) => RepForgeAgents(
    model: ai is ModelProvider
        ? ai as ModelProvider
        : throw ArgumentError(
            'A ModelProvider is required for agent workflows.',
          ),
    store: MemoryCheckpointStore(),
    modelId: () => ai.currentModel,
  );

  RepForgeAgentSession session({
    required ConversationManager conversations,
    required SettingsProvider settings,
    required CoachToolService tools,
  }) {
    final conversation = conversations.active!;
    final thread = '${conversation.kind}:${conversation.id}';
    if (!_sessions.containsKey(thread)) {
      for (final entry in _sessions.entries.toList()) {
        if (_sessions.length < 8) break;
        if (entry.value.canEvict) {
          _sessions.remove(entry.key);
          entry.value.dispose();
        }
      }
    }
    final session = _sessions.putIfAbsent(
      thread,
      () => RepForgeAgentSession._(
        this,
        conversations,
        settings,
        tools,
        conversation,
      ),
    );
    session.conversations = conversations;
    return session;
  }

  Future<void> forget(String kind, String conversationId) async {
    final session = _sessions.remove('$kind:$conversationId');
    if (session != null) {
      await session.cancel();
      session.dispose();
    }
  }
}

class RepForgeAgentSession extends ChangeNotifier {
  final RepForgeAgents owner;
  ConversationManager conversations;
  final SettingsProvider settings;
  final CoachToolService tools;
  final Conversation original;
  late AgentController<ChatState> controller;
  Future<void> _projection = Future.value();
  bool _disposed = false;
  bool _command = false;
  int? _projectedRevision;
  String? _loggedCheckpoint;
  AiFailure? _failure;
  bool _projectionFailed = false;
  bool _submitting = false;

  RepForgeAgentSession._(
    this.owner,
    this.conversations,
    this.settings,
    this.tools,
    this.original,
  ) {
    controller = _controller();
    controller.addListener(_changed);
  }

  String get threadId => '${original.kind}:${original.id}';
  AgentChangeReview? get changeReview => AgentChangeReview.fromState(state);
  String get statusText => state.statusText;
  bool get optimizer => original.kind == 'optimizer';
  bool get canEvict =>
      !hasListeners && !state.isRunning && !_command && !_submitting;
  AgentViewState<ChatState> get state => controller.state;
  bool get isLoading =>
      _command || state.isRunning || state.pendingInput != null;
  bool get isWorking =>
      _command || _submitting || state.isRunning || state.isCommandPending;
  AiFailure? get failure => _failure;
  bool get canRetry =>
      !_command &&
      state.status == RunStatus.failed &&
      !state.isRunning &&
      state.pendingInput == null &&
      state.checkpoint?.nextNode == 'model' &&
      _failure?.canRetry == true;
  PendingAgentInput? get pendingInput => state.pendingInput;
  List<String> get toolCalls => [
    ...?state.data?.messages
        .skip(state.data!.turnStart)
        .expand((m) => m.calls.map((c) => c.name)),
  ];
  PendingQuestions? get pendingQuestions =>
      pendingInput?.request.kind == 'repforge_questions'
      ? PendingQuestions.fromJson(
          Map<String, dynamic>.from(pendingInput!.request.payload),
        )
      : null;
  String get streamingText {
    final data = state.data;
    final saved = conversations.conversations
        .where((c) => c.id == original.id)
        .firstOrNull;
    final persistedIds = saved?.messages.map((m) => m.id).toSet() ?? <String>{};
    final buffer = StringBuffer();
    if (data != null) {
      for (var i = data.turnStart; i < data.messages.length; i++) {
        final message = data.messages[i];
        if (message.role == 'assistant' &&
            !persistedIds.contains(_messageId(i))) {
          buffer.write(message.text);
        }
      }
    }
    buffer.write(state.streamingText);
    return buffer.toString();
  }

  AgentController<ChatState> _controller({List<ModelMessage>? history}) {
    final prompt = optimizer
        ? GeminiContextBuilder.buildOptimizerSystemPrompt(
            userName: settings.userName,
            unitLabel: settings.unitLabel,
          )
        : GeminiContextBuilder.buildCoachSystemPrompt(
            userName: settings.userName,
            unitLabel: settings.unitLabel,
          );
    final rounds = owner.maxModelCalls();
    return AgentController.chat(
      runtime: AgentRuntime(
        store: owner.store,
        model: owner.model,
        limits: RunLimits(
          activeTimeout: Duration(minutes: rounds * 10 + 1),
          maxModelCalls: rounds,
          maxToolCalls: rounds * 16,
          maxSteps: rounds * 20 + 1,
        ),
      ),
      workflow: chatWorkflow(
        id: 'repforge.${original.kind}',
        modelId: owner.modelId(),
        systemPrompt: prompt,
        initialMessages:
            history ??
            [for (final message in original.messages) _modelMessage(message)],
        tools: repforgeTools(tools, optimizer: optimizer),
        authorize: (tool, _) => tool.effect == ToolEffect.write
            ? ToolAuthorization.requireApproval
            : ToolAuthorization.allow,
      ),
      threadId: threadId,
    );
  }

  static ModelMessage _modelMessage(ChatMessage message) => ModelMessage(
    role: message.role == 'model' ? 'assistant' : 'user',
    text: message.text,
    attachments: [
      if (message.imageBytesBase64 != null)
        {
          'mimeType': message.imageMimeType ?? 'image/jpeg',
          'data': message.imageBytesBase64,
        },
    ],
  );

  Future<void> restore() async {
    _projectedRevision = null;
    _projectionFailed = false;
    _failure = null;
    if (!await controller.restore()) _readFailure();
    await _projection;
    if (state.needsRecovery) {
      _failure = const AiFailure(
        'This reply was interrupted when the app closed. Check any changes already made, then stop it before sending a new message.',
        canRetry: false,
      );
      notifyListeners();
    }
  }

  Future<void> send(String text, {List<JsonMap> attachments = const []}) async {
    if (_command || state.isRunning || state.pendingInput != null) return;
    _command = true;
    _failure = null;
    try {
      if (state.checkpoint != null && !state.canStart) return;
      final current = conversations.conversations
          .where((c) => c.id == original.id)
          .first;
      final history = current.messages
          .take(current.messages.length - 1)
          .map(_modelMessage)
          .toList();
      controller.removeListener(_changed);
      controller.dispose();
      controller = _controller(history: history);
      controller.addListener(_changed);
      _projectedRevision = null;
      if (await controller.start(
        input: {'text': text, 'attachments': attachments},
      )) {
        await _settle();
      } else {
        _readFailure();
      }
    } catch (_) {
      _failure = const AiFailure(
        'Your chat could not be saved. Check available storage and reopen the chat before continuing.',
        canRetry: false,
      );
    } finally {
      _command = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> retry() async {
    if (!canRetry) return;
    _command = true;
    _failure = null;
    try {
      if (await controller.retry()) {
        await _settle();
      } else {
        _readFailure();
      }
    } finally {
      _command = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> submit(PendingAgentInput target, Object? response) async {
    if (_submitting) return false;
    _submitting = true;
    try {
      return await _submit(target, response);
    } finally {
      _submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> _submit(PendingAgentInput target, Object? response) async {
    if (_command && state.pendingInput == null) return false;
    final current = pendingInput;
    if (current == null ||
        current.threadId != target.threadId ||
        current.runId != target.runId ||
        current.revision != target.revision ||
        current.request.id != target.request.id) {
      return false;
    }
    if (target.request.kind == 'repforge_questions') {
      try {
        target.request.responseSchema.validate(response);
        final answers = jsonObject(response)['answers']! as List<Object?>;
        final questions = pendingQuestions!.questions;
        if (answers.length != questions.length) return false;
        for (var i = 0; i < answers.length; i++) {
          final answer = jsonObject(answers[i]);
          final selected = (answer['selected']! as List<Object?>)
              .cast<String>();
          final custom = (answer['custom'] as String? ?? '').trim();
          final question = questions[i];
          if (answer['question'] != question.question ||
              selected.any((option) => !question.options.contains(option)) ||
              selected.toSet().length != selected.length ||
              (!question.multiSelect && selected.length > 1) ||
              (selected.isEmpty && custom.isEmpty)) {
            return false;
          }
        }
      } catch (_) {
        return false;
      }
    }
    _failure = null;
    DebugLogBuffer.instance.write(
      '[AI] input_response run=${target.runId} kind=${target.request.kind} accepted=${response == true}',
    );
    if (!await controller.submitInput(target, response)) {
      _readFailure();
      return false;
    }
    await _settle();
    return true;
  }

  Future<void> cancel() async {
    if (state.checkpoint != null) await controller.cancel();
    await _projection;
  }

  Future<void> _settle() async {
    try {
      await controller.completion;
      await _projection;
      _readFailure();
    } catch (_) {
      _failure = const AiFailure(
        'Your chat could not be saved. Check available storage and reopen the chat before continuing.',
        canRetry: false,
      );
    }
  }

  void _readFailure() {
    final error = state.error;
    if (_projectionFailed) return;
    if (state.status == RunStatus.cancelled) {
      _failure = null;
    } else if (error != null) {
      _failure = AiFailure(
        error.message,
        canRetry:
            state.checkpoint?.nextNode == 'model' &&
            !{
              'model_auth',
              'model_unavailable',
              'model_capability',
              'workflow_version',
              'context_budget',
            }.contains(error.code),
      );
    } else {
      _failure = null;
    }
  }

  String _messageId(int index) => '${state.checkpoint!.runId}:$index';
  void _changed() {
    if (_disposed) return;
    final checkpoint = state.checkpoint;
    final logKey = checkpoint == null
        ? null
        : '${checkpoint.runId}:${checkpoint.revision}';
    if (checkpoint != null && _loggedCheckpoint != logKey) {
      _loggedCheckpoint = logKey;
      DebugLogBuffer.instance.write(
        '[AI] ${jsonEncode({'event': 'checkpoint', 'run': checkpoint.runId, 'status': checkpoint.status.name, 'modelCalls': checkpoint.modelCalls, 'toolCalls': checkpoint.toolCalls, 'nextCall': state.data?.nextCall, 'pendingCalls': state.data?.pendingCalls.length, 'input': checkpoint.interrupt?.kind, 'failure': checkpoint.failure?['code']})}',
      );
    }
    if (checkpoint != null && checkpoint.revision != _projectedRevision) {
      _projectedRevision = checkpoint.revision;
      final data = state.data;
      _projection = _projection
          .then((_) => _project(checkpoint, data))
          .catchError(_projectionError);
    }

    notifyListeners();
  }

  Future<void> _project(RunCheckpoint checkpoint, ChatState? data) async {
    if (data == null) return;
    final runId = checkpoint.runId;
    final resume = checkpoint.resumeInput;
    if (resume?.request.kind == 'repforge_questions') {
      await _projectAnswers(
        runId,
        data.messages.length,
        jsonObject(resume!.value),
      );
    }
    final toolNames = data.messages
        .skip(data.turnStart)
        .expand((m) => m.calls.map((call) => call.name))
        .toList();
    final pendingTools = <String, String>{};
    for (var index = data.turnStart; index < data.messages.length; index++) {
      final message = data.messages[index];
      for (final call in message.calls) {
        pendingTools[call.id] = call.name;
        if (call.arguments['preamble'] case final String preamble
            when call.name == 'ask_user_questions' && preamble.isNotEmpty) {
          await conversations.appendTo(
            original.id,
            ChatMessage(
              id: '$runId:question:$index:${call.id}',
              role: 'model',
              text: preamble,
            ),
          );
        }
      }
      if (message.role == 'tool' &&
          pendingTools.remove(message.callId) == 'ask_user_questions') {
        final response = message.result?['response'];
        if (response is JsonMap) {
          await _projectAnswers(runId, index, response);
        }
      }
      if (message.role == 'assistant' && message.text.trim().isNotEmpty) {
        await conversations.appendTo(
          original.id,
          ChatMessage(
            id: '$runId:$index',
            role: 'model',
            text: message.text,
            toolCalls: toolNames,
          ),
        );
      }
    }
  }

  Future<void> _projectAnswers(
    String runId,
    int index,
    JsonMap response,
  ) async {
    final answers = response['answers']! as List<Object?>;
    final text = answers
        .map((value) {
          final answer = jsonObject(value);
          final selected = answer['selected']! as List<Object?>;
          return '${answer['question']}: ${[...selected, if (answer['custom'] case final String custom when custom.isNotEmpty) custom].join(', ')}';
        })
        .join(' · ');
    await conversations.appendTo(
      original.id,
      ChatMessage(id: '$runId:answer:$index', role: 'user', text: text),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  void _projectionError(Object _) {
    _projectionFailed = true;
    _failure = const AiFailure(
      'Your chat could not be saved. Reopen it before continuing.',
      canRetry: false,
    );
  }
}
