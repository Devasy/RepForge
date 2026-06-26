// routine_optimizer_view_model.dart — Conversational routine optimizer VM.
//
// Drives IAiService.streamCoachReply with an optimizer-focused system prompt.
// Intercepts ask_user_questions tool calls — sets pendingQuestions and returns
// a Completer.future, suspending the stream until submitAnswers() is called.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, TextPart, FunctionCall, Tool;

import '../models/models.dart';
import '../services/ai/agent_event.dart';
import '../services/ai/agent_orchestrator.dart';
import '../services/ai/coach_tool_service.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';
import '../services/gemini_context_builder.dart';

class RoutineOptimizerViewModel extends ChangeNotifier {
  final AgentOrchestrator _orchestrator;
  final CoachToolService _coachTools;
  final ConversationManager _conversations;
  final SettingsProvider _settings;

  bool _loading = false;
  bool _disposed = false;
  String _streamingText = '';
  String _statusText = '';
  final List<String> _activeTools = [];
  PendingQuestions? _pendingQuestions;
  Completer<Map<String, Object?>>? _pendingCompleter;

  RoutineOptimizerViewModel({
    required AgentOrchestrator orchestrator,
    required CoachToolService coachTools,
    required ConversationManager conversations,
    required SettingsProvider settings,
  })  : _orchestrator = orchestrator,
        _coachTools = coachTools,
        _conversations = conversations,
        _settings = settings {
    _conversations.addListener(_notify);
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingCompleter?.complete({'answers': <Object?>[], 'aborted': true});
    _pendingCompleter = null;
    _pendingQuestions = null;
    _conversations.removeListener(_notify);
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  bool get isConfigured => _orchestrator.isConfigured;
  bool get isLoading => _loading;
  String get streamingText => _streamingText;
  String get statusText => _statusText;
  List<String> get activeTools => List.unmodifiable(_activeTools);
  PendingQuestions? get pendingQuestions => _pendingQuestions;
  List<ChatMessage> get messages => _conversations.activeMessages;
  List<Conversation> get conversations => _conversations.conversations;
  String? get activeConversationId => _conversations.active?.id;

  // ── Commands ───────────────────────────────────────────────────────────────

  Future<void> loadConversations() => _conversations.loadConversations();

  void selectConversation(String id) {
    if (_loading) return;
    _conversations.selectConversation(id);
  }

  Future<void> deleteConversation(String id) =>
      _conversations.deleteConversation(id);

  /// Begin a fresh conversation and auto-send the optimization seed prompt.
  Future<void> startForRoutine(Routine routine) async {
    _conversations.startNewConversation();
    final seed =
        'Optimize my "${routine.name}" routine based on my past performance.';
    await sendMessage(seed);
  }

  /// Submit the user's answers to the pending ask_user_questions call.
  Future<void> submitAnswers(List<AnswerSpec> answers) async {
    _pendingQuestions = null;

    final text = answers
        .map((a) {
          final parts = [...a.selected];
          if (a.custom != null && a.custom!.isNotEmpty) parts.add(a.custom!);
          return '${a.question}: ${parts.join(', ')}';
        })
        .join(' · ');

    if (text.isNotEmpty) {
      await _conversations.appendMessage(ChatMessage(role: 'user', text: text));
    }

    _pendingCompleter?.complete(<String, Object?>{
      'answers': [for (final a in answers) a.toJson()],
    });
    _pendingCompleter = null;
    _notify();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    _loading = true;
    _streamingText = '';
    _statusText = '';
    _activeTools.clear();
    _notify();

    await _conversations.appendMessage(ChatMessage(role: 'user', text: trimmed));

    final systemPrompt = GeminiContextBuilder.buildOptimizerSystemPrompt(
      userName: _settings.userName,
      unitLabel: _settings.unitLabel,
    );
    final history = _buildHistory();
    final tools = [
      ..._coachTools.buildTools(),
      Tool(functionDeclarations: [CoachToolService.askUserQuestionsDeclaration]),
    ];

    final buffer = StringBuffer();
    try {
      await for (final event in _orchestrator.orchestrate(
        userMessage: trimmed,
        systemPrompt: systemPrompt,
        history: history,
        tools: tools,
        onToolCall: _routeToolCall,
      )) {
        switch (event) {
          case AgentTextChunk(:final text):
            buffer.write(text);
            _streamingText = buffer.toString();
            _statusText = '';
            _notify();

          case AgentStatusUpdate(:final status):
            _statusText = status;
            _notify();

          case AgentToolActivity(:final toolName, :final isStart, :final label):
            if (isStart) {
              _activeTools.add(label ?? toolName);
            } else {
              _activeTools.remove(label ?? toolName);
            }
            _notify();

          case AgentRetryWait(:final remaining, :final reason):
            _statusText = '$reason — retrying in ${remaining.inSeconds}s…';
            _notify();

          case AgentError(:final message):
            buffer.write('\n\n_Error: ${message}_');
            _notify();

          case AgentChartData():
            // Future: route to chart rendering
            break;
        }
      }
      final reply = buffer.toString().trim();
      if (reply.isNotEmpty) {
        await _conversations.appendMessage(
          ChatMessage(role: 'model', text: reply),
        );
      }
    } catch (e) {
      // Swallow internal abort signals from dispose().
      if (e is! StateError || e.message != 'optimizer_aborted') {
        await _conversations.appendMessage(
          ChatMessage(role: 'model', text: 'Error: $e'),
        );
      }
    } finally {
      _streamingText = '';
      _statusText = '';
      _activeTools.clear();
      _loading = false;
      _pendingQuestions = null;
      _notify();
    }
  }

  Future<Map<String, Object?>> _routeToolCall(FunctionCall call) async {
    if (call.name == 'ask_user_questions') {
      return _handleAskUserQuestions(Map<String, dynamic>.from(call.args));
    }
    return _coachTools.handleCall(call);
  }

  Future<Map<String, Object?>> _handleAskUserQuestions(
    Map<String, dynamic> args,
  ) async {
    final pending = PendingQuestions.fromJson(args);

    final preamble = pending.preamble;
    if (preamble != null && preamble.isNotEmpty) {
      await _conversations.appendMessage(
        ChatMessage(role: 'model', text: preamble),
      );
    }

    _pendingQuestions = pending;
    final completer = Completer<Map<String, Object?>>();
    _pendingCompleter = completer;
    _notify();

    final result = await completer.future;

    // If the session was abandoned (e.g. dispose() was called), abort cleanly.
    if (result['aborted'] == true) {
      throw StateError('optimizer_aborted');
    }

    return result;
  }

  List<Content> _buildHistory() {
    final msgs = _conversations.activeMessages;
    final prior =
        msgs.length > 1 ? msgs.sublist(0, msgs.length - 1) : <ChatMessage>[];
    return prior.map((m) => Content(m.role, [TextPart(m.text)])).toList();
  }
}
