// ai_coach_view_model.dart — orchestration for the AI coach screen.
//
// Owns all coach logic so the View stays dumb: builds the system prompt,
// drives the streaming tool-call loop via AgentOrchestrator + CoachToolService,
// and persists each turn through ConversationManager. Exposes immutable state
// including agent status text and active tool tracking.

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart' show Content, TextPart;

import '../models/models.dart';
import '../services/ai/agent_event.dart';
import '../services/ai/agent_orchestrator.dart';
import '../services/ai/coach_tool_service.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';
import '../services/gemini_context_builder.dart';

class AiCoachViewModel extends ChangeNotifier {
  final AgentOrchestrator _orchestrator;
  final CoachToolService _coachTools;
  final ConversationManager _conversations;
  final SettingsProvider _settings;

  bool _loading = false;
  String _streamingText = '';

  /// Human-readable status text shown below the streaming area.
  /// E.g. "Fetching bench press data…", "Rate limit — retrying in 12s…"
  String _statusText = '';

  /// Names of tools currently being executed (shown as chips in the UI).
  final List<String> _activeTools = [];

  AiCoachViewModel({
    required AgentOrchestrator orchestrator,
    required CoachToolService coachTools,
    required ConversationManager conversations,
    required SettingsProvider settings,
  })  : _orchestrator = orchestrator,
        _coachTools = coachTools,
        _conversations = conversations,
        _settings = settings {
    // Forward conversation-store changes so the View only watches the VM.
    _conversations.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _conversations.removeListener(notifyListeners);
    super.dispose();
  }

  // ── Exposed state (immutable snapshots) ────────────────────────────────────

  bool get isConfigured => _orchestrator.isConfigured;
  bool get isLoading => _loading;
  String get streamingText => _streamingText;
  String get statusText => _statusText;
  List<String> get activeTools => List.unmodifiable(_activeTools);
  List<ChatMessage> get messages => _conversations.activeMessages;
  List<Conversation> get conversations => _conversations.conversations;
  String? get activeConversationId => _conversations.active?.id;

  // ── Commands ───────────────────────────────────────────────────────────────

  /// Load the persisted conversation list (call when the screen opens).
  Future<void> loadConversations() => _conversations.loadConversations();

  /// Start a fresh, unsaved conversation.
  void newConversation() {
    if (_loading) return;
    _conversations.startNewConversation();
  }

  /// Switch to an existing conversation.
  void selectConversation(String id) {
    if (_loading) return;
    _conversations.selectConversation(id);
  }

  /// Delete a conversation.
  Future<void> deleteConversation(String id) =>
      _conversations.deleteConversation(id);

  /// Send a user message and stream the coach's reply through the agent
  /// orchestrator. Both the user message and the final reply are persisted.
  /// The orchestrator handles tool calls, retries, and status updates.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    _loading = true;
    _streamingText = '';
    _statusText = '';
    _activeTools.clear();
    notifyListeners();

    // Persist the user message first; history is derived from the store.
    await _conversations.appendMessage(
      ChatMessage(role: 'user', text: trimmed),
    );

    final systemPrompt = _buildSystemPrompt();
    final history = _buildHistory();

    final buffer = StringBuffer();
    try {
      await for (final event in _orchestrator.orchestrate(
        userMessage: trimmed,
        systemPrompt: systemPrompt,
        history: history,
        tools: _coachTools.buildTools(),
        onToolCall: _coachTools.handleCall,
      )) {
        switch (event) {
          case AgentTextChunk(:final text):
            buffer.write(text);
            _streamingText = buffer.toString();
            _statusText = '';
            notifyListeners();

          case AgentStatusUpdate(:final status):
            _statusText = status;
            notifyListeners();

          case AgentToolActivity(:final toolName, :final isStart, :final label):
            if (isStart) {
              _activeTools.add(label ?? toolName);
            } else {
              _activeTools.remove(label ?? toolName);
            }
            notifyListeners();

          case AgentRetryWait(:final remaining, :final reason):
            _statusText = '$reason — retrying in ${remaining.inSeconds}s…';
            notifyListeners();

          case AgentError(:final message):
            buffer.write('\n\n_Error: ${message}_');
            notifyListeners();

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
      buffer.write('\n\n_Error: ${e}_');
      final errText = buffer.toString().trim();
      if (errText.isNotEmpty) {
        await _conversations.appendMessage(
          ChatMessage(role: 'model', text: errText),
        );
      }
    } finally {
      _streamingText = '';
      _statusText = '';
      _activeTools.clear();
      _loading = false;
      notifyListeners();
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  // Static prompt — live data is fetched by the model via the coach tools,
  // keeping the prefix stable for implicit prompt caching.
  String _buildSystemPrompt() => GeminiContextBuilder.buildCoachSystemPrompt(
        userName: _settings.userName,
        unitLabel: _settings.unitLabel,
      );

  /// Prior turns (everything before the user message just appended).
  List<Content> _buildHistory() {
    final msgs = _conversations.activeMessages;
    final prior =
        msgs.length > 1 ? msgs.sublist(0, msgs.length - 1) : <ChatMessage>[];
    return prior.map((m) => Content(m.role, [TextPart(m.text)])).toList();
  }
}
