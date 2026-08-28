// Unit tests for Gemini thinking-level support and clamping.

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';

void main() {
  group('supportedThinkingLevels', () {
    test('gemini-3.7-flash does not support minimal', () {
      expect(supportedThinkingLevels('gemini-3.7-flash'), ['low', 'medium', 'high']);
    });

    test('other gemini-3.x models support all four levels', () {
      expect(supportedThinkingLevels('gemini-3.6-flash'), kThinkingLevels);
      expect(supportedThinkingLevels('gemini-3.5-flash'), kThinkingLevels);
      expect(supportedThinkingLevels('gemini-3.5-flash-lite'), kThinkingLevels);
      expect(supportedThinkingLevels('gemini-3.1-flash-lite'), kThinkingLevels);
    });

    test('gemini-2.x models support no thinking levels', () {
      expect(supportedThinkingLevels('gemini-2.5-flash'), isEmpty);
    });
  });

  group('clampThinkingLevel', () {
    test('leaves a supported level unchanged', () {
      expect(clampThinkingLevel('gemini-3.6-flash', 'high'), 'high');
    });

    test('snaps minimal to low for gemini-3.7-flash', () {
      expect(clampThinkingLevel('gemini-3.7-flash', 'minimal'), 'low');
    });

    test('leaves the level unchanged for a model with no thinking levels', () {
      expect(clampThinkingLevel('gemini-2.5-flash', 'minimal'), 'minimal');
    });
  });

  group('GeminiAiService thinking level', () {
    test('defaults to kDefaultThinkingLevel', () {
      final service = GeminiAiService();
      expect(service.thinkingLevel, kDefaultThinkingLevel);
    });

    test('updateThinkingLevel changes the level', () {
      final service = GeminiAiService();
      service.updateThinkingLevel('high');
      expect(service.thinkingLevel, 'high');
    });

    test('updateThinkingLevel clamps against the current model', () {
      final service = GeminiAiService();
      service.updateModel('gemini-3.7-flash');
      service.updateThinkingLevel('minimal');
      expect(service.thinkingLevel, 'low');
    });

    test('updateModel re-clamps an already-set thinking level', () {
      final service = GeminiAiService();
      service.updateThinkingLevel('minimal');
      service.updateModel('gemini-3.7-flash');
      expect(service.thinkingLevel, 'low');
    });

    test('init clamps the supplied thinking level against the supplied model', () {
      final service = GeminiAiService();
      service.init('key', model: 'gemini-3.7-flash', thinkingLevel: 'minimal');
      expect(service.thinkingLevel, 'low');
    });
  });

  group('getFallbackModel', () {
    test('gemini-3.7-flash falls back to gemini-3.6-flash', () {
      expect(getFallbackModel('gemini-3.7-flash'), 'gemini-3.6-flash');
    });
  });
}
