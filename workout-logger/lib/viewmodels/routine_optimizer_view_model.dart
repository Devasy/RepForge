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
import '../services/interfaces/ai_service_interface.dart';
import '../services/ai/coach_tool_service.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';
import '../services/gemini_context_builder.dart';

class RoutineOptimizerViewModel extends ChangeNotifier {
  final IAiService _ai;
  final CoachToolService _coachTools;
  final ConversationManager _conversations;
  final SettingsProvider _settings;

  bool _loading = false;
  bool _disposed = false;
  String _streamingText = '';
  PendingQuestions? _pendingQuestions;
  Completer<Map<String, Object?>>? _pendingCompleter;

  RoutineOptimizerViewModel({
    required IAiService ai,
    required CoachToolService coachTools,
    required ConversationManager conversations,
    required SettingsProvider settings,
  })  : _ai = ai,
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

  bool get isConfigured => _ai.isConfigured;
  bool get isLoading => _loading;
  String get streamingText => _streamingText;
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
  void submitAnswers(List<AnswerSpec> answers) {
    _pendingQuestions = null;

    final text = answers
        .map((a) {
          final parts = [...a.selected];
          if (a.custom != null && a.custom!.isNotEmpty) parts.add(a.custom!);
          return '${a.question}: ${parts.join(', ')}';
        })
        .join(' · ');

    if (text.isNotEmpty) {
      _conversations.appendMessage(ChatMessage(role: 'user', text: text));
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
      await for (final chunk in _ai.streamCoachReply(
        userMessage: trimmed,
        systemPrompt: systemPrompt,
        history: history,
        tools: tools,
        onToolCall: _routeToolCall,
      )) {
        buffer.write(chunk);
        _streamingText = buffer.toString();
        _notify();
      }
      final reply = buffer.toString().trim();
      if (reply.isNotEmpty) {
        await _conversations.appendMessage(
          ChatMessage(role: 'model', text: reply),
        );
      }
    } catch (e) {
      await _conversations.appendMessage(
        ChatMessage(role: 'model', text: 'Error: $e'),
      );
    } finally {
      _streamingText = '';
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

    return completer.future;
  }

  List<Content> _buildHistory() {
    final msgs = _conversations.activeMessages;
    final prior =
        msgs.length > 1 ? msgs.sublist(0, msgs.length - 1) : <ChatMessage>[];
    return prior.map((m) => Content(m.role, [TextPart(m.text)])).toList();
  }
}
