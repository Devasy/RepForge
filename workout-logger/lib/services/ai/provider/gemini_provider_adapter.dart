// gemini_provider_adapter.dart — Translates Gemini API output into ModelStep.
//
// This adapter implements ModelRuntime by calling the Gemini REST API
// (streamGenerateContent) and translating the SSE chunks into our
// SDK-agnostic ModelStep/ModelMessage types.
//
// It does NOT execute tools or loop. It does NOT own the conversation
// history. It just translates a single model pass to/from the wire format.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart' show Tool;
import 'package:http/http.dart' as http;

import '../retry_policy.dart';
import '../tools/tool_spec.dart';
import 'model_message.dart';
import 'model_runtime.dart';
import 'model_step.dart';
import 'provider_metadata.dart';

const String _apiBase =
    'https://generativelanguage.googleapis.com/v1beta/models';

/// Gemini-specific implementation of [ModelRuntime].
///
/// Reuses the raw HTTP streaming approach from GeminiAiService, but
/// yields [ModelStep]s instead of raw strings. Does NOT execute tools.
class GeminiProviderAdapter implements ModelRuntime {
  final String Function() _apiKeyGetter;
  final String Function() _modelGetter;

  /// Retry policy for transient HTTP errors (429 / 5xx).
  final RetryPolicy retryPolicy;

  /// Optional callback for retry status events (countdown UI).
  void Function(RetryStatus status)? onRetryStatus;

  /// Optional callback for token usage tracking.
  void Function({required int prompt, required int response, required int total})?
      onUsage;

  /// Optional HTTP client for testing.
  final http.Client? _httpClient;

  GeminiProviderAdapter({
    required String Function() apiKeyGetter,
    required String Function() modelGetter,
    RetryPolicy? retryPolicy,
    this.onRetryStatus,
    this.onUsage,
    http.Client? httpClient,
  })  : _apiKeyGetter = apiKeyGetter,
        _modelGetter = modelGetter,
        _httpClient = httpClient,
        retryPolicy = retryPolicy ?? const RetryPolicy();

  @override
  bool get isConfigured => _apiKeyGetter().isNotEmpty;

  @override
  String get currentModel => _modelGetter();

  @override
  ProviderMetadata get metadata => ProviderMetadata(
        providerId: 'gemini',
        modelId: currentModel,
        supportsToolCalling: true,
        supportsStreaming: true,
      );

  @override
  Stream<ModelStep> streamStep({
    required String systemPrompt,
    required List<ModelMessage> messages,
    required List<ToolSpec> tools,
  }) async* {
    if (!isConfigured) {
      yield const ModelTextDelta(
        'Please add your Gemini API key in Profile → AI Features to get started.',
      );
      yield const ModelFinish('stop');
      return;
    }

    final contents = _messagesToContents(messages);
    final geminiTools = tools.isNotEmpty ? _specsToGeminiTools(tools) : null;

    final body = _makeBody(
      contents: contents,
      system: systemPrompt,
      tools: geminiTools,
    );

    var hasToolCalls = false;

    try {
      await for (final chunk in _streamSse(body)) {
        final candidates = chunk['candidates'] as List<dynamic>? ?? [];
        for (final raw in candidates) {
          final c = raw as Map<String, dynamic>;
          final content = c['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>? ?? [];

          for (final part in parts) {
            if (part is! Map<String, dynamic>) continue;

            yield ModelRawPart(part);

            // Text part (skip thought parts).
            if (part.containsKey('text') && part['thought'] != true) {
              final t = part['text'] as String? ?? '';
              if (t.isNotEmpty) yield ModelTextDelta(t);
            }

            // Function call part.
            if (part.containsKey('functionCall')) {
              final fc = part['functionCall'] as Map<String, dynamic>;
              final name = fc['name'] as String;
              final args = (fc['args'] as Map<String, dynamic>? ?? {})
                  .cast<String, Object?>();

              yield ModelToolCall(
                callId: '${name}_${DateTime.now().millisecondsSinceEpoch}',
                toolName: name,
                args: args,
              );
              hasToolCalls = true;
            }
          }
        }

        // Track token usage from the last chunk.
        final usage = chunk['usageMetadata'] as Map<String, dynamic>?;
        if (usage != null) {
          final p = (usage['promptTokenCount'] as num?)?.toInt() ?? 0;
          final r = (usage['candidatesTokenCount'] as num?)?.toInt() ?? 0;
          final t = (usage['totalTokenCount'] as num?)?.toInt() ?? (p + r);
          onUsage?.call(prompt: p, response: r, total: t);
        }
      }
    } catch (e) {
      yield ModelTextDelta('Error: $e');
    }

    yield ModelFinish(hasToolCalls ? 'tool_calls' : 'stop');
  }

  // ── Wire format helpers ─────────────────────────────────────────────────

  /// Convert our ModelMessage list to Gemini's content format.
  List<dynamic> _messagesToContents(List<ModelMessage> messages) {
    final contents = <dynamic>[];
    for (final msg in messages) {
      switch (msg) {
        case UserMessage(:final text):
          contents.add({
            'role': 'user',
            'parts': [
              {'text': text}
            ],
          });

        case AssistantMessage(:final text, :final toolCalls, :final rawParts):
          if (rawParts != null && rawParts.isNotEmpty) {
            // Preserve raw parts for thought_signature round-tripping.
            contents.add({'role': 'model', 'parts': rawParts});
          } else {
            final parts = <Map<String, dynamic>>[];
            if (text.isNotEmpty) parts.add({'text': text});
            for (final tc in toolCalls) {
              parts.add({
                'functionCall': {
                  'name': tc.toolName,
                  'args': tc.args,
                },
              });
            }
            if (parts.isNotEmpty) {
              contents.add({'role': 'model', 'parts': parts});
            }
          }

        case ToolResultMessage(:final results):
          final responseParts = <Map<String, dynamic>>[];
          for (final r in results) {
            responseParts.add({
              'functionResponse': {'name': r.toolName, 'response': r.data},
            });
          }
          contents.add({'role': 'function', 'parts': responseParts});
      }
    }
    return contents;
  }

  /// Convert our ToolSpec list to Gemini's Tool JSON format.
  List<Map<String, dynamic>> _specsToGeminiTools(List<ToolSpec> specs) {
    return [
      {
        'functionDeclarations': [
          for (final spec in specs)
            {
              'name': spec.name,
              'description': spec.description,
              if (spec.parameters.isNotEmpty)
                'parameters': _paramToSchema(ToolParam.object(
                  properties: spec.parameters,
                  requiredProperties:
                      spec.required.isNotEmpty ? spec.required : null,
                )),
            },
        ],
      },
    ];
  }

  /// Convert a ToolParam to Gemini's Schema JSON.
  Map<String, dynamic> _paramToSchema(ToolParam param) {
    final schema = <String, dynamic>{
      'type': param.type.toUpperCase(),
    };
    if (param.description != null) schema['description'] = param.description;
    if (param.nullable) schema['nullable'] = true;
    if (param.items != null) schema['items'] = _paramToSchema(param.items!);
    if (param.properties != null) {
      schema['properties'] = {
        for (final e in param.properties!.entries)
          e.key: _paramToSchema(e.value),
      };
    }
    if (param.requiredProperties != null &&
        param.requiredProperties!.isNotEmpty) {
      schema['required'] = param.requiredProperties;
    }
    return schema;
  }

  Map<String, dynamic> _makeBody({
    required List<dynamic> contents,
    String? system,
    List<Map<String, dynamic>>? tools,
    bool jsonMode = false,
    String thinkingLevel = 'medium',
  }) =>
      {
        'contents': contents,
        if (system != null)
          'systemInstruction': {
            'parts': [
              {'text': system}
            ]
          },
        if (tools != null) 'tools': tools,
        'generationConfig': {
          'thinkingConfig': {'thinkingLevel': thinkingLevel},
          if (jsonMode) 'responseMimeType': 'application/json',
        },
      };

  Stream<Map<String, dynamic>> _streamSse(Map<String, dynamic> body) async* {
    final apiKey = _apiKeyGetter();
    final model = _modelGetter();
    final uri = Uri.parse(
      '$_apiBase/$model:streamGenerateContent?alt=sse&key=$apiKey',
    );
    final encodedBody = jsonEncode(body);

    final streamed = await retryPolicy.execute(
      makeRequest: () {
        final client = _httpClient ?? http.Client();
        final request = http.Request('POST', uri)
          ..headers['Content-Type'] = 'application/json'
          ..body = encodedBody;
        return client.send(request);
      },
      onStatus: onRetryStatus,
    );

    try {
      final lineBuf = StringBuffer();
      await for (final raw in streamed.stream.transform(utf8.decoder)) {
        lineBuf.write(raw);
        final text = lineBuf.toString();
        final lines = text.split('\n');
        lineBuf
          ..clear()
          ..write(lines.last);
        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (!line.startsWith('data: ')) continue;
          final payload = line.substring(6).trim();
          if (payload.isEmpty || payload == '[DONE]') continue;
          yield jsonDecode(payload) as Map<String, dynamic>;
        }
      }
      final tail = lineBuf.toString().trim();
      if (tail.startsWith('data: ')) {
        final payload = tail.substring(6).trim();
        if (payload.isNotEmpty && payload != '[DONE]') {
          yield jsonDecode(payload) as Map<String, dynamic>;
        }
      }
    } catch (_) {
      rethrow;
    }
  }
}
