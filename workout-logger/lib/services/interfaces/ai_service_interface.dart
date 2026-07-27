// Abstract AI Service Interface (Dependency Inversion Principle)
//
// Defines the contract for the conversational AI / generation backend.
// High-level modules (the coach ViewModel, program generator) depend on this
// abstraction rather than a concrete SDK, so the backend can be swapped (e.g.
// google_generative_ai today → firebase_ai later) without touching consumers.
//
// The signatures intentionally use the google_generative_ai content model
// (Content / Tool / FunctionCall). firebase_ai exposes an almost identical
// shape, so a future backend swap is a mechanical adapter rather than a rewrite.

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../models/models.dart';

/// Contract for the AI backend used across RepForge (coach chat, program
/// generation, insights). Implemented by [GeminiAiService] today.
abstract mixin class IAiService {
  /// True once an API key (or equivalent credential) has been supplied.
  bool get isConfigured;

  /// The model identifier currently in use (e.g. `gemini-3.6-flash`).
  String get currentModel;

  /// Stream a chat reply token-by-token across any domain.
  ///
  /// Defaults to calling [streamCoachReply] for backward compatibility.
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

  /// Stream a coach reply (alias for backward compatibility).
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  });

  /// Generic domain-agnostic structured JSON generator.
  /// Generates a structured object [T] by prompting the LLM for JSON and
  /// decoding it via [fromJson].
  Future<T> generateStructuredJson<T>({
    required String systemPrompt,
    required String userPrompt,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    throw UnimplementedError('generateStructuredJson not implemented.');
  }

  /// Generate a structured multi-week training program from a natural-language
  /// prompt, constrained to the provided exercise catalogue.
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  });

  /// One-shot weekly summary in conversational prose.
  Future<String> generateWeeklyInsights(String contextText);

  /// Generic one-shot contextual insight given a [system] instruction and
  /// [context] payload.
  Future<String> generateInsight(String system, String context);
}
