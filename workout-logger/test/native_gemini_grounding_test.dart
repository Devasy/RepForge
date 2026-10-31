import 'dart:convert';
import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_gemini/ai_orchestration_gemini.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/models/web_search_result.dart';
import 'package:repforge/services/ai/gemini_search.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';
import 'package:repforge/services/interfaces/web_grounding_support.dart';

const suggestions =
    '<style>.search{color:green}</style><div class="search">Google Search suggestions</div>';
const grounding = <String, Object?>{
  'webSearchQueries': ['resistance training systematic review'],
  'searchEntryPoint': {'renderedContent': suggestions},
  'groundingChunks': [
    {
      'web': {
        'title': 'Research source',
        'uri': 'https://example.org/research',
      },
    },
  ],
};
String sse(List<JsonMap> parts, {JsonMap? metadata}) =>
    'data: ${jsonEncode({
      'candidates': [
        {
          'index': 0,
          'content': {'role': 'model', 'parts': parts},
          'finishReason': 'STOP',
          'groundingMetadata': ?metadata,
        },
      ],
    })}\n\n';
ModelRequest request(String model, List<ModelMessage> messages) => ModelRequest(
  modelId: model,
  systemPrompt:
      'Use app records for personal data and Google Search for research.',
  messages: messages,
  tools: [
    ToolDefinition(
      name: 'read_history',
      description: 'Read training data.',
      arguments: ValueSchema.object(properties: {}),
    ),
  ],
);

void main() {
  test('agent service enables native Google Search', () async {
    Map<String, dynamic>? body;
    final service = GeminiAiService(
      modelClientFactory: () => MockClient((incoming) async {
        body = jsonDecode(incoming.body) as Map<String, dynamic>;
        return http.Response(
          sse([
            {'text': 'Summary'},
          ]),
          200,
        );
      }),
    )..init('fake-key', model: 'gemini-3.8-flash');
    addTearDown(service.dispose);
    await service
        .stream(
          request('gemini-3.8-flash', [
            ModelMessage(role: 'user', text: 'Research'),
          ]),
          CancellationToken(),
        )
        .toList();
    expect(
      (body!['tools'] as List).whereType<Map>().any(
        (tool) => tool.containsKey('googleSearch'),
      ),
      isTrue,
    );
  });

  for (final model in ['gemini-3.6-flash', 'gemini-3.8-flash']) {
    test(
      '$model circulates signed built-in search alongside app tool calls',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final parts = <JsonMap>[
          {
            'toolCall': {
              'toolType': 'GOOGLE_SEARCH_WEB',
              'id': 'search-1',
              'args': {
                'queries': ['resistance training systematic review'],
              },
            },
            'thoughtSignature': 'search-signature',
          },
          {
            'toolResponse': {
              'toolType': 'GOOGLE_SEARCH_WEB',
              'id': 'search-1',
              'response': {'search_suggestions': suggestions},
            },
            'thoughtSignature': 'response-signature',
          },
          {
            'functionCall': {
              'name': 'read_history',
              'id': 'history-1',
              'args': {},
            },
            'thoughtSignature': 'function-signature',
          },
        ];
        final provider = GeminiModelProvider(
          apiKey: 'fake-key',
          googleSearchEnabled: supportsGeminiWebGrounding,
          clientFactory: () => MockClient((incoming) async {
            bodies.add(jsonDecode(incoming.body) as Map<String, dynamic>);
            return http.Response(
              bodies.length == 1
                  ? sse(parts, metadata: grounding)
                  : sse([
                      {'text': 'Based on your records and the sources.'},
                    ]),
              200,
            );
          }),
        );
        final first = await provider
            .stream(
              request(model, [
                ModelMessage(
                  role: 'user',
                  text: 'Review my training with sources',
                ),
              ]),
              CancellationToken(),
            )
            .toList();
        final calls = first
            .whereType<ModelToolCall>()
            .map((event) => event.call)
            .toList();
        expect(calls.map((call) => call.name), ['read_history']);
        expect(
          first.whereType<ModelStatus>().any(
            (event) => event.message.contains('Searching'),
          ),
          isTrue,
        );
        final finish = first.whereType<ModelFinished>().single;
        final meta = jsonObject(finish.providerData['gemini']);
        expect(meta['parts'], parts);
        expect(
          jsonObject(meta['groundingMetadata'])['searchEntryPoint'],
          grounding['searchEntryPoint'],
        );
        expect(
          (bodies.first['tools'] as List).whereType<Map>().any(
            (tool) => tool.containsKey('googleSearch'),
          ),
          isTrue,
        );
        expect(bodies.first['toolConfig'], {
          'includeServerSideToolInvocations': true,
          'functionCallingConfig': {'mode': 'VALIDATED'},
        });
        final history = [
          ModelMessage(role: 'user', text: 'Review my training with sources'),
          ModelMessage(
            role: 'assistant',
            calls: calls,
            providerData: finish.providerData,
          ),
          ModelMessage(
            role: 'tool',
            callId: calls.single.id,
            result: {'workouts': 3},
          ),
        ];
        await provider
            .stream(request(model, history), CancellationToken())
            .toList();
        final contents = bodies.last['contents'] as List;
        expect((contents[1] as Map)['parts'], parts);
        final resultPart =
            ((contents[2] as Map)['parts'] as List).single as Map;
        expect((resultPart['functionResponse'] as Map)['id'], 'history-1');
      },
    );
  }

  test(
    'older model requests retain function calling without unsupported tool combinations',
    () async {
      Map<String, dynamic>? body;
      final provider = GeminiModelProvider(
        apiKey: 'fake-key',
        googleSearchEnabled: supportsGeminiWebGrounding,
        clientFactory: () => MockClient((incoming) async {
          body = jsonDecode(incoming.body) as Map<String, dynamic>;
          return http.Response(
            sse([
              {'text': 'Training summary'},
            ]),
            200,
          );
        }),
      );
      await provider
          .stream(
            request('gemini-2.5-flash', [
              ModelMessage(role: 'user', text: 'Summary'),
            ]),
            CancellationToken(),
          )
          .toList();
      expect(body!.containsKey('toolConfig'), isFalse);
      expect((body!['tools'] as List).single, contains('functionDeclarations'));
    },
  );

  test(
    'search-enabled replies never silently fall back to an incompatible model',
    () async {
      var requests = 0;
      final provider = GeminiModelProvider(
        apiKey: 'fake-key',
        maxRetries: 0,
        googleSearchEnabled: supportsGeminiWebGrounding,
        fallbackModel: (_) => 'gemini-2.5-flash',
        clientFactory: () => MockClient((_) async {
          requests++;
          return http.Response('{}', 404);
        }),
      );
      await expectLater(
        provider
            .stream(
              request('gemini-3.6-flash', [
                ModelMessage(role: 'user', text: 'Research'),
              ]),
              CancellationToken(),
            )
            .toList(),
        throwsA(isA<GeminiFailure>()),
      );
      expect(requests, 1);
    },
  );

  test(
    'grounding survives chat persistence with original suggestions and safe source links',
    () {
      final result = parseGeminiGrounding('Evidence summary', {
        ...grounding,
        'groundingChunks': [
          ...(grounding['groundingChunks']! as List),
          {
            'web': {
              'title': 'Duplicate',
              'uri': 'https://example.org/research',
            },
          },
          {
            'web': {'title': 'Invalid', 'uri': 'javascript:alert(1)'},
          },
          {
            'web': {
              'title': 'Credentials',
              'uri': 'https://user:pass@example.org/',
            },
          },
        ],
      })!;
      expect(result.sources, hasLength(1));
      expect(result.suggestionsHtml, suggestions);
      final message = ChatMessage(
        role: 'model',
        text: result.text,
        webSearch: result,
      );
      final saved = ChatMessage.fromJson(
        jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
      );
      expect(
        saved.webSearch!.sources.single.url,
        'https://example.org/research',
      );
      expect(
        saved.copyWith(text: 'Updated').webSearch!.suggestionsHtml,
        suggestions,
      );
      expect(saved.copyWith(webSearch: null).webSearch, isNull);
      expect(parseGeminiGrounding('Local data only', {}), isNull);
      expect(externalWebUri('data:text/html,hello'), isNull);
    },
  );
}
