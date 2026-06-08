// gemini_ai_service.dart — google_generative_ai implementation of IAiService.
//
// Backs the AI coach chat (streaming + tool calling), program generation, and
// insights. Uses a user-supplied Google AI Studio API key (free-tier friendly).
// Implements [IAiService] so the backend can be swapped (e.g. firebase_ai)
// without touching consumers.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../interfaces/ai_service_interface.dart';
import '../interfaces/storage_service_interface.dart';

// Ordered list of available Gemini models shown in the picker.
const kGeminiModels = [
  ('gemini-2.5-flash',      'Gemini 2.5 Flash'),
  ('gemini-3.0-flash',      'Gemini 3.0 Flash'),
  ('gemini-3.1-flash-lite', 'Gemini 3.1 Flash Lite'),
  ('gemini-3.5-flash',      'Gemini 3.5 Flash'),
];

// Default to a fast, free-tier 3.x model. gemini-3.5-flash is selectable and
// preferable when heavy tool-calling reliability matters.
const kDefaultGeminiModel = 'gemini-3.1-flash-lite';

// Upper bound on tool-resolution rounds per user turn, to bound runaway loops.
const int _kMaxToolRounds = 5;

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
  /// fed from a response's [UsageMetadata] via [_recordUsage].
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

  void _recordUsage(UsageMetadata? m) {
    if (m == null) return;
    final p = m.promptTokenCount ?? 0;
    final r = m.candidatesTokenCount ?? 0;
    recordUsage(prompt: p, response: r, total: m.totalTokenCount ?? (p + r));
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

  GenerativeModel _makeModel({
    bool jsonMode = false,
    String? system,
    List<Tool>? tools,
  }) {
    return GenerativeModel(
      model: _model,
      apiKey: _apiKey,
      systemInstruction: system != null ? Content.system(system) : null,
      tools: tools,
      generationConfig: jsonMode
          ? GenerationConfig(responseMimeType: 'application/json')
          : null,
    );
  }

  // ── Coach chat (streaming + optional tool-call loop) ───────────────────────
  // [history] is the prior conversation as alternating user/model Content.
  // When [tools] + [onToolCall] are supplied, function calls the model emits
  // are dispatched and their results fed back until a text answer is produced.
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
      final chat = _makeModel(system: systemPrompt, tools: tools)
          .startChat(history: history);

      Content next = Content.text(userMessage);

      for (var round = 0; round < _kMaxToolRounds; round++) {
        final calls = <FunctionCall>[];
        UsageMetadata? roundUsage;
        await for (final chunk in chat.sendMessageStream(next)) {
          final t = chunk.text;
          if (t != null && t.isNotEmpty) yield t;
          calls.addAll(chunk.functionCalls);
          if (chunk.usageMetadata != null) roundUsage = chunk.usageMetadata;
        }
        // The final chunk of each round carries that round's cumulative usage.
        _recordUsage(roundUsage);

        // No tools requested (or no handler) → the streamed text is the answer.
        if (calls.isEmpty || onToolCall == null) return;

        // Resolve every requested call and feed the results back as one turn.
        final responses = <FunctionResponse>[];
        for (final call in calls) {
          try {
            final result = await onToolCall(call);
            responses.add(FunctionResponse(call.name, result));
          } catch (e) {
            responses.add(FunctionResponse(call.name, {'error': '$e'}));
          }
        }
        next = Content.functionResponses(responses);
      }
      // Exhausted the tool-round budget without a final text answer.
      yield '\n\n_(Stopped after $_kMaxToolRounds tool steps — try rephrasing.)_';
    } on GenerativeAIException catch (e) {
      yield 'AI error: ${e.message}';
    } catch (e) {
      yield 'Error: $e';
    }
  }

  // ── Program generator (structured JSON output) ────────────────────────────
  @override
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  }) async {
    if (!isConfigured) {
      throw StateError('Gemini API key not configured.');
    }

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

    try {
      final response = await _makeModel(jsonMode: true, system: systemPrompt)
          .generateContent([Content.text(prompt)]);
      _recordUsage(response.usageMetadata);
      final raw = response.text ?? '';
      if (raw.isEmpty) throw const FormatException('Empty response from Gemini.');

      final data = jsonDecode(raw) as Map<String, dynamic>;
      // Ensure a fresh UUID so it never collides with an existing program.
      data['id'] = const Uuid().v4();
      data['isImported'] = true;
      data['author'] = 'AI Coach';
      return TrainingProgram.fromJson(data);
    } on GenerativeAIException catch (e) {
      throw Exception('Gemini API error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Could not parse program JSON: $e');
    }
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
      final response = await _makeModel(system: systemPrompt)
          .generateContent([Content.text(contextText)]);
      _recordUsage(response.usageMetadata);
      return response.text?.trim() ?? 'No insights generated.';
    } on GenerativeAIException catch (e) {
      return 'AI error: ${e.message}';
    } catch (e) {
      return 'Could not generate insights: $e';
    }
  }

  // ── Routine optimizer (structured JSON output) ────────────────────────────
  @override
  Future<RoutineOptimizationResult> generateOptimization({
    required String contextPayload,
  }) async {
    if (!isConfigured) {
      throw StateError('Gemini API key not configured.');
    }

    const systemPrompt =
        'You are a certified strength coach analysing a workout routine for RepForge.\n'
        'Return ONLY raw JSON — no markdown fences, no comments, no explanation text.\n'
        'Produce 1–3 suggestions total, at most one of each type: reorder, replace, add.\n'
        'Base recommendations strictly on the performance data provided.\n'
        'For reorder and remove_exercise_id use ONLY exercise IDs already present in the routine.\n'
        'For replace_with_name and add_exercise_name use ONLY names from the Available exercises list.\n\n'
        'Required JSON schema (follow exactly):\n'
        '{\n'
        '  "summary": "<1-2 sentence overall assessment>",\n'
        '  "suggestions": [\n'
        '    {\n'
        '      "type": "reorder",\n'
        '      "reasoning": "<why this order is better>",\n'
        '      "reordered_exercise_ids": ["<id>", "<id>", ...]\n'
        '    },\n'
        '    {\n'
        '      "type": "replace",\n'
        '      "reasoning": "<why to swap>",\n'
        '      "remove_exercise_id": "<id of exercise to drop>",\n'
        '      "replace_with_name": "<exact name from catalogue>"\n'
        '    },\n'
        '    {\n'
        '      "type": "add",\n'
        '      "reasoning": "<why to add>",\n'
        '      "add_exercise_name": "<exact name from catalogue>"\n'
        '    }\n'
        '  ]\n'
        '}\n'
        'Include only the suggestion types that are genuinely beneficial. '
        'Omit a type entirely if no meaningful improvement can be made.';

    try {
      final response =
          await _makeModel(jsonMode: true, system: systemPrompt)
              .generateContent([Content.text(contextPayload)]);
      _recordUsage(response.usageMetadata);
      final raw = response.text ?? '';
      if (raw.isEmpty) throw const FormatException('Empty response from Gemini.');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return RoutineOptimizationResult.fromJson(data);
    } on GenerativeAIException catch (e) {
      throw Exception('Gemini API error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Could not parse optimization JSON: $e');
    }
  }

  // ── Generic one-shot insight (contextual) ─────────────────────────────────
  @override
  Future<String> generateInsight(String system, String context) async {
    if (!isConfigured) {
      return 'Add your Gemini API key in Profile → AI Features to unlock insights.';
    }
    try {
      final response = await _makeModel(system: system)
          .generateContent([Content.text(context)]);
      _recordUsage(response.usageMetadata);
      return response.text?.trim() ?? 'No insight generated.';
    } on GenerativeAIException catch (e) {
      return 'AI error: ${e.message}';
    } catch (e) {
      return 'Could not generate insight: $e';
    }
  }
}
