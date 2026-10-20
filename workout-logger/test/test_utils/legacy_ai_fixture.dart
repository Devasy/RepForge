import 'dart:convert';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_gemini/ai_orchestration_gemini.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as sdk;
import 'package:repforge/services/ai/ai_failure.dart';
import 'package:repforge/services/interfaces/ai_service_interface.dart';

// Adapts existing scripted test fixtures to one invocation per model request.
mixin TestAiModelProvider implements ModelProvider {
  List<String>? _reply;
  Object? _error;

  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (request.messages.last.role == 'tool' && _reply != null) {
      final reply = _reply!;
      final error = _error;
      _reply = null;
      _error = null;
      if (error != null) throw _failure(error);
      for (final chunk in reply) {
        yield ModelText(chunk);
      }
      yield ModelFinished(ModelFinishReason.stop);
      return;
    }
    final ai = this as IAiService;
    final index = request.messages.lastIndexWhere(
      (message) => message.role == 'user',
    );
    final user = request.messages[index];
    final history = request.messages
        .take(index)
        .where((m) => m.role != 'tool')
        .map(
          (message) =>
              sdk.Content(message.role == 'assistant' ? 'model' : 'user', [
                for (final attachment in message.attachments)
                  sdk.DataPart(
                    attachment['mimeType']! as String,
                    base64Decode(attachment['data']! as String),
                  ),
                sdk.TextPart(
                  message.text.isEmpty && message.attachments.isNotEmpty
                      ? '[Attached image]'
                      : message.text,
                ),
              ]),
        )
        .toList();
    final calls = <ToolCall>[];
    final chunks = <String>[];
    Object? error;
    try {
      await for (final chunk in ai.streamCoachReply(
        userMessage: user.text,
        systemPrompt: request.systemPrompt,
        history: history,
        imageBytesBase64: user.attachments.firstOrNull?['data'] as String?,
        imageMimeType: user.attachments.firstOrNull?['mimeType'] as String?,
        onToolCall: (call) async {
          calls.add(
            ToolCall(
              id: newIdentifier(),
              name: call.name,
              arguments: call.args,
            ),
          );
          return {};
        },
      )) {
        if (calls.isEmpty) {
          yield ModelText(chunk);
        } else {
          chunks.add(chunk);
        }
      }
    } catch (caught) {
      error = caught;
    }
    if (calls.isNotEmpty) {
      _reply = chunks;
      _error = error;
      for (final call in calls) {
        yield ModelToolCall(call);
      }
      yield ModelFinished(ModelFinishReason.toolCalls);
    } else {
      if (error != null) throw _failure(error);
      yield ModelFinished(ModelFinishReason.stop);
    }
  }

  GeminiFailure _failure(Object error) {
    final safe = AiFailure.from(error);
    return GeminiFailure(
      'model_transport',
      safe.message,
      canRetry: safe.canRetry,
    );
  }
}
