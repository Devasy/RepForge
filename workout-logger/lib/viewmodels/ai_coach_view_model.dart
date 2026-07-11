// ai_coach_view_model.dart — orchestration for the AI coach screen.
//
// Owns all coach logic so the View stays dumb: builds the coach graph,
// drives the streaming agent runtime, and persists each turn through
// ConversationManager. Exposes immutable state including agent status text
// and active tool tracking.

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/ai/agent_event.dart';
import '../services/ai/graphs/coach_graph.dart';
import '../services/ai/runtime/agent_artifact.dart';
import '../services/ai/runtime/agent_runtime.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';

class AiCoachViewModel extends ChangeNotifier {
  final DefaultAgentRuntime _runtime;
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
    required DefaultAgentRuntime runtime,
    required ConversationManager conversations,
    required SettingsProvider settings,
  })  : _runtime = runtime,
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

  bool get isConfigured => _runtime.isConfigured;
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
  /// runtime. Both the user message and the final reply are persisted.
  /// The runtime handles tool calls, retries, and status updates via the
  /// coach graph.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    _loading = true;
    _streamingText = '';
    _statusText = '';
    _activeTools.clear();
    notifyListeners();

    // Persist the user message first.
    await _conversations.appendMessage(
      ChatMessage(role: 'user', text: trimmed),
    );

    final graph = buildCoachGraph(
      userName: _settings.userName,
      unitLabel: _settings.unitLabel,
    );

    final buffer = StringBuffer();
    try {
      await for (final event in _runtime.run(
        graph: graph,
        input: AgentRunInput(userMessage: trimmed),
      )) {
        switch (event) {
          case AgentRunStarted():
            // Coach graph doesn't use interrupts, run ID not needed.
            break;

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
            // Legacy: route to chart rendering (backward compat).
            break;

          case AgentArtifactReady(:final artifact):
            // Future: render typed artifacts (charts, tables, etc.)
            if (artifact is ChartArtifact) {
              // Could render inline chart here.
            }
            break;

          case AgentInterrupted():
            // Coach graph doesn't use interrupts, but handle gracefully.
            break;

          case AgentTraceEvent():
            // Debug/trace events — ignore in production UI.
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
}
