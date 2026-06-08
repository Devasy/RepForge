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
abstract class IAiService {
  /// True once an API key (or equivalent credential) has been supplied.
  bool get isConfigured;

  /// The model identifier currently in use (e.g. `gemini-3.1-flash-lite`).
  String get currentModel;

  /// Stream a coach reply token-by-token.
  ///
  /// When [tools] and [onToolCall] are provided, the implementation runs a
  /// tool-call loop: any function calls the model emits are dispatched through
  /// [onToolCall] and their results fed back, until the model produces a final
  /// natural-language answer. Only text is yielded to the caller.
  Stream<String> streamCoachReply({
    required String userMessage,
    required String systemPrompt,
    required List<Content> history,
    List<Tool>? tools,
    Future<Map<String, Object?>> Function(FunctionCall call)? onToolCall,
  });

  /// Generate a structured multi-week training program from a natural-language
  /// prompt, constrained to the provided exercise catalogue.
  Future<TrainingProgram> generateProgram({
    required String userPrompt,
    required List<Exercise> allExercises,
  });

  /// One-shot weekly training summary in conversational prose.
  Future<String> generateWeeklyInsights(String contextText);

  /// Generic one-shot contextual insight given a [system] instruction and
  /// [context] payload.
  Future<String> generateInsight(String system, String context);

  /// Analyse a routine's performance context and return structured optimization
  /// suggestions (reorder / replace / add exercises).
  Future<RoutineOptimizationResult> generateOptimization({
    required String contextPayload,
  });
}
