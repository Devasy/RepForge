import 'dart:convert';
import 'dart:async';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import '../services/ai/ai_failure.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/models.dart';
import '../services/interfaces/ai_service_interface.dart';
import '../services/ai/coach_tool_service.dart';
import '../services/managers/conversation_manager.dart';
import '../services/settings_provider.dart';
import '../services/ai/orchestration/repforge_agents.dart';
import '../services/ai/orchestration/agent_change_review.dart';

class AiCoachViewModel extends ChangeNotifier {
  final IAiService _ai;
  final CoachToolService _coachTools;
  final ConversationManager _conversations;
  final SettingsProvider _settings;

  late final RepForgeAgents _agents;
  RepForgeAgentSession? _session;
  bool _loading = false;
  bool _disposed = false;
  AiFailure? _localFailure;
  Uint8List? _pendingImageBytes;
  String? _pendingImageMimeType;

  AiCoachViewModel({
    required IAiService ai,
    required CoachToolService coachTools,
    required ConversationManager conversations,
    required SettingsProvider settings,
    RepForgeAgents? agents,
  }) : _ai = ai,
       _coachTools = coachTools,
       _conversations = conversations,
       _settings = settings {
    _agents = agents ?? RepForgeAgents.inMemory(ai);
    _conversations.addListener(_notify);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session?.removeListener(_notify);
    _session = null;
    _conversations.removeListener(_notify);
    super.dispose();
  }

  AiFailure? get failure => _localFailure ?? _session?.failure;
  bool get canRetry => !_loading && (_session?.canRetry ?? false);
  Future<void> retry() async {
    await _session?.retry();
    _notify();
  }

  AgentChangeReview? get changeReview => _session?.changeReview;
  bool get isRunning => _session?.state.isRunning ?? false;
  String get statusText => _session?.statusText ?? '';
  bool get isConfigured => _ai.isConfigured;
  bool get isLoading => _loading || (_session?.isLoading ?? false);
  bool get _navigationBusy => _loading || (_session?.isWorking ?? false);
  String get streamingText => _session?.streamingText ?? '';
  List<String> get streamingToolCalls =>
      List.unmodifiable(_session?.toolCalls ?? const <String>[]);
  List<ChatMessage> get messages => _conversations.activeMessages;
  List<Conversation> get conversations => _conversations.conversations;
  String? get activeConversationId => _conversations.active?.id;
  Uint8List? get pendingImageBytes => _pendingImageBytes;
  bool get hasPendingImage => _pendingImageBytes != null;
  PendingAgentInput? get pendingInput => _session?.pendingInput;
  bool get needsRecovery => _session?.state.needsRecovery ?? false;
  Future<bool> submitInput(PendingAgentInput target, Object? value) async =>
      await _session?.submit(target, value) ?? false;
  Future<void> cancelRun() async {
    await _session?.cancel();
    _notify();
  }

  void _bindSession() {
    _session?.removeListener(_notify);
    _session = _agents.session(
      conversations: _conversations,
      settings: _settings,
      tools: _coachTools,
    );
    if (!_disposed) _session!.addListener(_notify);
  }

  Future<void> _restoreActive() async {
    if (_conversations.active == null) return;
    _loading = true;
    _bindSession();
    _notify();
    try {
      await _session!.restore();
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> loadConversations() async {
    await _conversations.loadConversations();
    await _restoreActive();
  }

  void newConversation() {
    if (_navigationBusy) return;
    _localFailure = null;
    _session?.removeListener(_notify);
    _session = null;
    _conversations.startNewConversation();
  }

  void selectConversation(String id) {
    if (_navigationBusy) return;
    _localFailure = null;
    _conversations.selectConversation(id);
    unawaited(_restoreActive());
  }

  Future<void> deleteConversation(String id) async {
    if (_navigationBusy) return;
    await _agents.forget('coach', id);
    if (id == activeConversationId) {
      _localFailure = null;
      _session?.removeListener(_notify);
      _session = null;
    }
    await _conversations.deleteConversation(id);
  }

  static const int _maxImageBytes = 5 * 1024 * 1024; // 5 MB limit
  static const Set<String> _supportedImageMimes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Pick an image to attach to the next message.
  Future<void> pickImage() async {
    if (isLoading) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
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

      if (fileLength == null ||
          fileLength <= 0 ||
          fileLength > _maxImageBytes) {
        debugPrint(
          'File size unavailable or exceeds limit ($fileLength bytes)',
        );
        return;
      }

      final Uint8List bytes = file.path != null
          ? await File(file.path!).readAsBytes()
          : await file.readAsBytes();
      if (bytes.isEmpty) return;

      _pendingImageBytes = bytes;
      _pendingImageMimeType = mimeType;
      _notify();
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// Clear the currently attached pending image.
  void clearPendingImage() {
    _pendingImageBytes = null;
    _pendingImageMimeType = null;
    _notify();
  }

  @visibleForTesting
  void setPendingImageForTesting(Uint8List? bytes, String? mimeType) {
    _pendingImageBytes = bytes;
    _pendingImageMimeType = mimeType;
    _notify();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && !hasPendingImage) || isLoading || needsRecovery) {
      return;
    }
    _loading = true;
    _localFailure = null;
    final image = _pendingImageBytes == null
        ? null
        : base64Encode(_pendingImageBytes!);
    final mime = _pendingImageMimeType;
    clearPendingImage();
    _notify();
    try {
      await _conversations.appendMessage(
        ChatMessage(
          role: 'user',
          text: trimmed,
          imageBytesBase64: image,
          imageMimeType: mime,
        ),
      );
      _bindSession();
      await _session!.send(
        trimmed,
        attachments: [
          if (image != null) {'mimeType': mime ?? 'image/jpeg', 'data': image},
        ],
      );
    } catch (_) {
      _localFailure = const AiFailure(
        'Your chat could not be saved. Check available storage and reopen the chat before continuing.',
        canRetry: false,
      );
    } finally {
      _loading = false;
      _notify();
    }
  }
}
