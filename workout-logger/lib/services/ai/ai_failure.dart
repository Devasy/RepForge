/// A safe explanation of an AI failure, without exposing provider diagnostics.
class AiFailure {
  final String message;
  final bool canRetry;
  const AiFailure(this.message, {this.canRetry = true});

  static AiFailure from(Object error, {int? statusCode}) {
    final text = error.toString().toLowerCase();
    if (statusCode == 403 ||
        statusCode == 401 ||
        RegExp(r'\b(401|403)\b').hasMatch(text) ||
        text.contains('permission_denied') ||
        text.contains('api key')) {
      return const AiFailure(
        'Gemini cannot access your account. Check your API key and model access in Settings.',
        canRetry: false,
      );
    }
    if (statusCode == 404) {
      return const AiFailure(
        'This Gemini model is no longer available. Choose another model in Settings.',
        canRetry: false,
      );
    }
    if (statusCode == 429 ||
        text.contains('quota') ||
        text.contains('resource_exhausted')) {
      return const AiFailure(
        'Your Gemini usage limit has been reached. Wait a while before trying again, or check your Google AI plan.',
      );
    }
    if (statusCode == 503 ||
        text.contains('high demand') ||
        text.contains('overloaded') ||
        text.contains('unavailable')) {
      return const AiFailure(
        'Gemini is busy right now. Please try again in a moment.',
      );
    }
    if (text.contains('socket') ||
        text.contains('connection') ||
        text.contains('network') ||
        text.contains('clientexception')) {
      return const AiFailure(
        'The connection to Gemini was lost. Check your internet connection and try again.',
      );
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return const AiFailure(
        'Gemini took too long to respond. Please try again.',
      );
    }
    return const AiFailure(
      'Gemini could not finish this reply. Please try again.',
    );
  }

  @override
  String toString() => message;
}
