import 'dart:convert';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as sdk;

import '../ai_failure.dart';
import 'sdk_schema.dart';

Stream<String> legacyChatReply({
  required ModelProvider model,
  required String modelId,
  required int maxModelCalls,
  required String userMessage,
  required String systemPrompt,
  required List<sdk.Content> history,
  List<sdk.Tool>? tools,
  Future<Map<String, Object?>> Function(sdk.FunctionCall)? onToolCall,
  String? imageBytesBase64,
  String? imageMimeType,
}) async* {
  AgentRuntime? runtime;
  RunHandle? handle;
  final threadId = newIdentifier();
  try {
    final registry = ToolRegistry([
      for (final tool in tools ?? <sdk.Tool>[])
        for (final declaration
            in tool.functionDeclarations ?? <sdk.FunctionDeclaration>[])
          _CallbackTool(declaration, onToolCall),
    ]);
    final workflow = chatWorkflow(
      id: 'legacy-chat',
      modelId: modelId,
      systemPrompt: systemPrompt,
      tools: registry,
      initialMessages: [
        for (final content in history)
          ModelMessage(
            role: content.role == 'model' ? 'assistant' : 'user',
            text: content.parts
                .whereType<sdk.TextPart>()
                .map((part) => part.text)
                .join(),
            attachments: [
              for (final part in content.parts.whereType<sdk.DataPart>())
                {'mimeType': part.mimeType, 'data': base64Encode(part.bytes)},
            ],
          ),
      ],
      authorize: (_, _) => ToolAuthorization.allow,
    );
    runtime = AgentRuntime(
      store: MemoryCheckpointStore(),
      model: model,
      limits: RunLimits(
        maxModelCalls: maxModelCalls,
        maxToolCalls: maxModelCalls * 16,
        maxSteps: maxModelCalls * 20 + 1,
      ),
    );
    handle = await runtime.start(
      workflow: workflow,
      threadId: threadId,
      input: {
        'text': userMessage,
        'attachments': [
          if (imageBytesBase64 != null)
            {
              'mimeType': imageMimeType ?? 'image/jpeg',
              'data': imageBytesBase64,
            },
        ],
      },
    );
    await for (final event in handle.events) {
      if (event.type == RunEventType.textDelta) {
        yield event.data['text']! as String;
      }
    }
    final result = await handle.done;
    if (result.status != RunStatus.completed) {
      final code = result.failure?['code'];
      throw AiFailure(
        result.failure?['message'] as String? ??
            'Gemini could not finish this reply. Please try again.',
        canRetry:
            result.toolCalls == 0 &&
            !{
              'model_auth',
              'model_unavailable',
              'model_capability',
            }.contains(code),
      );
    }
  } on AiFailure {
    rethrow;
  } on OrchestrationException catch (error) {
    throw AiFailure(error.message, canRetry: false);
  } catch (error) {
    throw AiFailure.from(error);
  } finally {
    if (handle?.snapshot.status == RunStatus.running) {
      await runtime!.cancel(
        threadId,
        expectedRevision: handle!.snapshot.revision,
      );
    }
  }
}

class _CallbackTool implements AgentTool {
  @override
  final ToolDefinition definition;
  final Future<Map<String, Object?>> Function(sdk.FunctionCall)? callback;
  _CallbackTool(sdk.FunctionDeclaration declaration, this.callback)
    : definition = ToolDefinition(
        name: declaration.name,
        description: declaration.description,
        arguments: ValueSchema(sdkArgumentSchema(declaration)),
        effect: ToolEffect.write,
      );
  @override
  Future<ToolOutcome> execute(ToolContext context) async {
    context.cancellation.check();
    final handler = callback;
    if (handler == null) {
      return ToolSuccess({'error': 'No tool callback was provided.'});
    }
    return ToolSuccess(
      await handler(
        sdk.FunctionCall(context.call.name, context.call.arguments),
      ),
    );
  }
}
