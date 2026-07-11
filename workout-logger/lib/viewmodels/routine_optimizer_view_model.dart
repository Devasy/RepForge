// routine_optimizer_view_model.dart — Conversational routine optimizer VM.
//
// Drives the optimizer graph through the agent runtime. Handles the
// ask_user_questions interrupt/resume flow as a first-class graph behavior
// instead of custom Completer-based logic.

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/ai/agent_event.dart';
import '../services/ai/graphs/optimizer_graph.dart';
import '../services/ai/runtime/agent_artifact.dart';
import '../services/ai/runtime/agent_interrupt.dart';
import '../services/ai/runtime/agent_runtime.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';

class RoutineOptimizerViewModel extends ChangeNotifier {
  final DefaultAgentRuntime _runtime;
  final ConversationManager _conversations;
  final SettingsProvider _settings;

  bool _loading = false;
  bool _disposed = false;
  String _streamingText = '';
  String _statusText = '';
  final List<String> _activeTools = [];
  PendingQuestions? _pendingQuestions;

  /// The run ID of the currently suspended run (for resume).
  String? _suspendedRunId;

  RoutineOptimizerViewModel({
    required DefaultAgentRuntime runtime,
    required ConversationManager conversations,
    required SettingsProvider settings,
  })  : _runtime = runtime,
        _conversations = conversations,
        _settings = settings {
    _conversations.addListener(_notify);
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingQuestions = null;
    _suspendedRunId = null;
    _conversations.removeListener(_notify);
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  bool get isConfigured => _runtime.isConfigured;
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

  /// Submit the user's answers to the pending ask_user_questions interrupt.
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

    _notify();

    // Resume the suspended run with the user's answers.
    final runId = _suspendedRunId;
    if (runId == null) return;
    _suspendedRunId = null;

    final buffer = StringBuffer();
    _loading = true;
    _notify();

    try {
      final resumeStream = await _runtime.resume(
        runId: runId,
        payload: <String, Object?>{
          'answers': [for (final a in answers) a.toJson()],
        },
      );

      await for (final event in resumeStream) {
        _handleEvent(event, buffer);
      }

      final reply = buffer.toString().trim();
      if (reply.isNotEmpty) {
        await _conversations.appendMessage(
          ChatMessage(role: 'model', text: reply),
        );
      }
    } catch (e) {
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

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    _loading = true;
    _streamingText = '';
    _statusText = '';
    _activeTools.clear();
    _notify();

    await _conversations.appendMessage(ChatMessage(role: 'user', text: trimmed));

    final graph = buildOptimizerGraph(
      userName: _settings.userName,
      unitLabel: _settings.unitLabel,
    );

    final buffer = StringBuffer();
    try {
      await for (final event in _runtime.run(
        graph: graph,
        input: AgentRunInput(userMessage: trimmed),
      )) {
        _handleEvent(event, buffer);
      }

      final reply = buffer.toString().trim();
      if (reply.isNotEmpty) {
        await _conversations.appendMessage(
          ChatMessage(role: 'model', text: reply),
        );
      }
    } catch (e) {
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

  /// Shared event handler for both run() and resume() streams.
  void _handleEvent(AgentEvent event, StringBuffer buffer) {
    switch (event) {
      case AgentRunStarted(:final runId):
        _suspendedRunId = runId;
        _notify();

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
        // Legacy: route to chart rendering.
        break;

      case AgentArtifactReady(:final artifact):
        if (artifact is QuestionFormArtifact) {
          // The interrupt mechanism handles this, but log it for preamble.
          final preamble = artifact.questions.preamble;
          if (preamble != null && preamble.isNotEmpty) {
            _conversations.appendMessage(
              ChatMessage(role: 'model', text: preamble),
            );
          }
        }
        break;

      case AgentInterrupted(:final interrupt):
        if (interrupt is AwaitUserQuestions) {
          _pendingQuestions = interrupt.payload;
          _notify();
        }
        break;

      case AgentTraceEvent():
        // Ignore trace events.
        break;
    }
  }
}
