import 'json.dart';
import 'model.dart';
import 'tool.dart';
import 'workflow.dart';

class ChatState {
  final String modelId;
  final String systemPrompt;
  final List<ModelMessage> messages;
  final List<ToolCall> pendingCalls;
  final int nextCall;
  final List<Artifact> artifacts;
  final int turnStart;
  ChatState({
    required this.modelId,
    required this.systemPrompt,
    required List<ModelMessage> messages,
    List<ToolCall> pendingCalls = const [],
    this.nextCall = 0,
    List<Artifact> artifacts = const [],
    this.turnStart = 0,
  }) : messages = List.unmodifiable(messages),
       pendingCalls = List.unmodifiable(pendingCalls),
       artifacts = List.unmodifiable(artifacts);

  ChatState withReply(ModelReply reply) => ChatState(
    modelId: modelId,
    systemPrompt: systemPrompt,
    messages: [
      ...messages,
      ModelMessage(
        role: 'assistant',
        text: reply.text,
        calls: reply.calls,
        providerData: reply.finish.providerData,
      ),
    ],
    pendingCalls: reply.calls,
    artifacts: artifacts,
    turnStart: turnStart,
  );

  ChatState withResult(ToolSuccess result) {
    final byId = {for (final artifact in artifacts) artifact.id: artifact};
    for (final artifact in result.artifacts) {
      byId[artifact.id] = artifact;
    }
    return ChatState(
      modelId: modelId,
      systemPrompt: systemPrompt,
      messages: [
        ...messages,
        ModelMessage(
          role: 'tool',
          callId: pendingCalls[nextCall].id,
          result: result.data,
        ),
      ],
      pendingCalls: pendingCalls,
      nextCall: nextCall + 1,
      artifacts: byId.values.toList(),
      turnStart: turnStart,
    );
  }
}

class ChatStateCodec implements StateCodec<ChatState> {
  const ChatStateCodec();
  @override
  JsonMap encode(ChatState state) => {
    'modelId': state.modelId,
    'systemPrompt': state.systemPrompt,
    'messages': state.messages.map((message) => message.toJson()).toList(),
    'pendingCalls': state.pendingCalls.map((call) => call.toJson()).toList(),
    'nextCall': state.nextCall,
    'artifacts': state.artifacts.map((artifact) => artifact.toJson()).toList(),
    'turnStart': state.turnStart,
  };
  @override
  ChatState decode(JsonMap json) => ChatState(
    modelId: json['modelId']! as String,
    systemPrompt: json['systemPrompt']! as String,
    messages: (json['messages']! as List<Object?>)
        .map((item) => ModelMessage.fromJson(jsonObject(item)))
        .toList(),
    pendingCalls: (json['pendingCalls']! as List<Object?>)
        .map((item) => ToolCall.fromJson(jsonObject(item)))
        .toList(),
    nextCall: json['nextCall']! as int,
    turnStart: json['turnStart'] as int? ?? 0,
    artifacts: (json['artifacts']! as List<Object?>)
        .map((item) => Artifact.fromJson(jsonObject(item)))
        .toList(),
  );
}

Workflow<ChatState> chatWorkflow({
  required String id,
  int version = 1,
  required String modelId,
  required String systemPrompt,
  required ToolRegistry tools,
  ToolPolicy authorize = readOnlyToolPolicy,
  int maxMessages = 200,
  List<ModelMessage> initialMessages = const [],
}) {
  if (maxMessages < 1) throw ArgumentError('maxMessages must be positive.');
  return Workflow(
    id: id,
    version: version,
    entryNode: 'model',
    codec: const ChatStateCodec(),
    tools: tools,
    authorize: authorize,
    initialize: (previous, input) {
      final messages = [...previous?.messages ?? initialMessages];
      if (previous != null) {
        for (final call in previous.pendingCalls.skip(previous.nextCall)) {
          messages.add(
            ModelMessage(
              role: 'tool',
              callId: call.id,
              result: {
                'status': 'unknown',
                'message':
                    'The previous run ended without a recorded result. Do not assume this action completed or failed.',
              },
            ),
          );
        }
      }
      final text = input['text'] as String? ?? '';
      final attachments = (input['attachments'] as List<Object?>? ?? const [])
          .map(jsonObject)
          .toList();
      if (text.trim().isEmpty && attachments.isEmpty) {
        throw ArgumentError('A message or attachment is required.');
      }
      messages.add(
        ModelMessage(role: 'user', text: text, attachments: attachments),
      );
      return ChatState(
        modelId: modelId,
        systemPrompt: systemPrompt,
        messages: messages,
        artifacts: previous?.artifacts ?? const [],
        turnStart: messages.length - 1,
      );
    },
    nodes: {
      'model': WorkflowNode(
        replaySafe: true,
        destinations: {'tool'},
        execute: (context, state) async {
          if (state.messages.length > maxMessages) {
            throw const OrchestrationException(
              'context_budget',
              'Conversation needs host-managed compaction.',
            );
          }
          final reply = await context.callModel(
            ModelRequest(
              modelId: state.modelId,
              systemPrompt: state.systemPrompt,
              messages: state.messages,
              tools: tools.definitions,
            ),
          );
          return NodeResult(
            update: (current) => current.withReply(reply),
            transition: reply.calls.isEmpty
                ? const Complete()
                : const ContinueAt('tool'),
          );
        },
      ),
      'tool': WorkflowNode(
        destinations: {'tool', 'model'},
        execute: (context, state) async {
          if (state.nextCall >= state.pendingCalls.length) {
            return NodeResult(
              update: (current) => current,
              transition: const ContinueAt('model'),
            );
          }
          final outcome = await context.executeTool(
            state.pendingCalls[state.nextCall],
          );
          return switch (outcome) {
            ToolNeedsInput(:final request) => NodeResult(
              update: (current) => current,
              transition: SuspendAt('tool', request),
            ),
            ToolSuccess() => NodeResult(
              update: (current) => current.withResult(outcome),
              transition: state.nextCall + 1 < state.pendingCalls.length
                  ? const ContinueAt('tool')
                  : const ContinueAt('model'),
            ),
          };
        },
      ),
    },
  );
}
