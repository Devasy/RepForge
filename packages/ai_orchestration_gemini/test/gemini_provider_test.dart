import 'dart:async';
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
String sse(Object data) => 'data: ${jsonEncode(data)}\r\n\r\n';
ModelRequest request({List<ModelMessage>? messages}) => ModelRequest(
  modelId: 'gemini-test',
  systemPrompt: 'Test',
  tools: [],
  messages: messages ?? [ModelMessage(role: 'user', text: 'Hello')],
);

void main() {
  test(
    'one-shot generation shares fallback, keeps JSON settings and closes clients',
    () async {
      final requests = <http.Request>[];
      final diagnostics = <JsonMap>[];
      final provider = GeminiModelProvider(
        apiKey: 'key',
        maxRetries: 0,
        fallbackModel: (_) => 'small',
        generationConfig: (model) => {
          'thinkingConfig': {'model': model},
        },
        onDiagnostic: diagnostics.add,
        clientFactory: () => MockClient((incoming) async {
          requests.add(incoming);
          return requests.length == 1
              ? http.Response('overloaded', 503)
              : http.Response(
                  jsonEncode({
                    'candidates': [
                      {
                        'content': {
                          'parts': [
                            {'text': '{"ok":true}'},
                          ],
                        },
                      },
                    ],
                  }),
                  200,
                );
        }),
      );
      final body = <String, Object?>{
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'Request'},
            ],
          },
        ],
        'generationConfig': {'responseMimeType': 'application/json'},
      };
      final result = await provider.generate(modelId: 'primary', body: body);
      expect(result['candidates'], hasLength(1));
      expect(
        requests.every((r) => r.url.path.endsWith(':generateContent')),
        true,
      );
      expect(requests.last.url.path, contains('small:'));
      expect(requests.last.url.queryParameters.containsKey('key'), false);
      final config = jsonObject(
        jsonObject(jsonDecode(requests.last.body))['generationConfig'],
      );
      expect(config['responseMimeType'], 'application/json');
      expect(config['thinkingConfig'], {'model': 'small'});
      expect(diagnostics.last['event'], 'response_complete');
      expect(body['generationConfig'], {
        'responseMimeType': 'application/json',
      });
    },
  );

  test(
    'timeouts, overload and unavailable models traverse the fallback ladder',
    () async {
      final models = <String>[];
      final diagnostics = <JsonMap>[];
      final provider = GeminiModelProvider(
        apiKey: 'secret',
        timeout: const Duration(milliseconds: 100),
        retryDelay: (_) => Duration.zero,
        onDiagnostic: diagnostics.add,
        fallbackModel: (model) => {'a': 'b', 'b': 'c', 'c': 'd'}[model],
        clientFactory: () => MockClient((incoming) async {
          final model = incoming.url.pathSegments.last.split(':').first;
          models.add(model);
          if (model == 'a') return Completer<http.Response>().future;
          if (model == 'b') return http.Response('overloaded', 503);
          if (model == 'c') return http.Response('removed', 404);
          return http.Response(
            sse(
              packet([
                {'text': 'Recovered'},
              ]),
            ),
            200,
          );
        }),
      );
      final events = await provider
          .stream(
            ModelRequest(
              modelId: 'a',
              systemPrompt: 'Test',
              messages: [ModelMessage(role: 'user', text: 'Hello')],
              tools: [],
            ),
            CancellationToken(),
          )
          .toList();
      expect(models, ['a', 'b', 'b', 'c', 'd']);
      expect(events.whereType<ModelText>().single.text, 'Recovered');
      expect(
        events.whereType<ModelStatus>().any(
          (e) => e.message.contains('another model'),
        ),
        true,
      );
      expect(diagnostics.where((e) => e['event'] == 'fallback'), hasLength(3));
      expect(jsonEncode(diagnostics), isNot(contains('secret')));
    },
  );

  test('minute quota retries then falls back without cycling', () async {
    final models = <String>[];
    final provider = GeminiModelProvider(
      apiKey: 'key',
      retryDelay: (_) => Duration.zero,
      fallbackModel: (model) => model == 'a' ? 'b' : 'a',
      clientFactory: () => MockClient((incoming) async {
        models.add(incoming.url.pathSegments.last.split(':').first);
        return http.Response(
          jsonEncode({
            'error': {
              'status': 'RESOURCE_EXHAUSTED',
              'details': [
                {
                  'quotaMetric': 'generate_content_free_tier_requests',
                  'quotaId':
                      'GenerateRequestsPerMinutePerProjectPerModel-FreeTier',
                },
              ],
            },
          }),
          429,
        );
      }),
    );
    await expectLater(
      provider
          .stream(
            ModelRequest(
              modelId: 'a',
              systemPrompt: 'Test',
              messages: [],
              tools: [],
            ),
            CancellationToken(),
          )
          .toList(),
      throwsA(
        isA<GeminiFailure>().having((e) => e.code, 'code', 'model_quota'),
      ),
    );
    expect(models, ['a', 'a', 'b', 'b']);
  });

  test('bad requests and authentication errors never switch models', () async {
    for (final code in [400, 401, 403]) {
      var attempts = 0;
      final provider = GeminiModelProvider(
        apiKey: 'key',
        maxRetries: 0,
        fallbackModel: (_) => 'fallback',
        clientFactory: () => MockClient((_) async {
          attempts++;
          return http.Response('private diagnostic', code);
        }),
      );
      await expectLater(
        provider.stream(request(), CancellationToken()).toList(),
        throwsA(isA<GeminiFailure>()),
      );
      expect(attempts, 1);
    }
  });

  test(
    'partial streamed output is not replayed after an idle timeout',
    () async {
      final output = StreamController<List<int>>();
      addTearDown(output.close);
      var attempts = 0;
      final provider = GeminiModelProvider(
        apiKey: 'key',
        timeout: const Duration(milliseconds: 100),
        fallbackModel: (_) => 'fallback',
        clientFactory: () => MockClient.streaming((_, _) async {
          attempts++;
          output.add(
            utf8.encode(
              sse(
                packet([
                  {'text': 'Partial'},
                ], finish: null),
              ),
            ),
          );
          return http.StreamedResponse(output.stream, 200);
        }),
      );
      final texts = <String>[];
      await expectLater(
        provider.stream(request(), CancellationToken()).forEach((event) {
          if (event is ModelText) texts.add(event.text);
        }),
        throwsA(
          isA<GeminiFailure>().having((e) => e.code, 'code', 'model_timeout'),
        ),
      );
      expect(texts, ['Partial']);
      expect(attempts, 1);
    },
  );

  test('total request budget bounds an exhausted fallback ladder', () async {
    final models = <String>[];
    final provider = GeminiModelProvider(
      apiKey: 'key',
      timeout: const Duration(milliseconds: 80),
      maxRequestTime: const Duration(milliseconds: 180),
      fallbackModel: (m) => '${m}x',
      clientFactory: () => MockClient((incoming) async {
        models.add(incoming.url.pathSegments.last);
        return Completer<http.Response>().future;
      }),
    );
    await expectLater(
      provider
          .stream(request(), CancellationToken())
          .toList()
          .timeout(const Duration(seconds: 2)),
      throwsA(
        isA<GeminiFailure>().having((e) => e.code, 'code', 'model_timeout'),
      ),
    );
    expect(models.length, inInclusiveRange(1, 8));
    expect(models.toSet(), hasLength(models.length));
  });

  test('retry backoff can exceed the I/O timeout', () async {
    var attempts = 0;
    final provider = GeminiModelProvider(
      apiKey: 'key',
      timeout: const Duration(milliseconds: 100),
      retryDelay: (_) => const Duration(milliseconds: 250),
      clientFactory: () => MockClient(
        (_) async => ++attempts == 1
            ? http.Response('busy', 503)
            : http.Response(
                sse(
                  packet([
                    {'text': 'Ready'},
                  ]),
                ),
                200,
              ),
      ),
    );
    final events = await provider
        .stream(request(), CancellationToken())
        .toList();
    expect(attempts, 2);
    expect(events.whereType<ModelText>().single.text, 'Ready');
  });

  test('cancellation interrupts a long retry backoff', () async {
    final backingOff = Completer<void>();
    var attempts = 0;
    final provider = GeminiModelProvider(
      apiKey: 'key',
      timeout: const Duration(milliseconds: 100),
      retryDelay: (_) {
        backingOff.complete();
        return const Duration(seconds: 30);
      },
      clientFactory: () => MockClient((_) async {
        attempts++;
        return http.Response('busy', 503);
      }),
    );
    final token = CancellationToken();
    final result = expectLater(
      provider.stream(request(), token).toList(),
      throwsA(
        isA<OrchestrationException>().having(
          (e) => e.code,
          'code',
          'cancelled',
        ),
      ),
    );
    await backingOff.future;
    token.cancel();
    await result.timeout(const Duration(seconds: 2));
    expect(attempts, 1);
  });

  test(
    'preserves signed raw parts, same-name native IDs, attachments and usage through a real loop',
    () async {
      final bodies = <JsonMap>[];
      final usages = <JsonMap>[];
      final provider = GeminiModelProvider(
        apiKey: 'secret',
        onUsage: usages.add,
        clientFactory: () => MockClient((incoming) async {
          expect(incoming.url.queryParameters.containsKey('key'), false);
          expect(incoming.headers['x-goog-api-key'], 'secret');
          final body = jsonObject(jsonDecode(incoming.body));
          bodies.add(body);
          if (bodies.length == 1) {
            return http.Response(
              sse(
                packet([
                  {'text': 'Private reasoning', 'thought': true},
                  {
                    'functionCall': {
                      'id': 'a',
                      'name': 'read',
                      'args': <String, Object?>{},
                    },
                    'thoughtSignature': 'opaque-signature',
                  },
                  {
                    'functionCall': {
                      'id': 'b',
                      'name': 'read',
                      'args': <String, Object?>{},
                    },
                  },
                ]),
              ),
              200,
            );
          }
          return http.Response(
            sse(
                  packet([
                    {'text': 'Café'},
                  ], finish: null),
                ) +
                sse({
                  ...packet([
                    {'text': '', 'thoughtSignature': 'tail'},
                  ]),
                  'usageMetadata': {'totalTokenCount': 12},
                }),
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
      );
      var calls = 0;
      final runtime = AgentRuntime(
        store: MemoryCheckpointStore(),
        model: provider,
      );
      final run = await runtime.start(
        workflow: chatWorkflow(
          id: 'chat',
          modelId: 'gemini-test',
          systemPrompt: 'Test',
          tools: ToolRegistry([ReadTool(() => ++calls)]),
        ),
        threadId: 'thread',
        input: {
          'text': 'Report',
          'attachments': [
            {'mimeType': 'image/png', 'data': 'AQID'},
          ],
        },
      );
      final checkpoint = await run.done;
      expect(checkpoint.status, RunStatus.completed);
      expect(calls, 2);
      final contents = bodies[1]['contents']! as List<Object?>;
      final modelParts = jsonObject(contents[1])['parts']! as List<Object?>;
      expect(jsonObject(modelParts[1])['thoughtSignature'], 'opaque-signature');
      final responses = jsonObject(contents[2])['parts']! as List<Object?>;
      expect(
        responses.map(
          (p) => jsonObject(jsonObject(p)['functionResponse'])['id'],
        ),
        ['a', 'b'],
      );
      final userParts = jsonObject(contents[0])['parts']! as List<Object?>;
      expect(jsonObject(userParts.first)['inlineData'], {
        'mimeType': 'image/png',
        'data': 'AQID',
      });
      expect(usages.single['totalTokenCount'], 12);
      final state = const ChatStateCodec().decode(checkpoint.state);
      expect(state.messages.last.text, 'Café');
      expect(state.messages.last.providerData.toString(), contains('tail'));
      expect(
        state.messages.map((m) => m.text).join(),
        isNot(contains('Private reasoning')),
      );
    },
  );

  test(
    'missing native IDs get distinct internal IDs and remain omitted on the wire',
    () async {
      final provider = GeminiModelProvider(
        apiKey: 'key',
        clientFactory: () => MockClient(
          (_) async => http.Response(
            sse(
              packet([
                {
                  'functionCall': {'name': 'read', 'args': <String, Object?>{}},
                },
                {
                  'functionCall': {'name': 'read', 'args': <String, Object?>{}},
                },
              ]),
            ),
            200,
          ),
        ),
      );
      final events = await provider
          .stream(request(), CancellationToken())
          .toList();
      final calls = events
          .whereType<ModelToolCall>()
          .map((e) => e.call)
          .toList();
      expect(calls.map((c) => c.id).toSet(), hasLength(2));
      final wire = geminiContents([
        ModelMessage(role: 'user', text: 'Read'),
        ModelMessage(
          role: 'assistant',
          calls: calls,
          providerData: (events.last as ModelFinished).providerData,
        ),
        for (final call in calls)
          ModelMessage(role: 'tool', callId: call.id, result: {'ok': true}),
      ]);
      for (final part in wire.last['parts']! as List<Object?>) {
        expect(
          jsonObject(jsonObject(part)['functionResponse']).containsKey('id'),
          false,
        );
      }
    },
  );

  test(
    'SSE handles fragmented UTF-8, multiline events and an unterminated final event',
    () async {
      final raw = utf8.encode(
        'data: {"candidates":\r\ndata: [{"content":{"parts":[{"text":"é"}]},"finishReason":"STOP"}]}',
      );
      final provider = GeminiModelProvider(
        apiKey: 'key',
        clientFactory: () => MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.fromIterable([
              for (final byte in raw) [byte],
            ]),
            200,
          ),
        ),
      );
      final events = await provider
          .stream(request(), CancellationToken())
          .toList();
      expect(events.whereType<ModelText>().single.text, 'é');
      expect(
        events.whereType<ModelFinished>().single.reason,
        ModelFinishReason.stop,
      );
    },
  );

  test(
    'retries initial 503 responses but never retries a partially consumed stream',
    () async {
      var attempts = 0;
      final provider = GeminiModelProvider(
        apiKey: 'key',
        retryDelay: (_) => Duration.zero,
        clientFactory: () => MockClient((_) async {
          attempts++;
          return attempts == 1
              ? http.Response('busy', 503)
              : http.Response(
                  sse(
                    packet([
                      {'text': 'Ready'},
                    ]),
                  ),
                  200,
                );
        }),
      );
      await provider.stream(request(), CancellationToken()).toList();
      expect(attempts, 2);
      attempts = 0;
      final broken = GeminiModelProvider(
        apiKey: 'key',
        clientFactory: () => MockClient.streaming((_, _) async {
          attempts++;
          return http.StreamedResponse(
            Stream<List<int>>.multi((controller) {
              controller.add(
                utf8.encode(
                  sse(
                    packet([
                      {'text': 'Partial'},
                    ], finish: null),
                  ),
                ),
              );
              controller.addError(
                http.ClientException('private provider details'),
              );
              controller.close();
            }),
            200,
          );
        }),
      );
      await expectLater(
        broken.stream(request(), CancellationToken()).toList(),
        throwsA(
          isA<GeminiFailure>().having(
            (e) => e.message,
            'safe',
            isNot(contains('private')),
          ),
        ),
      );
      expect(attempts, 1);
    },
  );

  test(
    'daily quota fallback changes request model and rebuilds generation config',
    () async {
      final models = <String>[];
      final configs = <Object?>[];
      final provider = GeminiModelProvider(
        apiKey: 'key',
        fallbackModel: (_) => 'gemini-fallback',
        generationConfig: (model) => {'testModel': model},
        clientFactory: () => MockClient((incoming) async {
          models.add(incoming.url.path);
          configs.add(
            jsonObject(jsonDecode(incoming.body))['generationConfig'],
          );
          return models.length == 1
              ? http.Response('GenerateRequestsPerDay', 429)
              : http.Response(
                  sse(
                    packet([
                      {'text': 'Ready'},
                    ]),
                  ),
                  200,
                );
        }),
      );
      await provider.stream(request(), CancellationToken()).toList();
      expect(models.last, contains('gemini-fallback'));
      expect(jsonObject(configs.last)['testModel'], 'gemini-fallback');
    },
  );

  test('cancellation stops an idle response promptly', () async {
    final output = StreamController<List<int>>();
    final connected = Completer<void>();
    final provider = GeminiModelProvider(
      apiKey: 'key',
      clientFactory: () => MockClient.streaming((_, _) async {
        connected.complete();
        return http.StreamedResponse(output.stream, 200);
      }),
    );
    final token = CancellationToken();
    final result = expectLater(
      provider.stream(request(), token).toList(),
      throwsA(
        isA<OrchestrationException>().having(
          (e) => e.code,
          'code',
          'cancelled',
        ),
      ),
    );
    await connected.future;
    token.cancel();
    await result.timeout(const Duration(seconds: 2));
    await output.close();
  });

  test(
    'blocked and length finishes remain explicit and truncated streams fail',
    () async {
      for (final finish in ['MAX_TOKENS', 'SAFETY']) {
        final provider = GeminiModelProvider(
          apiKey: 'key',
          clientFactory: () => MockClient(
            (_) async => http.Response(sse(packet([], finish: finish)), 200),
          ),
        );
        final events = await provider
            .stream(request(), CancellationToken())
            .toList();
        expect(
          (events.last as ModelFinished).reason,
          finish == 'SAFETY'
              ? ModelFinishReason.blocked
              : ModelFinishReason.length,
        );
      }
      final truncated = GeminiModelProvider(
        apiKey: 'key',
        clientFactory: () => MockClient(
          (_) async => http.Response(
            sse(
              packet([
                {'text': 'Partial'},
              ], finish: null),
            ),
            200,
          ),
        ),
      );
      await expectLater(
        truncated.stream(request(), CancellationToken()).toList(),
        throwsA(isA<GeminiFailure>()),
      );
    },
  );

  test(
    'authentication errors are safe, nonretryable and do not echo diagnostics',
    () async {
      var attempts = 0;
      final provider = GeminiModelProvider(
        apiKey: 'secret',
        clientFactory: () => MockClient((_) async {
          attempts++;
          return http.Response('private secret details', 403);
        }),
      );
      await expectLater(
        provider.stream(request(), CancellationToken()).toList(),
        throwsA(
          isA<GeminiFailure>()
              .having((e) => e.canRetry, 'retry', false)
              .having((e) => e.message, 'safe', isNot(contains('secret'))),
        ),
      );
      expect(attempts, 1);
    },
  );
}

class ReadTool implements AgentTool {
  final int Function() read;
  ReadTool(this.read);
  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'read',
    description: 'Read',
    arguments: ValueSchema.object(),
  );
  @override
  ToolOutcome execute(ToolContext context) => ToolSuccess({'value': read()});
}
