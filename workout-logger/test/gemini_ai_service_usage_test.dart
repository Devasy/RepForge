// Unit tests for GeminiAiService token-usage tracking + persistence.

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  group('GeminiAiService token usage', () {
    late MockStorageService storage;
    late GeminiAiService service;

    setUp(() {
      storage = MockStorageService();
      service = GeminiAiService(storage: storage);
    });

    test('starts at zero', () {
      expect(service.totalTokensUsed, 0);
      expect(service.promptTokensUsed, 0);
      expect(service.responseTokensUsed, 0);
      expect(service.aiRequestCount, 0);
    });

    test('recordUsage accumulates across calls', () {
      service.recordUsage(prompt: 10, response: 5, total: 15);
      service.recordUsage(prompt: 20, response: 10, total: 30);

      expect(service.promptTokensUsed, 30);
      expect(service.responseTokensUsed, 15);
      expect(service.totalTokensUsed, 45);
      expect(service.aiRequestCount, 2);
    });

    test('usage is persisted and reloaded by a fresh instance', () async {
      await service.recordUsage(prompt: 100, response: 40, total: 140);

      final reloaded = GeminiAiService(storage: storage);
      await reloaded.loadUsage();

      expect(reloaded.promptTokensUsed, 100);
      expect(reloaded.responseTokensUsed, 40);
      expect(reloaded.totalTokensUsed, 140);
      expect(reloaded.aiRequestCount, 1);
    });

    test('resetUsage zeros counters and persists', () async {
      await service.recordUsage(prompt: 100, response: 40, total: 140);
      await service.resetUsage();

      expect(service.totalTokensUsed, 0);
      expect(service.aiRequestCount, 0);

      final reloaded = GeminiAiService(storage: storage);
      await reloaded.loadUsage();
      expect(reloaded.totalTokensUsed, 0);
      expect(reloaded.aiRequestCount, 0);
    });
  });

  group('GeminiAiService model picker', () {
    test('offers Gemini 3.7 Flash', () {
      expect(
        kGeminiModels,
        contains(('gemini-3.7-flash', 'Gemini 3.7 Flash')),
      );
    });

    test('model ids are unique and the default is one of them', () {
      final ids = kGeminiModels.map((e) => e.$1).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, contains(kDefaultGeminiModel));
    });

    test('every offered model has a defined fallback shape', () {
      // A model either falls back to another offered model or terminates the
      // chain; it must never point at an id the picker doesn't know.
      final ids = kGeminiModels.map((e) => e.$1).toSet();
      for (final id in ids) {
        final next = getFallbackModel(id);
        if (next != null) expect(ids, contains(next), reason: id);
      }
    });

    test('a selected model can be initialised and reported back', () {
      final service = GeminiAiService(storage: MockStorageService());
      service.init('fake_test_api_key', model: 'gemini-3.7-flash');
      expect(service.currentModel, 'gemini-3.7-flash');
    });
  });
}
