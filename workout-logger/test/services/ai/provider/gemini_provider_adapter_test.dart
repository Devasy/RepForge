import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/ai/provider/gemini_provider_adapter.dart';
import 'package:repforge/services/ai/provider/model_message.dart';
import 'package:repforge/services/ai/provider/model_step.dart';
import 'package:repforge/services/ai/tools/tool_spec.dart';

void main() {
  group('GeminiProviderAdapter', () {
    test('yields error message if api key is empty', () async {
      final adapter = GeminiProviderAdapter(
        apiKeyGetter: () => '',
        modelGetter: () => 'gemini-1.5-flash',
      );

      final steps = await adapter.streamStep(
        systemPrompt: 'system',
        messages: [],
        tools: [],
      ).toList();

      expect(steps.length, 2);
      expect(steps[0], isA<ModelTextDelta>());
      expect((steps[0] as ModelTextDelta).text, contains('Please add your Gemini API key'));
      expect(steps[1], isA<ModelFinish>());
    });

    test('streams text correctly', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        // Return a mocked SSE stream
        final streamData = '''
data: {"candidates": [{"content": {"parts": [{"text": "Hello "}]}}]}

data: {"candidates": [{"content": {"parts": [{"text": "world!"}]}}]}

data: {"candidates": [{"finishReason": "STOP"}]}
''';
        final stream = Stream.value(utf8.encode(streamData));
        return http.StreamedResponse(stream, 200);
      });

      final adapter = GeminiProviderAdapter(
        apiKeyGetter: () => 'fake-key',
        modelGetter: () => 'gemini-1.5-flash',
        httpClient: mockClient,
      );

      final steps = await adapter.streamStep(
        systemPrompt: 'system',
        messages: [const UserMessage('Hi')],
        tools: [],
      ).toList();

      final textDeltas = steps.whereType<ModelTextDelta>().map((e) => e.text).toList();
      expect(textDeltas, ['Hello ', 'world!']);
      expect(steps.last, isA<ModelFinish>());
    });

    test('translates tools correctly', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final bodyStr = await utf8.decoder.bind(bodyStream).join();
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        expect(body['tools'], isNotNull);
        
        final streamData = '''
data: {"candidates": [{"content": {"parts": [{"functionCall": {"name": "test_tool", "args": {"arg1": "val1"}}}]}}]}
''';
        final stream = Stream.value(utf8.encode(streamData));
        return http.StreamedResponse(stream, 200);
      });

      final adapter = GeminiProviderAdapter(
        apiKeyGetter: () => 'fake-key',
        modelGetter: () => 'gemini-1.5-flash',
        httpClient: mockClient,
      );

      final steps = await adapter.streamStep(
        systemPrompt: 'system',
        messages: [const UserMessage('Hi')],
        tools: [
          ToolSpec(
            name: 'test_tool',
            description: 'A test tool',
            parameters: {'arg1': ToolParam.string()},
          )
        ],
      ).toList();

      final calls = steps.whereType<ModelToolCall>();
      expect(calls.length, 1);
      expect(calls.first.toolName, 'test_tool');
      expect(calls.first.args, {'arg1': 'val1'});
    });
  });
}
