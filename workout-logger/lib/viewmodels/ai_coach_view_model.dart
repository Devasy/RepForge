// ai_coach_view_model.dart — orchestration for the AI coach screen.
//
// Owns all coach logic so the View stays dumb: builds the system prompt,
// drives the streaming tool-call loop via IAiService + CoachToolService, and
// persists each turn through ConversationManager. Exposes immutable state.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, TextPart, DataPart, Part, FunctionCall;

import '../models/models.dart';
import '../services/interfaces/ai_service_interface.dart';
import '../services/ai/coach_tool_service.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';
import '../services/gemini_context_builder.dart';

class AiCoachViewModel extends ChangeNotifier {
  final IAiService _ai;
  final CoachToolService _coachTools;
  final ConversationManager _conversations;
  final SettingsProvider _settings;

  bool _loading = false;
  String _streamingText = '';
  final List<String> _streamingToolCalls = [];
  Uint8List? _pendingImageBytes;
  String? _pendingImageMimeType;

  AiCoachViewModel({
    required IAiService ai,
    required CoachToolService coachTools,
    required ConversationManager conversations,
    required SettingsProvider settings,
  })  : _ai = ai,
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

  bool get isConfigured => _ai.isConfigured;
  bool get isLoading => _loading;
  String get streamingText => _streamingText;
  // Tool names invoked so far for the in-flight reply, in call order.
  List<String> get streamingToolCalls => List.unmodifiable(_streamingToolCalls);
  List<ChatMessage> get messages => _conversations.activeMessages;
  List<Conversation> get conversations => _conversations.conversations;
  String? get activeConversationId => _conversations.active?.id;
  Uint8List? get pendingImageBytes => _pendingImageBytes;
  bool get hasPendingImage => _pendingImageBytes != null;

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

  static const int _maxImageBytes = 5 * 1024 * 1024; // 5 MB limit
  static const Set<String> _supportedImageMimes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Pick an image to attach to the next message.
  Future<void> pickImage() async {
    if (_loading) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: false, // disable eager byte loading
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      // Determine MIME type strictly from extension
      final ext = (file.extension ?? '').toLowerCase().trim();
      final String? mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };

      if (mimeType == null || !_supportedImageMimes.contains(mimeType)) {
        debugPrint('Unsupported or missing image format: "$ext"');
        return;
      }

      // Check file length before reading bytes
      int? fileLength;
      if (file.size > 0) {
        fileLength = file.size;
      } else if (file.path != null) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          fileLength = await ioFile.length();
        }
      }

      if (fileLength == null || fileLength <= 0 || fileLength > _maxImageBytes) {
        debugPrint('File size unavailable or exceeds limit ($fileLength bytes)');
        return;
      }

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) return;

      _pendingImageBytes = bytes;
      _pendingImageMimeType = mimeType;
      notifyListeners();
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// Clear the currently attached pending image.
  void clearPendingImage() {
    _pendingImageBytes = null;
    _pendingImageMimeType = null;
    notifyListeners();
  }

  /// Send a user message and stream the coach's reply (running the tool-call
  /// loop). Both the user message and the final reply are persisted.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && _pendingImageBytes == null) || _loading) return;

    _loading = true;
    _streamingText = '';
    _streamingToolCalls.clear();

    final imageBytes = _pendingImageBytes;
    final imageMimeType = _pendingImageMimeType;
    final imageBase64 = imageBytes != null ? base64Encode(imageBytes) : null;

    _pendingImageBytes = null;
    _pendingImageMimeType = null;
    notifyListeners();

    // Persist the user message first; history is derived from the store.
    await _conversations.appendMessage(
      ChatMessage(
        role: 'user',
        text: trimmed,
        imageBytesBase64: imageBase64,
        imageMimeType: imageMimeType,
      ),
    );

    final systemPrompt = _buildSystemPrompt();
    final history = _buildHistory();

    final buffer = StringBuffer();
    try {
      await for (final chunk in _ai.streamCoachReply(
        userMessage: trimmed,
        systemPrompt: systemPrompt,
        history: history,
        tools: _coachTools.buildTools(),
        onToolCall: _recordAndDispatch,
        imageBytesBase64: imageBase64,
        imageMimeType: imageMimeType,
      )) {
        buffer.write(chunk);
        _streamingText = buffer.toString();
        notifyListeners();
      }
      final reply = buffer.toString().trim();
      if (reply.isNotEmpty) {
        await _conversations.appendMessage(
          ChatMessage(
            role: 'model',
            text: reply,
            toolCalls: _streamingToolCalls.isEmpty
                ? null
                : List.of(_streamingToolCalls),
          ),
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
      _streamingToolCalls.clear();
      _loading = false;
      notifyListeners();
    }
  }

  // Records the tool name for UI display, then delegates to the real handler.
  Future<Map<String, Object?>> _recordAndDispatch(FunctionCall call) async {
    _streamingToolCalls.add(call.name);
    notifyListeners();
    return _coachTools.handleCall(call);
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  // Static prompt — live data is fetched by the model via the coach tools,
  // keeping the prefix stable for implicit prompt caching.
  String _buildSystemPrompt() => GeminiContextBuilder.buildCoachSystemPrompt(
        userName: _settings.userName,
        unitLabel: _settings.unitLabel,
      );

  /// Prior turns (everything before the user message just appended).
  /// Replaces historical image payloads with concise textual placeholder
  /// so multi-turn conversations do not cause unbounded storage or token consumption.
  List<Content> _buildHistory() {
    final msgs = _conversations.activeMessages;
    final prior =
        msgs.length > 1 ? msgs.sublist(0, msgs.length - 1) : <ChatMessage>[];
    return prior.map((m) {
      final parts = <Part>[];
      if (m.text.isNotEmpty) {
        parts.add(TextPart(m.text));
      } else if (m.imageBytesBase64 != null && m.imageBytesBase64!.isNotEmpty) {
        parts.add(TextPart('[Attached image]'));
      } else {
        parts.add(TextPart(''));
      }
      return Content(m.role, parts);
    }).toList();
  }
}
