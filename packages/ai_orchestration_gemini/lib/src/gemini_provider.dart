import 'dart:async';
import 'dart:convert';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:http/http.dart' as http;

import 'gemini_wire.dart';

class GeminiFailure extends OrchestrationException {
  final bool canRetry;
  const GeminiFailure(super.code, super.message, {this.canRetry = true});
}

class GeminiModelProvider implements ModelProvider {
  final String apiKey;
  final http.Client Function() clientFactory;
  final JsonMap Function(String model) generationConfig;
  final String? Function(String model)? fallbackModel;
  final void Function(String model)? onModelChanged;
  final FutureOr<void> Function(JsonMap usage)? onUsage;
  final int maxRetries;
  final Duration timeout;
  final Duration Function(int attempt) retryDelay;

  GeminiModelProvider({
    required this.apiKey,
    http.Client Function()? clientFactory,
    JsonMap Function(String model)? generationConfig,
    this.fallbackModel,
    this.onModelChanged,
    this.onUsage,
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 60),
    Duration Function(int attempt)? retryDelay,
  }) : clientFactory = clientFactory ?? http.Client.new,
       generationConfig = generationConfig ?? ((_) => const {}),
       retryDelay =
           retryDelay ??
           ((attempt) => Duration(milliseconds: 500 * (1 << attempt))) {
    if (maxRetries < 0 || maxRetries > 5 || timeout <= Duration.zero) {
      throw ArgumentError('Invalid request limits.');
    }
  }

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (apiKey.trim().isEmpty) {
      throw const GeminiFailure(
        'model_auth',
        'Add your Gemini API key in Settings.',
        canRetry: false,
      );
    }
    final contents = geminiContents(request.messages);
    final parts = <JsonMap>[];
    final ids = <String, Object?>{};
    var usage = <String, Object?>{};
    String? finish;
    var bytes = 0;
    await for (final chunk in _request(request, contents, cancellation)) {
      bytes += utf8.encode(jsonEncode(chunk)).length;
      if (bytes > 16 * 1024 * 1024) {
        throw const GeminiFailure(
          'model_protocol',
          'Gemini response exceeded the size limit.',
          canRetry: false,
        );
      }
      if (chunk['error'] != null) {
        throw const GeminiFailure(
          'model_transport',
          'Gemini could not finish this reply. Please try again.',
        );
      }
      if (chunk['usageMetadata'] != null) {
        usage = jsonObject(chunk['usageMetadata']);
      }
      final candidates = chunk['candidates'] as List<Object?>? ?? const [];
      if (candidates.length > 1) {
        throw const GeminiFailure(
          'model_protocol',
          'Multiple candidates are unsupported.',
          canRetry: false,
        );
      }
      if (jsonObject(
            chunk['promptFeedback'] ?? const <String, Object?>{},
          )['blockReason'] !=
          null) {
        finish = 'SAFETY';
      }
      for (final candidate in candidates) {
        final data = jsonObject(candidate);
        if (data['index'] != null && data['index'] != 0) {
          throw const GeminiFailure(
            'model_protocol',
            'Unexpected candidate index.',
            canRetry: false,
          );
        }
        final content = jsonObject(
          data['content'] ?? const <String, Object?>{},
        );
        final raw = content['parts'] as List<Object?>? ?? const [];
        if (finish != null && raw.isNotEmpty) {
          throw const GeminiFailure(
            'model_protocol',
            'Content arrived after Gemini finished.',
            canRetry: false,
          );
        }
        for (final item in raw) {
          final part = jsonObject(item);
          parts.add(part);
          if (part['thought'] == true) continue;
          if (part['text'] case final String text) {
            if (text.isNotEmpty) yield ModelText(text);
          }
          if (part['functionCall'] != null) {
            final call = jsonObject(part['functionCall']);
            final nativeId = call['id'] as String?;
            final id = nativeId == null || nativeId.isEmpty
                ? newIdentifier()
                : nativeId;
            if (ids.containsKey(id)) {
              throw const GeminiFailure(
                'model_protocol',
                'Duplicate Gemini call ID.',
                canRetry: false,
              );
            }
            ids[id] = nativeId;
            yield ModelToolCall(
              ToolCall(
                id: id,
                name: call['name']! as String,
                arguments: jsonObject(
                  call['args'] ?? const <String, Object?>{},
                ),
              ),
            );
          }
          if (part.keys.any(
            (key) => !{
              'text',
              'thought',
              'thoughtSignature',
              'functionCall',
              'partMetadata',
            }.contains(key),
          )) {
            throw const GeminiFailure(
              'model_capability',
              'This Gemini response modality is unsupported.',
              canRetry: false,
            );
          }
        }
        finish = data['finishReason'] as String? ?? finish;
      }
    }
    if (finish == null) {
      throw const GeminiFailure(
        'model_protocol',
        'Gemini ended before completing its response.',
      );
    }
    if (usage.isNotEmpty) await onUsage?.call(usage);
    final reason = switch (finish) {
      'STOP' =>
        ids.isEmpty ? ModelFinishReason.stop : ModelFinishReason.toolCalls,
      'MAX_TOKENS' => ModelFinishReason.length,
      'SAFETY' ||
      'RECITATION' ||
      'BLOCKLIST' ||
      'PROHIBITED_CONTENT' ||
      'SPII' ||
      'IMAGE_SAFETY' => ModelFinishReason.blocked,
      _ => throw const GeminiFailure(
        'model_protocol',
        'Gemini could not complete this response.',
      ),
    };
    yield ModelFinished(
      reason,
      usage: usage,
      providerData: {
        'gemini': {'parts': parts, 'callIds': ids},
      },
    );
  }

  Stream<JsonMap> _request(
    ModelRequest request,
    List<JsonMap> contents,
    CancellationToken cancellation,
  ) async* {
    var model = request.modelId;
    final visited = <String>{model};
    var retries = 0;
    while (true) {
      cancellation.check();
      if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model)) {
        throw const GeminiFailure(
          'model_capability',
          'Invalid Gemini model ID.',
          canRetry: false,
        );
      }
      final client = clientFactory();
      var open = true;
      void close() {
        if (open) {
          open = false;
          client.close();
        }
      }

      unawaited(cancellation.whenCancelled.then((_) => close()));
      Duration? delay;
      try {
        final uri = Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/$model:streamGenerateContent',
          {'alt': 'sse'},
        );
        final body = {
          'contents': contents,
          'systemInstruction': {
            'parts': [
              {'text': request.systemPrompt},
            ],
          },
          if (request.tools.isNotEmpty)
            'tools': [
              {
                'functionDeclarations': [
                  for (final tool in request.tools)
                    {
                      'name': tool.name,
                      'description': tool.description,
                      'parameters': geminiSchema(tool.arguments.definition),
                    },
                ],
              },
            ],
          'generationConfig': {...generationConfig(model), 'candidateCount': 1},
        };
        final outgoing = http.Request('POST', uri)
          ..headers.addAll({
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          })
          ..body = jsonEncode(body);
        final response = await _guard(client.send(outgoing), cancellation);
        if (response.statusCode != 200) {
          final error = await _guard(
            response.stream.bytesToString(),
            cancellation,
          );
          final fallback = fallbackModel?.call(model);
          if (response.statusCode == 429 &&
              (error.contains('GenerateRequestsPerDay') ||
                  error.contains('free_tier_requests')) &&
              fallback != null &&
              visited.length < 6 &&
              visited.add(fallback)) {
            model = fallback;
            onModelChanged?.call(model);
            continue;
          }
          if ((response.statusCode == 429 || response.statusCode >= 500) &&
              retries < maxRetries) {
            delay = _serverDelay(error) ?? retryDelay(retries);
            retries++;
          } else {
            throw _statusFailure(response.statusCode);
          }
        } else {
          final lines = StreamIterator(
            response.stream
                .transform(utf8.decoder)
                .transform(const LineSplitter()),
          );
          var event = StringBuffer();
          try {
            while (await _guard(lines.moveNext(), cancellation)) {
              final line = lines.current;
              if (line.isEmpty) {
                if (event.isNotEmpty) {
                  final payload = event.toString();
                  event = StringBuffer();
                  if (payload.trim() != '[DONE]') {
                    yield jsonObject(jsonDecode(payload));
                  }
                }
              } else if (line.startsWith('data:')) {
                if (event.isNotEmpty) event.writeln();
                event.write(line.substring(5).trimLeft());
                if (event.length > 1024 * 1024) {
                  throw const FormatException('SSE event too large');
                }
              }
            }
            if (event.isNotEmpty && event.toString().trim() != '[DONE]') {
              yield jsonObject(jsonDecode(event.toString()));
            }
          } finally {
            close();
            unawaited(lines.cancel());
          }
          return;
        }
      } on OrchestrationException {
        rethrow;
      } on TimeoutException {
        throw const GeminiFailure(
          'model_timeout',
          'Gemini took too long to respond. Please try again.',
        );
      } on FormatException {
        throw const GeminiFailure(
          'model_protocol',
          'Gemini returned an incomplete response. Please try again.',
        );
      } catch (_) {
        cancellation.check();
        throw const GeminiFailure(
          'model_network',
          'The connection to Gemini was lost. Check your internet connection and try again.',
        );
      } finally {
        close();
      }
      await _backoff(delay, cancellation);
    }
  }

  Future<void> _backoff(Duration delay, CancellationToken cancellation) async {
    final elapsed = Completer<void>();
    final timer = Timer(delay, elapsed.complete);
    try {
      await Future.any([elapsed.future, cancellation.whenCancelled]);
      cancellation.check();
    } finally {
      timer.cancel();
    }
  }

  Future<T> _guard<T>(Future<T> future, CancellationToken cancellation) =>
      Future.any([
        future,
        cancellation.whenCancelled.then<T>((_) {
          cancellation.check();
          throw StateError('Cancelled');
        }),
      ]).timeout(timeout);

  Duration? _serverDelay(String body) {
    final match = RegExp(
      r'(?:retryDelay"\s*:\s*"|retry in\s+)([\d.]+)s',
    ).firstMatch(body);
    final seconds = double.tryParse(match?.group(1) ?? '');
    return seconds == null || !seconds.isFinite
        ? null
        : Duration(
            milliseconds: (seconds * 1000 + 350).ceil().clamp(500, 45000),
          );
  }

  GeminiFailure _statusFailure(int status) => switch (status) {
    401 || 403 => const GeminiFailure(
      'model_auth',
      'Gemini cannot access your account. Check your API key and model access in Settings.',
      canRetry: false,
    ),
    404 => const GeminiFailure(
      'model_unavailable',
      'This Gemini model is no longer available. Choose another model in Settings.',
      canRetry: false,
    ),
    429 => const GeminiFailure(
      'model_quota',
      'Your Gemini usage limit has been reached. Wait a while before trying again, or check your Google AI plan.',
    ),
    503 => const GeminiFailure(
      'model_busy',
      'Gemini is busy right now. Please try again in a moment.',
    ),
    _ => GeminiFailure(
      'model_transport',
      'Gemini could not finish this reply. Please try again.',
      canRetry: status >= 500,
    ),
  };
}
