// Unit tests for ConversationManager — persistence + active-conversation logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/conversation_manager.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  group('ConversationManager', () {
    late MockStorageService storage;
    late ConversationManager manager;

    setUp(() {
      storage = MockStorageService();
      manager = ConversationManager(storage);
    });

    test('appendMessage creates a conversation and persists it', () async {
      await manager.appendMessage(
        ChatMessage(role: 'user', text: 'How is my bench press?'),
      );

      expect(manager.active, isNotNull);
      expect(manager.activeMessages, hasLength(1));

      // Persisted to storage.
      final stored = await storage.getAllConversations();
      expect(stored, hasLength(1));
      expect(stored.first.messages.first.text, 'How is my bench press?');
    });

    test('title is derived from the first user message', () async {
      await manager.appendMessage(
        ChatMessage(role: 'user', text: 'Plan my next push day please'),
      );
      expect(manager.active!.title, 'Plan my next push day please');
    });

    test('long first message title is truncated', () async {
      final long = 'a' * 80;
      await manager.appendMessage(ChatMessage(role: 'user', text: long));
      expect(manager.active!.title.length, lessThanOrEqualTo(41));
      expect(manager.active!.title.endsWith('…'), isTrue);
    });

    test('multiple messages append to the same active conversation', () async {
      await manager.appendMessage(ChatMessage(role: 'user', text: 'hi'));
      await manager.appendMessage(ChatMessage(role: 'model', text: 'hello!'));

      expect(manager.activeMessages, hasLength(2));
      final stored = await storage.getAllConversations();
      expect(stored, hasLength(1));
      expect(stored.first.messages, hasLength(2));
    });

    test('reload restores conversations from storage', () async {
      await manager.appendMessage(ChatMessage(role: 'user', text: 'first'));

      final fresh = ConversationManager(storage);
      await fresh.loadConversations();
      expect(fresh.conversations, hasLength(1));
      expect(fresh.conversations.first.messages.first.text, 'first');
    });

    test('conversations are sorted most-recently-updated first', () async {
      // Small delays keep updatedAt timestamps distinct (millisecond clock).
      await manager.appendMessage(ChatMessage(role: 'user', text: 'older'));
      final olderId = manager.active!.id;

      await Future<void>.delayed(const Duration(milliseconds: 5));
      manager.startNewConversation();
      await manager.appendMessage(ChatMessage(role: 'user', text: 'newer'));
      final newerId = manager.active!.id;

      expect(manager.conversations.first.id, newerId);

      // Touching the older one bumps it to the front.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      manager.selectConversation(olderId);
      await manager.appendMessage(ChatMessage(role: 'model', text: 'reply'));
      expect(manager.conversations.first.id, olderId);
    });

    test('startNewConversation clears the active conversation', () async {
      await manager.appendMessage(ChatMessage(role: 'user', text: 'hi'));
      expect(manager.active, isNotNull);

      manager.startNewConversation();
      expect(manager.active, isNull);
      expect(manager.activeMessages, isEmpty);
      // The prior conversation is still saved.
      expect(manager.conversations, hasLength(1));
    });

    test('deleteConversation removes it and clears active when needed', () async {
      await manager.appendMessage(ChatMessage(role: 'user', text: 'hi'));
      final id = manager.active!.id;

      await manager.deleteConversation(id);

      expect(manager.active, isNull);
      expect(manager.conversations, isEmpty);
      expect(await storage.getAllConversations(), isEmpty);
    });

    test('renameConversation updates the title and persists', () async {
      await manager.appendMessage(ChatMessage(role: 'user', text: 'hi'));
      final id = manager.active!.id;

      await manager.renameConversation(id, 'My chat');

      expect(manager.active!.title, 'My chat');
      final stored = await storage.getConversation(id);
      expect(stored!.title, 'My chat');
    });

    test('kind-scoped manager only loads matching conversations', () async {
      // Seed two conversations directly into storage with different kinds.
      final coachConv = Conversation(title: 'coach chat', kind: 'coach');
      final optimizerConv =
          Conversation(title: 'optimizer chat', kind: 'optimizer');
      await storage.saveConversation(coachConv);
      await storage.saveConversation(optimizerConv);

      final optimizerManager = ConversationManager(storage, kind: 'optimizer');
      await optimizerManager.loadConversations();

      expect(optimizerManager.conversations, hasLength(1));
      expect(optimizerManager.conversations.first.title, 'optimizer chat');
    });

    test('optimizer manager stamps kind on new conversations', () async {
      final optimizerManager = ConversationManager(storage, kind: 'optimizer');
      await optimizerManager.appendMessage(
        ChatMessage(role: 'user', text: 'Optimize Push Day'),
      );
      expect(optimizerManager.active!.kind, 'optimizer');

      final stored = await storage.getAllConversations();
      expect(stored.first.kind, 'optimizer');
    });

    test('default manager uses coach kind', () async {
      await manager.appendMessage(ChatMessage(role: 'user', text: 'hi'));
      expect(manager.active!.kind, 'coach');
    });
  });
}
