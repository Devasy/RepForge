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
  final bool Function(String model) googleSearchEnabled;
  final http.Client Function() clientFactory;
  final JsonMap Function(String model) generationConfig;
  final String? Function(String model)? fallbackModel;
  final void Function(String model)? onModelChanged;
  final FutureOr<void> Function(JsonMap usage)? onUsage;
  final void Function(JsonMap event)? onDiagnostic;
  final int maxRetries;
  final Duration timeout;
  final Duration modelTimeout;
  final Duration maxRequestTime;
  final Duration Function(int attempt) retryDelay;

  GeminiModelProvider({
    required this.apiKey,
    bool Function(String model)? googleSearchEnabled,
    http.Client Function()? clientFactory,
    JsonMap Function(String model)? generationConfig,
    this.fallbackModel,
    this.onModelChanged,
    this.onUsage,
    this.onDiagnostic,
    this.maxRetries = 1,
    this.timeout = const Duration(seconds: 15),
    this.modelTimeout = const Duration(minutes: 5),
    this.maxRequestTime = const Duration(minutes: 10),
    Duration Function(int attempt)? retryDelay,
  }) : googleSearchEnabled = googleSearchEnabled ?? ((_) => false),
       clientFactory = clientFactory ?? http.Client.new,
       generationConfig = generationConfig ?? ((_) => const {}),
       retryDelay =
           retryDelay ??
           ((attempt) => Duration(milliseconds: 500 * (1 << attempt))) {
    if (maxRetries < 0 ||
        maxRetries > 5 ||
        timeout <= Duration.zero ||
        modelTimeout <= Duration.zero ||
        maxRequestTime <= Duration.zero) {
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
    final grounding = <String, Object?>{};
    String? finish;
    var bytes = 0;
    await for (final event in _request(request, contents, cancellation)) {
      if (event is ModelStatus) {
        yield event;
        continue;
      }
      final chunk = event as JsonMap;
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
        if (data['groundingMetadata'] is Map) {
          grounding.addAll(jsonObject(data['groundingMetadata']));
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
          final serverTool = part['toolCall'] ?? part['toolResponse'];
          if (serverTool != null) {
            final tool = jsonObject(serverTool);
            final type = tool['toolType'];
            if (!{'GOOGLE_SEARCH', 'GOOGLE_SEARCH_WEB'}.contains(type)) {
              throw const GeminiFailure(
                'model_capability',
                'An unsupported built-in tool was returned.',
                canRetry: false,
              );
            }
            if (part['toolCall'] != null) {
              final queries = jsonObject(tool['args'])['queries'];
              if (queries is List) grounding['webSearchQueries'] = queries;
              yield const ModelStatus('Searching the web…');
            } else {
              final suggestions = jsonObject(
                tool['response'],
              )['search_suggestions'];
              if (suggestions is String) {
                grounding['searchEntryPoint'] = {
                  'renderedContent': suggestions,
                };
              }
            }
          }
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
              'toolCall',
              'toolResponse',
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
        'gemini': {
          'parts': parts,
          'callIds': ids,
          if (grounding.isNotEmpty) 'groundingMetadata': grounding,
        },
      },
    );
  }

  Future<JsonMap> generate({
    required String modelId,
    required JsonMap body,
    CancellationToken? cancellation,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const GeminiFailure(
        'model_auth',
        'Add your Gemini API key in Settings.',
        canRetry: false,
      );
    }
    final token = cancellation ?? CancellationToken();
    final request = ModelRequest(
      modelId: modelId,
      systemPrompt: '',
      messages: [],
      tools: [],
    );
    JsonMap? result;
    await for (final event in _request(request, const [], token, body: body)) {
      if (event is JsonMap) result = event;
    }
    if (result != null) return result;
    throw const GeminiFailure(
      'model_protocol',
      'Gemini returned an empty response.',
      canRetry: false,
    );
  }

  Stream<Object> _request(
    ModelRequest request,
    List<JsonMap> contents,
    CancellationToken cancellation, {
    JsonMap? body,
  }) async* {
    var model = request.modelId;
    final visited = <String>{model};
    final clock = Stopwatch()..start();
    var retries = 0;
    while (true) {
      cancellation.check();
      if (clock.elapsed >= maxRequestTime) throw _timeoutFailure;
      _diagnose({
        'event': 'request',
        'model': model,
        'attempt': retries + 1,
        'elapsedMs': clock.elapsedMilliseconds,
      });
      yield ModelStatus(
        retries == 0 ? 'Connecting to Gemini…' : 'Retrying Gemini…',
      );
      var received = false;
      Duration delay = Duration.zero;
      late GeminiFailure retryFailure;
      try {
        await for (final chunk in _attempt(
          request,
          contents,
          model,
          cancellation,
          clock,
          body: body,
        )) {
          received = true;
          yield chunk;
        }
        _diagnose({
          'event': 'response_complete',
          'model': model,
          'elapsedMs': clock.elapsedMilliseconds,
        });
        return;
      } on GeminiFailure catch (failure) {
        cancellation.check();
        _diagnose({
          'event': 'request_failed',
          'model': model,
          'code': failure.code,
          if (failure is _HttpFailure) 'status': failure.status,
          'partial': received,
          'elapsedMs': clock.elapsedMilliseconds,
        });
        if (received || clock.elapsed >= maxRequestTime) rethrow;
        final canSwitch =
            {
              'model_timeout',
              'model_busy',
              'model_quota',
              'model_unavailable',
              'model_transport',
              'model_network',
            }.contains(failure.code) &&
            (failure.canRetry || failure.code == 'model_unavailable');
        final immediate =
            failure.code == 'model_timeout' ||
            failure.code == 'model_unavailable' ||
            failure is _HttpFailure && failure.dailyQuota;
        if (canSwitch && (immediate || retries >= maxRetries)) {
          final fallback = fallbackModel?.call(model);
          final compatible =
              fallback != null &&
              (body != null ||
                  !googleSearchEnabled(request.modelId) ||
                  googleSearchEnabled(fallback));
          if (compatible && visited.length < 8 && visited.add(fallback)) {
            _diagnose({
              'event': 'fallback',
              'from': model,
              'to': fallback,
              'code': failure.code,
            });
            yield const ModelStatus(
              'Gemini is unavailable. Trying another model…',
            );
            model = fallback;
            retries = 0;
            onModelChanged?.call(model);
            continue;
          }
        }
        if (!failure.canRetry || retries >= maxRetries) rethrow;
        retryFailure = failure;
        delay = failure is _HttpFailure && failure.retryAfter != null
            ? failure.retryAfter!
            : retryDelay(retries);
        retries++;
      }
      if (delay >= maxRequestTime - clock.elapsed) {
        throw retryFailure;
      }
      _diagnose({
        'event': 'retry',
        'model': model,
        'delayMs': delay.inMilliseconds,
      });
      yield const ModelStatus('Gemini is busy. Waiting before retrying…');
      await _backoff(delay, cancellation);
    }
  }

  Stream<JsonMap> _attempt(
    ModelRequest request,
    List<JsonMap> contents,
    String model,
    CancellationToken cancellation,
    Stopwatch clock, {
    JsonMap? body,
  }) async* {
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
    final attemptClock = Stopwatch()..start();
    var hasPacket = false;
    JsonMap decodePacket(String payload) {
      final result = _packet(payload);
      hasPacket = true;
      return result;
    }

    Future<T> guard<T>(Future<T> future) {
      final remaining = maxRequestTime - clock.elapsed;
      final attemptRemaining = modelTimeout - attemptClock.elapsed;
      final wait = body == null && hasPacket && timeout < attemptRemaining
          ? timeout
          : attemptRemaining;
      return _guard(
        future,
        cancellation,
        budget: wait < remaining ? wait : remaining,
      );
    }

    try {
      final outgoing =
          http.Request(
              'POST',
              Uri.https(
                'generativelanguage.googleapis.com',
                '/v1beta/models/$model:${body == null ? 'streamGenerateContent' : 'generateContent'}',
                body == null ? {'alt': 'sse'} : null,
              ),
            )
            ..headers.addAll({
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            })
            ..body = jsonEncode(
              body != null
                  ? {
                      ...body,
                      'generationConfig': {
                        ...jsonObject(
                          body['generationConfig'] ?? const <String, Object?>{},
                        ),
                        ...generationConfig(model),
                      },
                    }
                  : {
                      'contents': contents,
                      'systemInstruction': {
                        'parts': [
                          {'text': request.systemPrompt},
                        ],
                      },
                      if (request.tools.isNotEmpty ||
                          googleSearchEnabled(model))
                        'tools': [
                          if (googleSearchEnabled(model))
                            {'googleSearch': <String, Object?>{}},
                          if (request.tools.isNotEmpty)
                            {
                              'functionDeclarations': [
                                for (final tool in request.tools)
                                  {
                                    'name': tool.name,
                                    'description': tool.description,
                                    'parameters': geminiSchema(
                                      tool.arguments.definition,
                                    ),
                                  },
                              ],
                            },
                        ],
                      if (googleSearchEnabled(model))
                        'toolConfig': {
                          'includeServerSideToolInvocations': true,
                          'functionCallingConfig': {'mode': 'VALIDATED'},
                        },
                      'generationConfig': {
                        ...generationConfig(model),
                        'candidateCount': 1,
                      },
                    },
            );
      final response = await guard(client.send(outgoing));
      if (response.statusCode != 200) {
        final body = await guard(response.stream.bytesToString());
        final failure = _statusFailure(response.statusCode);
        throw _HttpFailure(
          failure.code,
          failure.message,
          canRetry: failure.canRetry,
          status: response.statusCode,
          dailyQuota:
              response.statusCode == 429 &&
              (body.toLowerCase().contains('requestsperday') ||
                  body.toLowerCase().contains('requests_per_day')),
          retryAfter: _serverDelay(body),
        );
      }
      if (body != null) {
        final payload = await guard(response.stream.bytesToString());
        if (utf8.encode(payload).length > 16 * 1024 * 1024) {
          throw const FormatException('Response too large');
        }
        yield decodePacket(payload);
        return;
      }
      final lines = StreamIterator(
        response.stream.transform(utf8.decoder).transform(const LineSplitter()),
      );
      var event = StringBuffer();
      try {
        while (await guard(lines.moveNext())) {
          final line = lines.current;
          if (line.isEmpty && event.isNotEmpty) {
            final payload = event.toString();
            event = StringBuffer();
            if (payload.trim() != '[DONE]') yield decodePacket(payload);
          } else if (line.startsWith('data:')) {
            if (event.isNotEmpty) event.writeln();
            event.write(line.substring(5).trimLeft());
            if (event.length > 1024 * 1024) {
              throw const FormatException('SSE event too large');
            }
          }
        }
        if (event.isNotEmpty && event.toString().trim() != '[DONE]') {
          yield decodePacket(event.toString());
        }
      } finally {
        close();
        unawaited(lines.cancel());
      }
    } on OrchestrationException {
      rethrow;
    } on TimeoutException {
      throw _timeoutFailure;
    } on FormatException {
      throw const GeminiFailure(
        'model_protocol',
        'Gemini returned an incomplete response. Please try again.',
        canRetry: false,
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
  }

  JsonMap _packet(String payload) {
    final packet = jsonObject(jsonDecode(payload));
    if (packet['error'] case final Map<String, Object?> error) {
      throw _statusFailure((error['code'] as num?)?.toInt() ?? 500);
    }
    return packet;
  }

  void _diagnose(JsonMap event) {
    try {
      onDiagnostic?.call(event);
    } catch (_) {}
  }

  GeminiFailure get _timeoutFailure => const GeminiFailure(
    'model_timeout',
    'Gemini took too long to respond. Please try again.',
  );

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

  Future<T> _guard<T>(
    Future<T> future,
    CancellationToken cancellation, {
    required Duration budget,
  }) => Future.any([
    future,
    cancellation.whenCancelled.then<T>((_) {
      cancellation.check();
      throw StateError('Cancelled');
    }),
  ]).timeout(budget);

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

class _HttpFailure extends GeminiFailure {
  final bool dailyQuota;
  final int status;
  final Duration? retryAfter;
  const _HttpFailure(
    super.code,
    super.message, {
    required super.canRetry,
    required this.dailyQuota,
    required this.status,
    this.retryAfter,
  });
}
