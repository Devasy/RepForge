// gemini_ai_service.dart — google_generative_ai implementation of IAiService.
//
// Backs the AI coach chat (streaming + tool calling), program generation, and
// insights. Uses a user-supplied Google AI Studio API key (free-tier friendly).
// Implements [IAiService] so the backend can be swapped without touching consumers.
//
// Uses direct HTTP calls (rather than the SDK's chat helpers) so we can pass
// thinkingConfig: {thinkingBudget: 0} and avoid the SDK crashing on the
// `thoughtSignature` parts that Gemini 3.x models return when thinking is active.
// The SDK is still used for its type definitions (Content, Tool, FunctionCall)
// and their toJson() serialisers which are part of the public API.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    show Content, FunctionCall, Tool;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../interfaces/ai_service_interface.dart';
import '../interfaces/storage_service_interface.dart';

// Ordered list of available Gemini models shown in the picker.
const kGeminiModels = [
  ('gemini-2.5-flash',      'Gemini 2.5 Flash'),
  ('gemini-3.1-flash-lite', 'Gemini 3.1 Flash Lite'),
  ('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite'),
  ('gemini-3.5-flash',      'Gemini 3.5 Flash'),
  ('gemini-3.6-flash',      'Gemini 3.6 Flash'),
];

// Default to the latest GA model.
const kDefaultGeminiModel = 'gemini-3.6-flash';

// Upper bound on tool-resolution rounds per user turn, to bound runaway loops.
const int _kMaxToolRounds = 5;

// Retry policy for transient (5xx / 429) errors. Total attempts = 1 + retries.
const int _kMaxRetries = 3;

const String _apiBase =
    'https://generativelanguage.googleapis.com/v1beta/models';

// 429 (rate limit) and 5xx (server/overload, e.g. 503 "high demand") are
// transient and worth retrying; 4xx (bad key, bad request) are not.
bool _isRetryableStatus(int code) => code == 429 || (code >= 500 && code < 600);

// Exponential backoff: 500ms, 1s, 2s …
Duration _retryBackoff(int attempt) =>
    Duration(milliseconds: 500 * (1 << attempt));

/// Extracts exact retryDelay provided by Google in 429/503 payloads.
/// Checks error.details (google.rpc.RetryInfo) or error.message ("Please retry in Xs").
Duration? _extractRetryDelay(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is Map) {
      final errMap = decoded['error'] as Map;
      // 1. Check error.details for google.rpc.RetryInfo
      final details = errMap['details'];
      if (details is List) {
        for (final item in details) {
          if (item is Map && item['retryDelay'] is String) {
            final delayStr = (item['retryDelay'] as String).replaceAll('s', '').trim();
            final seconds = double.tryParse(delayStr);
            if (seconds != null && seconds > 0) {
              final ms = (seconds * 1000).ceil() + 350;
              return Duration(milliseconds: ms.clamp(500, 45000));
            }
          }
        }
      }
      // 2. Regex match in error.message (e.g. "Please retry in 23.690750876s.")
      final message = errMap['message'];
      if (message is String) {
        final match = RegExp(r'retry in\s+([\d.]+)\s*s', caseSensitive: false).firstMatch(message);
        if (match != null) {
          final seconds = double.tryParse(match.group(1)!);
          if (seconds != null && seconds > 0) {
            final ms = (seconds * 1000).ceil() + 350;
            return Duration(milliseconds: ms.clamp(500, 45000));
          }
        }
      }
    }
  } catch (_) {}
  return null;
}

bool _isDailyQuotaExhausted(String body) {
  return body.contains('GenerateRequestsPerDay') ||
      body.contains('free_tier_requests') ||
      body.contains('QuotaExceeded') ||
      body.contains('RESOURCE_EXHAUSTED');
}

String? _getFallbackModel(String currentModel) {
  switch (currentModel) {
    case 'gemini-3.6-flash':
      return 'gemini-3.5-flash';
    case 'gemini-3.5-flash':
      return 'gemini-3.5-flash-lite';
    case 'gemini-3.5-flash-lite':
      return 'gemini-2.5-flash';
    default:
      return null;
  }
}

// Gemini error bodies look like {"error":{"code":503,"message":"…","status":"…"}}.
// Surface just the human-readable message rather than the whole JSON blob.
String _errorMessage(int code, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is Map) {
      final msg = (decoded['error'] as Map)['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
  } catch (_) {
    // Body wasn't JSON — fall through to a generic message.
  }
  return 'request failed (HTTP $code).';
}

class GeminiAiService extends ChangeNotifier implements IAiService {
  // Optional storage so cumulative token usage survives restarts.
  final IStorageService? _storage;

  GeminiAiService({IStorageService? storage}) : _storage = storage;

  static const String _usageKey = 'aiTokenUsage';

  String _apiKey = '';
  String _model = kDefaultGeminiModel;

  // Cumulative token usage across all AI calls (persisted).
  int _promptTokens = 0;
  int _responseTokens = 0;
  int _totalTokens = 0;
  int _requestCount = 0;

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  String get currentModel => _model;

  /// Cumulative input (prompt) tokens billed across all AI calls.
  int get promptTokensUsed => _promptTokens;

  /// Cumulative output (response) tokens across all AI calls.
  int get responseTokensUsed => _responseTokens;

  /// Cumulative total tokens (prompt + response) across all AI calls.
  int get totalTokensUsed => _totalTokens;

  /// Number of AI requests recorded.
  int get aiRequestCount => _requestCount;

  void init(String apiKey, {String model = kDefaultGeminiModel}) {
    _apiKey = apiKey.trim();
    _model = model;
  }

  /// Load persisted cumulative token usage (call once at startup).
  Future<void> loadUsage() async {
    final raw = await _storage?.getSetting(_usageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _promptTokens = (m['prompt'] as num?)?.toInt() ?? 0;
      _responseTokens = (m['response'] as num?)?.toInt() ?? 0;
      _totalTokens = (m['total'] as num?)?.toInt() ?? 0;
      _requestCount = (m['requests'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {
      // Ignore corrupt usage data.
    }
  }

  /// Reset cumulative token usage to zero.
  Future<void> resetUsage() async {
    _promptTokens = 0;
    _responseTokens = 0;
    _totalTokens = 0;
    _requestCount = 0;
    await _persistUsage();
    notifyListeners();
  }

  /// Accumulate one request's token counts. Exposed for testing; normally
  /// fed from the raw usageMetadata JSON via [_recordRawUsage].
  @visibleForTesting
  Future<void> recordUsage({
    required int prompt,
    required int response,
    required int total,
  }) async {
    _promptTokens += prompt;
    _responseTokens += response;
    _totalTokens += total;
    _requestCount += 1;
    await _persistUsage();
    notifyListeners();
  }

  void _recordRawUsage(Map<String, dynamic>? usage) {
    if (usage == null) return;
    final p = (usage['promptTokenCount'] as num?)?.toInt() ?? 0;
    final r = (usage['candidatesTokenCount'] as num?)?.toInt() ?? 0;
    final t = (usage['totalTokenCount'] as num?)?.toInt() ?? (p + r);
    recordUsage(prompt: p, response: r, total: t);
  }

  Future<void> _persistUsage() async {
    final storage = _storage;
    if (storage == null) return;
    await storage.saveSetting(
      _usageKey,
      jsonEncode({
        'prompt': _promptTokens,
        'response': _responseTokens,
        'total': _totalTokens,
        'requests': _requestCount,
      }),
    );
  }

  void updateApiKey(String key) {
    _apiKey = key.trim();
    notifyListeners();
  }

  void updateModel(String model) {
    _model = model;
    notifyListeners();
  }

  // ── Raw HTTP helpers ────────────────────────────────────────────────────────

  Map<String, dynamic> _makeBody({
    required List<dynamic> contents,
    String? system,
    List<Tool>? tools,
    bool jsonMode = false,
  }) =>
      {
        'contents': contents,
        if (system != null)
          'systemInstruction': {
            'parts': [
              {'text': system}
            ]
          },
        if (tools != null) 'tools': tools.map((t) => t.toJson()).toList(),
        'generationConfig': {
          // Gemini 3.x thinking configuration enum (minimal, medium, high)
          'thinkingConfig': {'thinkingLevel': 'minimal'},
          if (jsonMode) 'responseMimeType': 'application/json',
        },
      };

  // Extracts non-thought text strings from a candidate object.
  Iterable<String> _textFromCandidate(Map<String, dynamic> candidate) sync* {
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? [];
    for (final part in parts) {
      if (part is Map<String, dynamic> &&
          part.containsKey('text') &&
          part['thought'] != true) {
        final t = part['text'] as String? ?? '';
        if (t.isNotEmpty) yield t;
      }
    }
  }

  // Streams parsed SSE chunks from the streamGenerateContent endpoint.
  Stream<Map<String, dynamic>> _streamSse(Map<String, dynamic> body) async* {
    // Establish the connection with retries. Retrying is only safe here —
    // before any bytes are yielded — so a transient 503 never reaches the user,
    // but a mid-stream failure is not retried (it would duplicate output).
    http.Client client = http.Client();
    http.StreamedResponse streamed;
    for (var attempt = 0;; attempt++) {
      final uri = Uri.parse(
        '$_apiBase/$_model:streamGenerateContent?alt=sse&key=$_apiKey',
      );
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
      final resp = await client.send(request);
      if (resp.statusCode == 200) {
        streamed = resp;
        break;
      }
      final err = await resp.stream.bytesToString();

      // Automatically fallback to next model when daily free quota limit is reached.
      if (_isDailyQuotaExhausted(err)) {
        final fallback = _getFallbackModel(_model);
        if (fallback != null) {
          _model = fallback;
          notifyListeners();
          client.close();
          client = http.Client();
          continue;
        }
      }

      final customDelay = _extractRetryDelay(err);
      if (_isRetryableStatus(resp.statusCode) &&
          (attempt < _kMaxRetries || (customDelay != null && attempt < 4))) {
        client.close();
        final delay = customDelay ?? _retryBackoff(attempt);
        await Future.delayed(delay);
        client = http.Client();
        continue;
      }
      client.close();
      throw Exception(_errorMessage(resp.statusCode, err));
    }

    try {
      final lineBuf = StringBuffer();
      await for (final raw in streamed.stream.transform(utf8.decoder)) {
        lineBuf.write(raw);
        final text = lineBuf.toString();
        final lines = text.split('\n');
        lineBuf
          ..clear()
          ..write(lines.last); // keep potentially incomplete last line
        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (!line.startsWith('data: ')) continue;
          final payload = line.substring(6).trim();
          if (payload.isEmpty || payload == '[DONE]') continue;
          yield jsonDecode(payload) as Map<String, dynamic>;
        }
      }
      // Flush any remaining buffered line.
      final tail = lineBuf.toString().trim();
      if (tail.startsWith('data: ')) {
        final payload = tail.substring(6).trim();
        if (payload.isNotEmpty && payload != '[DONE]') {
          yield jsonDecode(payload) as Map<String, dynamic>;
        }
      }
    } finally {
      client.close();
    }
  }

  // Single-shot (non-streaming) generateContent call, with retry on 5xx/429.
  Future<Map<String, dynamic>> _generate(Map<String, dynamic> body) async {
    final payload = jsonEncode(body);
    for (var attempt = 0;; attempt++) {
      final uri = Uri.parse('$_apiBase/$_model:generateContent?key=$_apiKey');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (_isDailyQuotaExhausted(response.body)) {
        final fallback = _getFallbackModel(_model);
        if (fallback != null) {
          _model = fallback;
          notifyListeners();
          continue;
        }
      }

      final customDelay = _extractRetryDelay(response.body);
      if (_isRetryableStatus(response.statusCode) &&
          (attempt < _kMaxRetries || (customDelay != null && attempt < 4))) {
        final delay = customDelay ?? _retryBackoff(attempt);
        await Future.delayed(delay);
        continue;
      }
      throw Exception(_errorMessage(response.statusCode, response.body));
    }
  }

  String _textFromResponse(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) return '';
    return _textFromCandidate(candidates[0] as Map<String, dynamic>).join();
  }

  // ── Generic & domain chat (streaming + optional tool-call loop) ───────────
  @override
  Stream<String> streamChatReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  }) =>
      streamCoachReply(
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: history,
        tools: tools,
        onToolCall: onToolCall,
      );

  @override
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  }) async* {
    if (!isConfigured) {
      yield 'Please add your Gemini API key in Profile → AI Features to get started.';
      return;
    }
    try {
      // Build the mutable contents list; grows with each tool-call round.
      final contents = <dynamic>[
        ...history.map((c) => c.toJson()),
        Content.text(userMessage).toJson(),
      ];

      for (var round = 0; round < _kMaxToolRounds; round++) {
        final body = _makeBody(
          contents: contents,
          system: systemPrompt,
          tools: tools,
        );

        // Raw parts from the model turn — preserved verbatim so that any
        // thought_signature fields on functionCall parts are not dropped when
        // we echo this turn back to the API in the next round.
        final rawModelParts = <Map<String, dynamic>>[];
        final calls = <FunctionCall>[];
        Map<String, dynamic>? lastUsage;

        await for (final chunk in _streamSse(body)) {
          final candidates = chunk['candidates'] as List<dynamic>? ?? [];
          for (final raw in candidates) {
            final c = raw as Map<String, dynamic>;
            for (final t in _textFromCandidate(c)) {
              yield t;
            }
            // Collect raw parts for the model-turn echo.
            final content = c['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>? ?? [];
            for (final part in parts) {
              if (part is! Map<String, dynamic>) continue;
              rawModelParts.add(part);
              if (part.containsKey('functionCall')) {
                final fc = part['functionCall'] as Map<String, dynamic>;
                calls.add(FunctionCall(
                  fc['name'] as String,
                  (fc['args'] as Map<String, dynamic>? ?? {})
                      .cast<String, Object?>(),
                ));
              }
            }
          }
          if (chunk['usageMetadata'] != null) {
            lastUsage = chunk['usageMetadata'] as Map<String, dynamic>;
          }
        }
        _recordRawUsage(lastUsage);

        // No tools requested (or no handler) → the streamed text is the answer.
        if (calls.isEmpty || onToolCall == null) return;

        // Echo the model turn back verbatim (preserves thought_signature).
        contents.add({'role': 'model', 'parts': rawModelParts});

        // Resolve every call and feed the results back as one function turn.
        final responseParts = <Map<String, dynamic>>[];
        for (final call in calls) {
          try {
            final result = await onToolCall(call);
            responseParts.add({
              'functionResponse': {'name': call.name, 'response': result}
            });
          } catch (e) {
            responseParts.add({
              'functionResponse': {
                'name': call.name,
                'response': {'error': '$e'}
              }
            });
          }
        }
        contents.add({'role': 'user', 'parts': responseParts});
      }
      // Exhausted the tool-round budget without a final text answer.
      yield '\n\n_(Stopped after $_kMaxToolRounds tool steps — try rephrasing.)_';
    } catch (e) {
      yield 'Error: $e';
    }
  }

  // ── Generic domain-agnostic structured JSON generator ───────────────────
  @override
  Future<T> generateStructuredJson<T>({
    required String systemPrompt,
    required String userPrompt,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    if (!isConfigured) {
      throw StateError('Gemini API key not configured.');
    }
    try {
      final data = await _generate(
        _makeBody(
          contents: [Content.text(userPrompt).toJson()],
          system: systemPrompt,
          jsonMode: true,
        ),
      );
      _recordRawUsage(data['usageMetadata'] as Map<String, dynamic>?);
      final raw = _textFromResponse(data);
      if (raw.isEmpty) throw const FormatException('Empty response from Gemini.');

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return fromJson(map);
    } on FormatException catch (e) {
      throw Exception('Could not parse JSON output: $e');
    } catch (e) {
      throw Exception('Gemini API error: $e');
    }
  }

  // ── Program generator (structured JSON output) ────────────────────────────
  @override
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  }) async {
    final exerciseList = allExercises
        .map((e) => '  "${e.id}": "${e.name} [${e.primaryMuscle}]"')
        .join('\n');

    const systemPrompt = '''You are a certified strength and conditioning coach creating structured training programs for RepForge.
Return ONLY raw JSON — no markdown fences, no comments, no explanation text.
Use ONLY exercise IDs from the provided list as exerciseId values.

Required JSON schema (follow exactly):
{
  "id": "unique-string",
  "name": "Program Name",
  "description": "Brief description",
  "totalWeeks": <integer>,
  "author": "AI Coach",
  "isImported": true,
  "createdAt": "<ISO8601>",
  "phases": [
    {"id":"phase-1","name":"Phase Name","startWeek":1,"endWeek":<int>,"notes":"...","colorHex":null}
  ],
  "weeks": [
    {
      "weekNumber": 1,
      "isDeload": false,
      "deloadIntensityFactor": 1.0,
      "deloadSetReduction": 0,
      "phaseId": "phase-1",
      "notes": null,
      "days": [
        {
          "id": "w1-d1",
          "name": "Day Name",
          "dayOfWeek": 1,
          "notes": null,
          "exercises": [
            {
              "exerciseId": "<id from list>",
              "sets": 3,
              "minReps": 8,
              "maxReps": 12,
              "restSeconds": 90,
              "tempo": "2-1-1",
              "weightPercentage": null,
              "notes": null,
              "supersetGroupId": null
            }
          ]
        }
      ]
    }
  ]
}''';

    final prompt =
        'Available exercises (ID: name [primary muscle]):\n$exerciseList\n\nUser request: $userPrompt';

    return generateStructuredJson<TrainingProgram>(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      fromJson: (map) {
        // Ensure a fresh UUID so it never collides with an existing program.
        map['id'] = const Uuid().v4();
        map['isImported'] = true;
        map['author'] = 'AI Coach';
        return TrainingProgram.fromJson(map);
      },
    );
  }

  // ── Weekly insights (single-shot text) ────────────────────────────────────
  @override
  Future<String> generateWeeklyInsights(String contextText) async {
    if (!isConfigured) {
      return 'Add your Gemini API key in Profile → AI Features to unlock insights.';
    }
    const systemPrompt =
        'You are a performance coach giving weekly training feedback for RepForge users. '
        'Write 3–4 sentences in a conversational, encouraging tone. '
        'Be specific — reference actual exercise names and numbers from the data. '
        'Cover: biggest win, one thing to watch, one tip for next week. '
        'No bullet points, no headers — natural flowing prose only.';
    try {
      final data = await _generate(
        _makeBody(
          contents: [Content.text(contextText).toJson()],
          system: systemPrompt,
        ),
      );
      _recordRawUsage(data['usageMetadata'] as Map<String, dynamic>?);
      final text = _textFromResponse(data).trim();
      return text.isNotEmpty ? text : 'No insights generated.';
    } catch (e) {
      return 'Could not generate insights: $e';
    }
  }

  // ── Generic one-shot insight (contextual) ─────────────────────────────────
  @override
  Future<String> generateInsight(String system, String context) async {
    if (!isConfigured) {
      return 'Add your Gemini API key in Profile → AI Features to unlock insights.';
    }
    try {
      final data = await _generate(
        _makeBody(
          contents: [Content.text(context).toJson()],
          system: system,
        ),
      );
      _recordRawUsage(data['usageMetadata'] as Map<String, dynamic>?);
      final text = _textFromResponse(data).trim();
      return text.isNotEmpty ? text : 'No insight generated.';
    } catch (e) {
      return 'Could not generate insight: $e';
    }
  }
}
