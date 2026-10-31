// Gemini settings, usage and generation facade; execution belongs to AgentRuntime.

import 'dart:convert';
import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_gemini/ai_orchestration_gemini.dart';
import 'ai_failure.dart';
import '../debug_log_buffer.dart';
import 'orchestration/legacy_chat.dart';
import '../interfaces/web_grounding_support.dart';
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
  ('gemini-2.5-flash-lite', 'Gemini 2.5 Flash Lite'),
  ('gemini-2.5-flash', 'Gemini 2.5 Flash'),
  ('gemini-3.1-flash-lite', 'Gemini 3.1 Flash Lite'),
  ('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite'),
  ('gemini-3.5-flash', 'Gemini 3.5 Flash'),
  ('gemini-3.6-flash', 'Gemini 3.6 Flash'),
  ('gemini-3.7-flash', 'Gemini 3.7 Flash'),
  ('gemini-3.8-flash', 'Gemini 3.8 Flash'),
];

// Ordered fastest/cheapest → most thorough. Matches the Gemini API's own
// thinkingLevel scale (gemini-2.x models don't use this — see
// supportedThinkingLevels).
const kThinkingLevels = ['minimal', 'low', 'medium', 'high'];

// Fastest level available on the default model.
const kDefaultThinkingLevel = 'minimal';

/// Thinking levels [model] accepts, in kThinkingLevels order. Empty for
/// gemini-2.x models, which use the older thinkingBudget shape and don't
/// support thinkingLevel at all. gemini-3.7-flash is the first 3.x model
/// that doesn't support 'minimal' — sending it returns an API error.
List<String> supportedThinkingLevels(String model) {
  if (model.startsWith('gemini-2')) return const [];
  final version = RegExp(r'^gemini-(\d+)\.(\d+)-flash$').firstMatch(model);
  if (version != null &&
      (int.parse(version.group(1)!) > 3 ||
          (version.group(1) == '3' && int.parse(version.group(2)!) >= 7))) {
    return const ['low', 'medium', 'high'];
  }
  return kThinkingLevels;
}

/// Snaps [level] to a value [model] actually supports, falling back to the
/// model's fastest supported level if [level] isn't valid for it. Returns
/// [level] unchanged for models with no thinkingLevel support at all.
String clampThinkingLevel(String model, String level) {
  final supported = supportedThinkingLevels(model);
  if (supported.isEmpty || supported.contains(level)) return level;
  return supported.first;
}

// Default to the latest GA model.
const kDefaultGeminiModel = 'gemini-3.6-flash';

// Default/minimum/maximum upper bound on tool-resolution rounds per user
// turn, to bound runaway loops. User-configurable via Profile → AI Features.
const int kDefaultMaxToolRounds = 5;
const int kMinMaxToolRounds = 3;
const int kMaxMaxToolRounds = 25;

String? getFallbackModel(String currentModel) {
  switch (currentModel) {
    case 'gemini-3.8-flash':
      return 'gemini-3.7-flash';
    case 'gemini-3.7-flash':
      return 'gemini-3.6-flash';
    case 'gemini-3.6-flash':
      return 'gemini-3.5-flash';
    case 'gemini-3.5-flash':
      return 'gemini-3.5-flash-lite';
    case 'gemini-3.5-flash-lite':
      return 'gemini-2.5-flash';
    case 'gemini-3.1-flash-lite':
    case 'gemini-2.5-flash':
      return 'gemini-2.5-flash-lite';
    default:
      return null;
  }
}

/// Combines adjacent user turns after an interrupted reply, as Gemini expects.
@visibleForTesting
List<Object?> buildGeminiChatContents(
  List<Content> history,
  List<Map<String, Object?>> userParts,
) {
  final contents = <Object?>[];
  for (final turn in [
    ...history.map((c) => c.toJson()),
    {'role': 'user', 'parts': userParts},
  ]) {
    final previous = contents.isEmpty ? null : contents.last;
    if (previous is Map &&
        previous['role'] == 'user' &&
        turn['role'] == 'user') {
      previous['parts'] = [
        ...(previous['parts'] as List),
        ...(turn['parts'] as List),
      ];
    } else {
      contents.add(Map<String, Object?>.from(turn));
    }
  }
  return contents;
}

class GeminiAiService extends ChangeNotifier
    implements IAiService, ModelProvider, WebGroundingSupport {
  // Optional storage so cumulative token usage survives restarts.
  final IStorageService? _storage;

  final http.Client Function()? _modelClientFactory;

  GeminiAiService({
    IStorageService? storage,
    http.Client Function()? modelClientFactory,
  }) : _storage = storage,
       _modelClientFactory = modelClientFactory;

  static const String _usageKey = 'aiTokenUsage';

  String _apiKey = '';
  String _model = kDefaultGeminiModel;
  int _maxToolRounds = kDefaultMaxToolRounds;
  String _thinkingLevel = kDefaultThinkingLevel;

  // Cumulative token usage across all AI calls (persisted).
  int _promptTokens = 0;
  int _responseTokens = 0;
  int _totalTokens = 0;
  int _requestCount = 0;

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  String get currentModel => _model;

  /// Upper bound on tool-resolution rounds per user turn.
  int get maxToolRounds => _maxToolRounds;

  /// Current thinkingLevel sent with 3.x requests. Always valid for
  /// [currentModel] — see [clampThinkingLevel].
  String get thinkingLevel => _thinkingLevel;

  /// Cumulative input (prompt) tokens billed across all AI calls.
  int get promptTokensUsed => _promptTokens;

  /// Cumulative output (response) tokens across all AI calls.
  int get responseTokensUsed => _responseTokens;

  /// Cumulative total tokens (prompt + response) across all AI calls.
  int get totalTokensUsed => _totalTokens;

  /// Number of AI requests recorded.
  int get aiRequestCount => _requestCount;

  void init(
    String apiKey, {
    String model = kDefaultGeminiModel,
    int maxToolRounds = kDefaultMaxToolRounds,
    String thinkingLevel = kDefaultThinkingLevel,
  }) {
    _apiKey = apiKey.trim();
    DebugLogBuffer.instance.protect(_apiKey);
    _model = model;
    _maxToolRounds = maxToolRounds.clamp(kMinMaxToolRounds, kMaxMaxToolRounds);
    _thinkingLevel = clampThinkingLevel(_model, thinkingLevel);
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
    DebugLogBuffer.instance.protect(_apiKey);
    notifyListeners();
  }

  void updateModel(String model) {
    _model = model;
    _thinkingLevel = clampThinkingLevel(_model, _thinkingLevel);
    notifyListeners();
  }

  void updateThinkingLevel(String level) {
    _thinkingLevel = clampThinkingLevel(_model, level);
    notifyListeners();
  }

  void updateMaxToolRounds(int rounds) {
    _maxToolRounds = rounds.clamp(kMinMaxToolRounds, kMaxMaxToolRounds);
    notifyListeners();
  }

  // ── Raw HTTP helpers ────────────────────────────────────────────────────────

  Map<String, dynamic> _makeBody({
    required List<Object?> contents,
    String? system,
    List<Tool>? tools,
    bool jsonMode = false,
  }) => {
    'contents': contents,
    if (system != null)
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
    if (tools != null) 'tools': tools.map((t) => t.toJson()).toList(),
    'generationConfig': {
      'thinkingConfig': _thinkingConfig,
      if (jsonMode) 'responseMimeType': 'application/json',
    },
  };

  // Every gemini-2.x model predates the Gemini 3.x thinking-level enum and
  // only understands the older thinkingBudget (integer token budget) shape;
  // 3.x models take thinkingLevel (see kThinkingLevels). Matched by family,
  // not the single 'gemini-2.5-flash' id, so a persisted legacy model id
  // that isn't in kGeminiModels (e.g. from a since-removed picker entry)
  // still gets the right shape instead of failing with no fallback. Since
  // the daily quota fallback chain can land on either family mid-conversation,
  // the config shape must match whichever model is currently selected.
  // _thinkingLevel is kept clamped to _model everywhere it's set, so it's
  // always a value _model actually accepts by the time this is read.
  Map<String, dynamic> get _thinkingConfig => _model.startsWith('gemini-2')
      ? {'thinkingBudget': 0}
      : {'thinkingLevel': _thinkingLevel};

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

  Future<Map<String, dynamic>> _generate(Map<String, dynamic> body) async {
    try {
      return await _modelProvider().generate(
        modelId: _model,
        body: jsonObject(body),
      );
    } on GeminiFailure catch (error) {
      throw AiFailure(error.message, canRetry: error.canRetry);
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
    String? imageBytesBase64,
    String? imageMimeType,
  }) => streamCoachReply(
    userMessage: userMessage,
    systemPrompt: systemPrompt,
    history: history,
    tools: tools,
    onToolCall: onToolCall,
    imageBytesBase64: imageBytesBase64,
    imageMimeType: imageMimeType,
  );

  @override
  bool get supportsWebGrounding => supportsGeminiWebGrounding(_model);

  GeminiModelProvider _modelProvider({bool enableWebSearch = true}) =>
      GeminiModelProvider(
        googleSearchEnabled: enableWebSearch
            ? supportsGeminiWebGrounding
            : null,
        apiKey: _apiKey,
        onDiagnostic: (event) =>
            DebugLogBuffer.instance.write('[AI] ${jsonEncode(event)}'),
        clientFactory: _modelClientFactory,
        generationConfig: (model) => {
          'thinkingConfig': model.startsWith('gemini-2')
              ? {'thinkingBudget': 0}
              : {'thinkingLevel': clampThinkingLevel(model, _thinkingLevel)},
        },
        fallbackModel: getFallbackModel,
        onModelChanged: (model) {
          _model = model;
          _thinkingLevel = clampThinkingLevel(model, _thinkingLevel);
          notifyListeners();
        },
        onUsage: (usage) async {
          try {
            await recordUsage(
              prompt: (usage['promptTokenCount'] as num?)?.toInt() ?? 0,
              response: (usage['candidatesTokenCount'] as num?)?.toInt() ?? 0,
              total: (usage['totalTokenCount'] as num?)?.toInt() ?? 0,
            );
          } catch (_) {
            debugPrint('Could not persist AI usage.');
          }
        },
      );

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) => _modelProvider().stream(
    ModelRequest(
      modelId: _model,
      systemPrompt: request.systemPrompt,
      messages: request.messages,
      tools: request.tools,
    ),
    cancellation,
  );

  @override
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
    String? imageBytesBase64,
    String? imageMimeType,
  }) => legacyChatReply(
    model: _modelProvider(enableWebSearch: false),
    modelId: _model,
    maxModelCalls: _maxToolRounds,
    userMessage: userMessage,
    systemPrompt: systemPrompt,
    history: history,
    tools: tools,
    onToolCall: onToolCall,
    imageBytesBase64: imageBytesBase64,
    imageMimeType: imageMimeType,
  );

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
      if (raw.isEmpty) {
        throw const FormatException('Empty response from Gemini.');
      }

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return fromJson(map);
    } on FormatException catch (e, st) {
      debugPrint('Gemini structured response parsing failed: $e\n$st');
      throw const AiFailure(
        'Gemini returned an incomplete response. Please try again.',
      );
    } catch (e) {
      throw e is AiFailure ? e : AiFailure.from(e);
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

    const systemPrompt =
        '''You are a certified strength and conditioning coach creating structured training programs for RepForge.
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
      return (e is AiFailure ? e : AiFailure.from(e)).message;
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
        _makeBody(contents: [Content.text(context).toJson()], system: system),
      );
      _recordRawUsage(data['usageMetadata'] as Map<String, dynamic>?);
      final text = _textFromResponse(data).trim();
      return text.isNotEmpty ? text : 'No insight generated.';
    } catch (e) {
      return (e is AiFailure ? e : AiFailure.from(e)).message;
    }
  }
}
