import 'dart:convert';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_gemini/ai_orchestration_gemini.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

JsonMap packet(List<JsonMap> parts, {String? finish = 'STOP'}) => {
  'candidates': [
    {
      'index': 0,
      'content': {'role': 'model', 'parts': parts},
      'finishReason': ?finish,
    },
  ],
};
ModelRequest request({List<ModelMessage>? messages}) => ModelRequest(
  modelId: 'gemini-test',
  systemPrompt: 'Test',
  tools: [],
  messages: messages ?? [ModelMessage(role: 'user', text: 'Hello')],
);

void main() {
  test(
    'Vertex Express uses global API-key JSON endpoint and hides thoughts',
    () async {
      final diagnostics = <JsonMap>[];
      final provider = GeminiModelProvider(
        apiKey: 'vertex-test-key',
        backend: GeminiBackend.vertexExpress,
        onDiagnostic: diagnostics.add,
        generationConfig: (_) => {
          'thinkingConfig': {'thinkingLevel': 'medium'},
        },
        clientFactory: () => MockClient((r) async {
          expect(r.method, 'POST');
          expect(
            r.url.toString(),
            'https://aiplatform.googleapis.com/v1/publishers/google/models/gemini-3.8-flash:generateContent',
          );
          expect(r.headers['x-goog-api-key'], 'vertex-test-key');
          final body = jsonDecode(r.body) as Map;
          expect(body['contents'], isNotEmpty);
          expect(
            body['generationConfig']['thinkingConfig']['thinkingLevel'],
            'medium',
          );
          return http.Response(
            jsonEncode(
              packet([
                {'text': 'hidden', 'thought': true},
                {'text': 'First '},
                {'text': 'second'},
              ]),
            ),
            200,
          );
        }),
      );
      final events = await provider
          .stream(
            ModelRequest(
              modelId: 'gemini-3.8-flash',
              systemPrompt: 'Coach',
              messages: [ModelMessage(role: 'user', text: 'Test')],
              tools: [],
            ),
            CancellationToken(),
          )
          .toList();
      expect(
        events.whereType<ModelText>().map((e) => e.text).join(),
        'First second',
      );
      expect(
        events.whereType<ModelFinished>().single.reason,
        ModelFinishReason.stop,
      );
      expect(diagnostics.first['provider'], 'vertexExpress');
      expect(diagnostics.first['effectiveGenerationConfig'], {
        'thinkingConfig': {'thinkingLevel': 'medium'},
      });
    },
  );

  test(
    'Vertex one-shot and tool calls keep the Gemini wire contract',
    () async {
      final provider = GeminiModelProvider(
        apiKey: 'key',
        backend: GeminiBackend.vertexExpress,
        clientFactory: () => MockClient((r) async {
          expect(r.url.host, 'aiplatform.googleapis.com');
          expect(r.url.query, isEmpty);
          return http.Response(
            jsonEncode(
              packet([
                {
                  'functionCall': {
                    'name': 'get_progress_overview',
                    'args': {'days': 183},
                  },
                  'thoughtSignature': 'signed',
                },
              ]),
            ),
            200,
          );
        }),
      );
      final events = await provider
          .stream(request(), CancellationToken())
          .toList();
      expect(
        events.whereType<ModelToolCall>().single.call.arguments['days'],
        183,
      );
      expect(
        events.whereType<ModelFinished>().single.providerData['gemini'],
        isNotNull,
      );
      final result = await provider.generate(
        modelId: 'gemini-3.8-flash',
        body: {'contents': []},
      );
      expect(result['candidates'], isNotEmpty);
    },
  );
}
