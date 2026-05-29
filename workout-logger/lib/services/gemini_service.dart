// gemini_service.dart — Gemini AI integration (coach chat, program gen, insights)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

// Ordered list of available Gemini models shown in the picker.
const kGeminiModels = [
  ('gemini-2.5-flash',      'Gemini 2.5 Flash'),
  ('gemini-3.0-flash',      'Gemini 3.0 Flash'),
  ('gemini-3.1-flash-lite', 'Gemini 3.1 Flash Lite'),
  ('gemini-3.5-flash',      'Gemini 3.5 Flash'),
];

const kDefaultGeminiModel = 'gemini-2.5-flash';

class GeminiService extends ChangeNotifier {
  String _apiKey = '';
  String _model = kDefaultGeminiModel;

  bool get isConfigured => _apiKey.isNotEmpty;
  String get currentModel => _model;

  void init(String apiKey, {String model = kDefaultGeminiModel}) {
    _apiKey = apiKey.trim();
    _model = model;
  }

  void updateApiKey(String key) {
    _apiKey = key.trim();
    notifyListeners();
  }

  void updateModel(String model) {
    _model = model;
    notifyListeners();
  }

  GenerativeModel _makeModel({bool jsonMode = false, String? system}) {
    return GenerativeModel(
      model: _model,
      apiKey: _apiKey,
      systemInstruction: system != null ? Content.system(system) : null,
      generationConfig: jsonMode
          ? GenerationConfig(responseMimeType: 'application/json')
          : null,
    );
  }

  // ── Coach chat (streaming) ─────────────────────────────────────────────────
  // [history] is the prior conversation as alternating user/model Content objects.
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
  }) async* {
    if (!isConfigured) {
      yield 'Please add your Gemini API key in Profile → AI Features to get started.';
      return;
    }
    try {
      final session = _makeModel(system: systemPrompt).startChat(history: history);
      await for (final chunk
          in session.sendMessageStream(Content.text(userMessage))) {
        final t = chunk.text;
        if (t != null && t.isNotEmpty) yield t;
      }
    } on GenerativeAIException catch (e) {
      yield 'AI error: ${e.message}';
    } catch (e) {
      yield 'Error: $e';
    }
  }

  // ── Program generator (structured JSON output) ────────────────────────────
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
      final raw = response.text ?? '';
      if (raw.isEmpty) throw FormatException('Empty response from Gemini.');

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
      return response.text?.trim() ?? 'No insights generated.';
    } on GenerativeAIException catch (e) {
      return 'AI error: ${e.message}';
    } catch (e) {
      return 'Could not generate insights: $e';
    }
  }

  // ── Generic one-shot insight (contextual) ─────────────────────────────────
  // Thin, tool-agnostic helper for on-demand contextual insights (muscle
  // drill-down, target suggestions, stalled-target nudges). Kept generic so a
  // future function-calling path can be added additively over [_makeModel].
  Future<String> generateInsight(String system, String context) async {
    if (!isConfigured) {
      return 'Add your Gemini API key in Profile → AI Features to unlock insights.';
    }
    try {
      final response = await _makeModel(system: system)
          .generateContent([Content.text(context)]);
      return response.text?.trim() ?? 'No insight generated.';
    } on GenerativeAIException catch (e) {
      return 'AI error: ${e.message}';
    } catch (e) {
      return 'Could not generate insight: $e';
    }
  }
}
