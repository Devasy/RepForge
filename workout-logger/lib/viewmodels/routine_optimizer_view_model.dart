import 'dart:async';

import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/ai/ai_failure.dart';
import '../services/ai/coach_tool_service.dart';
import '../services/ai/orchestration/repforge_agents.dart';
import '../services/interfaces/ai_service_interface.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';

class RoutineOptimizerViewModel extends ChangeNotifier {
  final IAiService _ai;
  final CoachToolService _tools;
  final ConversationManager _conversations;
  final SettingsProvider _settings;
  late final RepForgeAgents _agents;
  RepForgeAgentSession? _session;
  bool _busy = false;
  bool _disposed = false;
  AiFailure? _localFailure;

  RoutineOptimizerViewModel({
    required IAiService ai,
    required CoachToolService coachTools,
    required ConversationManager conversations,
    required SettingsProvider settings,
    RepForgeAgents? agents,
  }) : _ai = ai,
       _tools = coachTools,
       _conversations = conversations,
       _settings = settings {
    _agents = agents ?? RepForgeAgents.inMemory(ai);
    _conversations.addListener(_notify);
  }

  bool get isConfigured => _ai.isConfigured;
  bool get isLoading => _busy || (_session?.isLoading ?? false);
  String get streamingText => _session?.streamingText ?? '';
  PendingQuestions? get pendingQuestions => _session?.pendingQuestions;
  PendingAgentInput? get pendingInput => _session?.pendingInput;
  bool get needsRecovery => _session?.state.needsRecovery ?? false;
  AiFailure? get failure => _localFailure ?? _session?.failure;
  List<ChatMessage> get messages => _conversations.activeMessages;
  List<Conversation> get conversations => _conversations.conversations;
  String? get activeConversationId => _conversations.active?.id;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _bind() {
    _session?.removeListener(_notify);
    _session = _agents.session(
      conversations: _conversations,
      settings: _settings,
      tools: _tools,
    );
    if (!_disposed) _session!.addListener(_notify);
  }

  Future<void> loadConversations() => _conversations.loadConversations();
  Future<void> initializeForRoutine(Routine routine) async {
    await loadConversations();
    if (_disposed) return;
    final seed =
        'Optimize my "${routine.name}" routine based on my past performance.';
    final previous = conversations
        .where(
          (conversation) => conversation.messages.firstOrNull?.text == seed,
        )
        .firstOrNull;
    if (previous != null) {
      _busy = true;
      try {
        _conversations.selectConversation(previous.id);
        _bind();
        await _session!.restore();
        if (_disposed) return;
        if (_session!.pendingInput != null ||
            _session!.state.isRunning ||
            _session!.failure != null) {
          return;
        }
      } finally {
        _busy = false;
        _notify();
      }
    }
    if (!_disposed) await startForRoutine(routine);
  }

  void selectConversation(String id) {
    if (isLoading) return;
    _conversations.selectConversation(id);
    if (_conversations.active == null) return;
    _busy = true;
    _localFailure = null;
    _bind();
    unawaited(
      _session!.restore().whenComplete(() {
        _busy = false;
        _notify();
      }),
    );
  }

  Future<void> deleteConversation(String id) async {
    if (isLoading) return;
    await _agents.forget('optimizer', id);
    if (id == activeConversationId) {
      _session?.removeListener(_notify);
      _session = null;
    }
    await _conversations.deleteConversation(id);
  }

  Future<void> startForRoutine(Routine routine) async {
    if (isLoading) return;
    _session?.removeListener(_notify);
    _session = null;
    _conversations.startNewConversation();
    await sendMessage(
      'Optimize my "${routine.name}" routine based on my past performance.',
    );
  }

  Future<bool> submitInput(PendingAgentInput target, Object? response) async =>
      await _session?.submit(target, response) ?? false;

  Future<void> submitAnswers(
    List<AnswerSpec> answers, {
    PendingAgentInput? target,
  }) async {
    final pending = target ?? pendingInput;
    if (pending == null || pending.request.kind != 'repforge_questions') return;
    await submitInput(pending, {
      'answers': [for (final answer in answers) answer.toJson()],
    });
    _notify();
  }

  Future<void> cancelRun() async {
    await _session?.cancel();
    _notify();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || isLoading || needsRecovery) return;
    _busy = true;
    _localFailure = null;
    _notify();
    try {
      await _conversations.appendMessage(
        ChatMessage(role: 'user', text: text.trim()),
      );
      _bind();
      await _session!.send(text.trim());
    } catch (_) {
      _localFailure = const AiFailure(
        'Your chat could not be saved. Reopen it before continuing.',
        canRetry: false,
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _session?.removeListener(_notify);
    _session = null;
    _conversations.removeListener(_notify);
    super.dispose();
  }
}
