import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/ai/ai_failure.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';

String response(List<Map<String, Object?>> parts) =>
    'data: ${jsonEncode({
      'candidates': [
        {
          'index': 0,
          'content': {'role': 'model', 'parts': parts},
          'finishReason': 'STOP',
        },
      ],
    })}\n\n';

void main() {
  test(
    'legacy tool-enabled chat uses the runtime and preserves signed calls',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final service = GeminiAiService(
        modelClientFactory: () => MockClient((incoming) async {
          final body = jsonDecode(incoming.body) as Map<String, dynamic>;
          bodies.add(body);
          return http.Response(
            response(
              bodies.length == 1
                  ? [
                      {
                        'functionCall': {
                          'id': 'native',
                          'name': 'save',
                          'args': {'title': 'Draft'},
                        },
                        'thoughtSignature': 'opaque',
                      },
                    ]
                  : [
                      {'text': 'Saved.'},
                    ],
            ),
            200,
          );
        }),
      )..init('fixture-key');
      addTearDown(service.dispose);
      var calls = 0;
      final text = await service
          .streamChatReply(
            userMessage: 'Save this',
            systemPrompt: 'Test',
            history: [Content.text('Earlier')],
            imageBytesBase64: 'AQID',
            imageMimeType: 'image/png',
            tools: [
              Tool(
                functionDeclarations: [
                  FunctionDeclaration(
                    'save',
                    'Save',
                    Schema.object(
                      properties: {'title': Schema.string()},
                      requiredProperties: ['title'],
                    ),
                  ),
                ],
              ),
            ],
            onToolCall: (call) async {
              calls++;
              expect(call.name, 'save');
              expect(call.args, {'title': 'Draft'});
              return {'saved': true};
            },
          )
          .join();
      expect(text, 'Saved.');
      expect(calls, 1);
      expect(bodies, hasLength(2));
      expect(
        (bodies.first['tools'] as List).single,
        contains('functionDeclarations'),
      );
      expect(bodies.first.containsKey('toolConfig'), isFalse);
      expect(jsonEncode(bodies.first['contents']), contains('AQID'));
      expect(jsonEncode(bodies.first['contents']), contains('Earlier'));
      final contents = bodies.last['contents'] as List<dynamic>;
      expect(contents[1]['parts'][0]['thoughtSignature'], 'opaque');
      expect(contents[2]['parts'][0]['functionResponse']['id'], 'native');
      expect(contents[2]['parts'][0]['functionResponse']['response'], {
        'saved': true,
      });
    },
  );

  test('unconfigured coach streams expose a nonretryable AiFailure', () async {
    final service = GeminiAiService();
    addTearDown(service.dispose);
    await expectLater(
      service
          .streamCoachReply(
            userMessage: 'Hi',
            systemPrompt: 'Test',
            history: [],
          )
          .toList(),
      throwsA(isA<AiFailure>().having((e) => e.canRetry, 'retry', false)),
    );
  });

  test(
    'provider diagnostics stay private at the legacy API boundary',
    () async {
      final service = GeminiAiService(
        modelClientFactory: () => MockClient(
          (_) async => http.Response('secret-key private details', 403),
        ),
      )..init('fixture-key');
      addTearDown(service.dispose);
      await expectLater(
        service
            .streamChatReply(
              userMessage: 'Hi',
              systemPrompt: 'Test',
              history: [],
            )
            .toList(),
        throwsA(
          isA<AiFailure>()
              .having((e) => e.canRetry, 'retry', false)
              .having((e) => e.message, 'safe', isNot(contains('secret-key'))),
        ),
      );
    },
  );

  test(
    'a failing legacy tool callback cannot offer replay of its write',
    () async {
      var calls = 0;
      final service = GeminiAiService(
        modelClientFactory: () => MockClient(
          (_) async => http.Response(
            response([
              {
                'functionCall': {
                  'id': 'native',
                  'name': 'save',
                  'args': <String, Object?>{},
                },
              },
            ]),
            200,
          ),
        ),
      )..init('fixture-key');
      addTearDown(service.dispose);
      await expectLater(
        service
            .streamCoachReply(
              userMessage: 'Save',
              systemPrompt: 'Test',
              history: [],
              tools: [
                Tool(
                  functionDeclarations: [
                    FunctionDeclaration(
                      'save',
                      'Save',
                      Schema.object(properties: {}),
                    ),
                  ],
                ),
              ],
              onToolCall: (_) async {
                calls++;
                throw StateError('private failure');
              },
            )
            .toList(),
        throwsA(isA<AiFailure>().having((e) => e.canRetry, 'retry', false)),
      );
      expect(calls, 1);
    },
  );
}
