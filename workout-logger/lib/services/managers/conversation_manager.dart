// Conversation Manager (Single Responsibility Principle)
//
// Single source of truth for persisted AI coach conversations. Owns the
// in-memory list + the currently active conversation, and mirrors every
// mutation to storage. Does NOT talk to the AI backend — that's the
// AiCoachViewModel's job.

import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';

/// Manages the lifecycle of AI coach [Conversation]s (load, create, append,
/// rename, delete) backed by [IStorageService].
///
/// [kind] scopes this manager to a specific conversation category
/// (e.g. `'coach'` or `'optimizer'`). Only conversations with a matching
/// [Conversation.kind] are loaded or created by this instance.
class ConversationManager extends ChangeNotifier {
  final IStorageService _storage;
  final String kind;

  List<Conversation> _conversations = [];
  Conversation? _active;

  ConversationManager(this._storage, {this.kind = 'coach'});

  /// All conversations, most-recently-updated first.
  List<Conversation> get conversations => List.unmodifiable(_conversations);

  /// The conversation currently shown in the coach screen, or null for a
  /// fresh (unsaved) chat.
  Conversation? get active => _active;

  /// Messages of the active conversation (empty for a fresh chat).
  List<ChatMessage> get activeMessages => _active?.messages ?? const [];

  /// Load all conversations from storage. Does not change the active one.
  /// Only conversations whose [Conversation.kind] matches [kind] are loaded.
  Future<void> loadConversations() async {
    final all = await _storage.getAllConversations();
    _conversations = all.where((c) => c.kind == kind).toList();
    notifyListeners();
  }

  /// Begin a fresh conversation. Nothing is persisted until the first message
  /// is appended (avoids littering storage with empty chats).
  void startNewConversation() {
    _active = null;
    notifyListeners();
  }

  /// Make [id] the active conversation, if it exists.
  void selectConversation(String id) {
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    _active = _conversations[idx];
    notifyListeners();
  }

  /// Append [message] to the active conversation, creating one if needed,
  /// then persist. The conversation title is derived from the first user
  /// message. Bumps `updatedAt` and re-sorts the list newest-first.
  Future<void> appendMessage(ChatMessage message) async {
    final current = _active;
    final Conversation updated;

    if (current == null) {
      updated = Conversation(
        title: _deriveTitle(message),
        kind: kind,
        messages: [message],
      );
    } else {
      final title = current.title.isEmpty && message.role == 'user'
          ? _deriveTitle(message)
          : current.title;
      updated = current.copyWith(
        title: title,
        updatedAt: DateTime.now(),
        messages: [...current.messages, message],
      );
    }

    _active = updated;
    _upsert(updated);
    await _storage.saveConversation(updated);
    notifyListeners();
  }

  /// Rename a conversation.
  Future<void> renameConversation(String id, String title) async {
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final updated = _conversations[idx].copyWith(
      title: title.trim(),
      updatedAt: DateTime.now(),
    );
    if (_active?.id == id) _active = updated;
    _upsert(updated);
    await _storage.saveConversation(updated);
    notifyListeners();
  }

  /// Delete a conversation. Clears the active one if it was deleted.
  Future<void> deleteConversation(String id) async {
    _conversations = _conversations.where((c) => c.id != id).toList();
    if (_active?.id == id) _active = null;
    await _storage.deleteConversation(id);
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _upsert(Conversation conversation) {
    final next = _conversations.where((c) => c.id != conversation.id).toList()
      ..add(conversation)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _conversations = next;
  }

  String _deriveTitle(ChatMessage message) {
    final text = message.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return 'New chat';
    return text.length <= 40 ? text : '${text.substring(0, 40).trim()}…';
  }
}
