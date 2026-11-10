import 'dart:async';
import 'dart:convert';
import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/ai/observability/agent_tracing.dart';
import 'package:repforge/services/ai/observability/langfuse_config.dart';
import 'package:repforge/services/ai/observability/langfuse_service.dart';
import 'package:repforge/services/debug_log_buffer.dart';
import 'package:repforge/services/ai/gemini_ai_service.dart';

const config = LangfuseConfig(
  publicKey: 'pk-lf-test-public',
  secretKey: 'sk-lf-test-secret',
  enabled: true,
);
const fullConfig = LangfuseConfig(
  publicKey: 'pk-lf-test-public',
  secretKey: 'sk-lf-test-secret',
  enabled: true,
  captureContent: true,
);

class ReplyModel implements ModelProvider {
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    yield const ModelText('Answer');
    yield ModelFinished(
      ModelFinishReason.stop,
      providerData: {
        'gemini': {
          'model': 'gemini-2.5-flash',
          'modelVersion': 'gemini-2.5-flash-001',
        },
      },
      usage: {'totalTokenCount': 15},
    );
  }
}

class ErrorTool implements AgentTool {
  @override
  final definition = ToolDefinition(
    name: 'run_sql_query',
    description: 'Test SQL',
    arguments: ValueSchema.object(properties: {}),
  );
  @override
  Future<ToolOutcome> execute(ToolContext context) async =>
      ToolSuccess({'error': 'database is locked'});
}

Map<String, dynamic> span(http.Request request) =>
    (jsonDecode(request.body)['resourceSpans'][0]['scopeSpans'][0]['spans'][0]
            as Map)
        .cast<String, dynamic>();
Map<String, String> attributes(Map<String, dynamic> span) => {
  for (final a in span['attributes'] as List)
    a['key'] as String: a['value']['stringValue'] as String,
};
void main() {
  test(
    'generation usage prices cached input and reasoning without double counting',
    () async {
      final requests = <http.Request>[];
      final service = LangfuseService(
        write: (_) async {},
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.dispose);
      await service.save(config);
      service.record(
        traceId: 'a' * 32,
        sessionId: 'usage-test',
        name: 'reply',
        type: 'generation',
        started: DateTime.now(),
        metadata: {
          'usage': {
            'promptTokenCount': 100,
            'cachedContentTokenCount': 20,
            'candidatesTokenCount': 10,
            'thoughtsTokenCount': 5,
            'totalTokenCount': 115,
          },
        },
      );
      await service.flush();
      expect(
        jsonDecode(
          attributes(
            span(requests.single),
          )['langfuse.observation.usage_details']!,
        ),
        {
          'input': 80,
          'input_cached_tokens': 20,
          'output': 10,
          'output_reasoning_tokens': 5,
          'total': 115,
        },
      );
    },
  );
  test(
    'disabled tracing sends nothing and enabled export uses OTLP v4 with content off',
    () async {
      final requests = <http.Request>[];
      String? saved;
      final service = LangfuseService(
        read: () async => saved,
        write: (v) async => saved = v,
        clientFactory: () => MockClient((r) async {
          requests.add(r);
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.dispose);
      void record() => service.record(
        traceId: 'a' * 32,
        sessionId: 'chat',
        name: 'reply',
        type: 'generation',
        started: DateTime.now(),
        input: 'private workout',
        output: 'private reply',
      );
      record();
      await service.flush();
      expect(requests, isEmpty);
      await service.save(config);
      record();
      await service.flush();
      final request = requests.single;
      expect(
        request.url.toString(),
        'https://cloud.langfuse.com/api/public/otel/v1/traces',
      );
      expect(request.headers['x-langfuse-ingestion-version'], '4');
      expect(request.followRedirects, isFalse);
      expect(
        request.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('${config.publicKey}:${config.secretKey}'))}',
      );
      expect(request.body, isNot(contains('private workout')));
      expect(request.body, isNot(contains('private reply')));
      expect(
        attributes(span(request))['langfuse.observation.type'],
        'generation',
      );
      expect(span(request)['spanId'], hasLength(16));
      expect(
        int.parse(span(request)['endTimeUnixNano'] as String),
        greaterThanOrEqualTo(
          int.parse(span(request)['startTimeUnixNano'] as String),
        ),
      );
      await service.load();
      expect(service.config.enabled, isTrue);
    },
  );
  test(
    'content capture redacts keys and exporter failures do not change model replies',
    () async {
      final requests = <http.Request>[];
      final service = LangfuseService(
        write: (_) async {},
        clientFactory: () => MockClient((r) async {
          requests.add(r);
          return http.Response('private server error', 503);
        }),
      );
      addTearDown(service.dispose);
      await service.save(fullConfig);
      DebugLogBuffer.instance.protect('my-private-gemini-key');
      final traced = TracedModel(ReplyModel(), AgentTracing(service, 'chat'));
      final result = await traced
          .stream(
            ModelRequest(
              modelId: 'gemini-3.8-flash',
              systemPrompt: 'my-private-gemini-key',
              messages: [ModelMessage(role: 'user', text: 'Check my progress')],
              tools: [],
            ),
            CancellationToken(),
          )
          .toList();
      expect(result.whereType<ModelText>().single.text, 'Answer');
      await service.flush();
      expect(service.status, contains('chat is unaffected'));
      final request = requests.single;
      expect(request.body, isNot(contains('my-private-gemini-key')));
      expect(request.body, isNot(contains(config.secretKey)));
      final attrs = attributes(span(request));
      expect(attrs['langfuse.observation.model.name'], 'gemini-2.5-flash');
      expect(
        attrs['langfuse.observation.metadata'],
        contains('gemini-3.8-flash'),
      );
      expect(
        attrs['langfuse.observation.input'],
        contains('Check my progress'),
      );
      expect(attrs['langfuse.observation.output'], contains('Answer'));
    },
  );
  test(
    'disabling tracing cancels queued exports and preserves off status',
    () async {
      final gate = Completer<http.Response>();
      final started = Completer<void>();
      var count = 0;
      final service = LangfuseService(
        write: (_) async {},
        clientFactory: () => MockClient((r) {
          count++;
          if (!started.isCompleted) started.complete();
          return gate.future;
        }),
      );
      addTearDown(service.dispose);
      await service.save(config);
      for (var i = 0; i < 2; i++) {
        service.record(
          traceId: 'a' * 32,
          sessionId: 'chat',
          name: 'reply',
          type: 'span',
          started: DateTime.now(),
        );
      }
      await started.future;
      await service.save(const LangfuseConfig());
      gate.complete(http.Response('{}', 200));
      await service.flush();
      expect(count, 1);
      expect(service.status, 'Tracing is off');
    },
  );
  test(
    'tool errors share the generation trace and carry structured error status',
    () async {
      final requests = <http.Request>[];
      final service = LangfuseService(
        write: (_) async {},
        clientFactory: () => MockClient((r) async {
          requests.add(r);
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.dispose);
      await service.save(fullConfig);
      final trace = AgentTracing(service, 'chat');
      await TracedModel(ReplyModel(), trace)
          .stream(
            ModelRequest(
              modelId: 'requested',
              systemPrompt: 'Test',
              messages: [],
              tools: [],
            ),
            CancellationToken(),
          )
          .toList();
      final outcome = await trace
          .tools(ToolRegistry([ErrorTool()]))
          .require('run_sql_query')
          .execute(
            ToolContext(
              threadId: 'thread',
              runId: 'run',
              call: ToolCall(id: 'call', name: 'run_sql_query', arguments: {}),
              cancellation: CancellationToken(),
              deadline: DateTime.now().add(const Duration(minutes: 1)),
            ),
          );
      expect((outcome as ToolSuccess).data['error'], 'database is locked');
      await service.flush();
      expect(requests, hasLength(2));
      expect(span(requests.first)['traceId'], span(requests.last)['traceId']);
      final attrs = attributes(span(requests.last));
      expect(attrs['langfuse.observation.type'], 'tool');
      expect(attrs['langfuse.observation.level'], 'ERROR');
      expect(
        attrs['langfuse.observation.output'],
        contains('database is locked'),
      );
      trace.finish();
      await service.flush();
      expect(requests, hasLength(3));
      expect(
        span(requests.first)['parentSpanId'],
        span(requests.last)['spanId'],
      );
      expect(span(requests[1])['parentSpanId'], span(requests.last)['spanId']);
      expect(span(requests.last).containsKey('parentSpanId'), isFalse);
    },
  );

  test(
    'Gemini adapter traces the actual fallback model and transport attempts',
    () async {
      final exports = <http.Request>[];
      var attempts = 0;
      final ai =
          GeminiAiService(
            modelClientFactory: () => MockClient((_) async {
              if (attempts++ == 0) return http.Response('{}', 404);
              return http.Response(
                'data: ${jsonEncode({
                  'modelVersion': 'gemini-3.7-flash-001',
                  'candidates': [
                    {
                      'index': 0,
                      'content': {
                        'role': 'model',
                        'parts': [
                          {'text': 'ok'},
                        ],
                      },
                      'finishReason': 'STOP',
                    },
                  ],
                })}\n\n',
                200,
              );
            }),
          )..init(
            'fixture-key',
            model: 'gemini-3.8-flash',
            allowModelFallbacks: true,
          );
      addTearDown(ai.dispose);
      final service = LangfuseService(
        write: (_) async {},
        clientFactory: () => MockClient((r) async {
          exports.add(r);
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.dispose);
      await service.save(config);
      final result = await TracedModel(ai, AgentTracing(service, 'chat'))
          .stream(
            ModelRequest(
              modelId: 'gemini-3.8-flash',
              systemPrompt: 'Test',
              messages: [ModelMessage(role: 'user', text: 'Hello')],
              tools: [],
            ),
            CancellationToken(),
          )
          .toList();
      expect(result.whereType<ModelText>().single.text, 'ok');
      await service.flush();
      final attrs = attributes(span(exports.single));
      expect(attrs['langfuse.observation.model.name'], 'gemini-3.7-flash');
      final metadata =
          jsonDecode(attrs['langfuse.observation.metadata']!) as Map;
      expect(metadata['resolvedModel'], 'gemini-3.7-flash');
      expect(
        (metadata['transport'] as List).any(
          (e) => (e as Map)['event'] == 'fallback',
        ),
        isTrue,
      );
    },
  );

  test(
    'invalid hosts and placeholder keys are rejected before exporting',
    () async {
      for (final host in [
        'http://cloud.langfuse.com',
        'https://user:secret@example.com',
        'https://cloud.langfuse.com?key=secret',
        'https://cloud.langfuse.com/api/public',
      ]) {
        expect(
          () => LangfuseConfig(host: host).endpoint,
          throwsFormatException,
        );
      }
      expect(
        () => const LangfuseConfig(
          publicKey: 'pk-lf-...',
          secretKey: 'sk-lf-...',
        ).validate(),
        throwsFormatException,
      );
      final service = LangfuseService(
        write: (_) async {},
        clientFactory: () => MockClient(
          (_) async =>
              http.Response('{"partialSuccess":{"rejectedSpans":"1"}}', 200),
        ),
      );
      addTearDown(service.dispose);
      await expectLater(service.testConnection(config), throwsStateError);
    },
  );
}
