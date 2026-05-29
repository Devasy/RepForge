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
      service.recordUsage(prompt: 100, response: 40, total: 140);
      // Let the fire-and-forget persist complete.
      await Future<void>.delayed(Duration.zero);

      final reloaded = GeminiAiService(storage: storage);
      await reloaded.loadUsage();

      expect(reloaded.promptTokensUsed, 100);
      expect(reloaded.responseTokensUsed, 40);
      expect(reloaded.totalTokensUsed, 140);
      expect(reloaded.aiRequestCount, 1);
    });

    test('resetUsage zeros counters and persists', () async {
      service.recordUsage(prompt: 100, response: 40, total: 140);
      await service.resetUsage();

      expect(service.totalTokensUsed, 0);
      expect(service.aiRequestCount, 0);

      final reloaded = GeminiAiService(storage: storage);
      await reloaded.loadUsage();
      expect(reloaded.totalTokensUsed, 0);
      expect(reloaded.aiRequestCount, 0);
    });
  });
}
