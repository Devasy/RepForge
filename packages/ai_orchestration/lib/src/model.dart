import 'json.dart';
import 'tool.dart';
import 'workflow.dart';

class ToolCall {
  final String id;
  final String name;
  final JsonMap arguments;
  ToolCall({required this.id, required this.name, JsonMap arguments = const {}})
    : arguments = jsonObject(arguments) {
    if (id.isEmpty || name.isEmpty) {
      throw ArgumentError('Tool identity is required.');
    }
  }
  JsonMap toJson() => {'id': id, 'name': name, 'arguments': arguments};
  factory ToolCall.fromJson(JsonMap json) => ToolCall(
    id: json['id']! as String,
    name: json['name']! as String,
    arguments: jsonObject(json['arguments']),
  );
}

class ModelMessage {
  final String role;
  final String text;
  final List<ToolCall> calls;
  final String? callId;
  final JsonMap? result;
  final List<JsonMap> attachments;
  final JsonMap providerData;
  ModelMessage({
    required this.role,
    this.text = '',
    List<ToolCall> calls = const [],
    this.callId,
    JsonMap? result,
    List<JsonMap> attachments = const [],
    JsonMap providerData = const {},
  }) : calls = List.unmodifiable(calls),
       result = result == null ? null : jsonObject(result),
       attachments = List.unmodifiable(attachments.map(jsonObject)),
       providerData = jsonObject(providerData) {
    if (!{'user', 'assistant', 'tool'}.contains(role) ||
        (role == 'tool' && (callId == null || result == null)) ||
        (role != 'assistant' && calls.isNotEmpty)) {
      throw ArgumentError('Invalid message role or tool correlation.');
    }
  }
  JsonMap toJson() => {
    'role': role,
    'text': text,
    'calls': calls.map((call) => call.toJson()).toList(),
    'callId': callId,
    'result': result,
    'attachments': attachments,
    'providerData': providerData,
  };
  factory ModelMessage.fromJson(JsonMap json) => ModelMessage(
    role: json['role']! as String,
    text: json['text']! as String,
    calls: (json['calls']! as List<Object?>)
        .map((item) => ToolCall.fromJson(jsonObject(item)))
        .toList(),
    callId: json['callId'] as String?,
    result: json['result'] == null ? null : jsonObject(json['result']),
    attachments: (json['attachments']! as List<Object?>)
        .map(jsonObject)
        .toList(),
    providerData: jsonObject(json['providerData']),
  );
}

class ModelRequest {
  final String modelId;
  final String systemPrompt;
  final List<ModelMessage> messages;
  final List<ToolDefinition> tools;
  ModelRequest({
    required this.modelId,
    required this.systemPrompt,
    required List<ModelMessage> messages,
    required List<ToolDefinition> tools,
  }) : messages = List.unmodifiable(messages),
       tools = List.unmodifiable(tools);
}

sealed class ModelEvent {
  const ModelEvent();
}

class ModelText extends ModelEvent {
  final String text;
  const ModelText(this.text);
}

class ModelToolCall extends ModelEvent {
  final ToolCall call;
  const ModelToolCall(this.call);
}

class ModelStatus extends ModelEvent {
  final String message;
  const ModelStatus(this.message);
}

enum ModelFinishReason { stop, toolCalls, length, blocked }

class ModelFinished extends ModelEvent {
  final ModelFinishReason reason;
  final JsonMap providerData;
  final JsonMap usage;
  ModelFinished(
    this.reason, {
    JsonMap providerData = const {},
    JsonMap usage = const {},
  }) : providerData = jsonObject(providerData),
       usage = jsonObject(usage);
}

abstract interface class ModelProvider {
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  );
}

class ModelReply {
  final String text;
  final List<ToolCall> calls;
  final ModelFinished finish;
  ModelReply(this.text, List<ToolCall> calls, this.finish)
    : calls = List.unmodifiable(calls);
}
