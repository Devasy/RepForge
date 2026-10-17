import 'dart:async';
import 'package:ai_orchestration/ai_orchestration.dart';

class ScriptedModel implements ModelProvider {
  final List<List<ModelEvent>> turns;
  final List<ModelRequest> requests = [];
  ScriptedModel(this.turns);
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    requests.add(request);
    for (final event in turns[requests.length - 1]) {
      yield event;
    }
  }
}

class CallbackTool implements AgentTool {
  @override
  final ToolDefinition definition;
  final FutureOr<ToolOutcome> Function(ToolContext) action;
  CallbackTool(
    String name,
    this.action, {
    ToolEffect effect = ToolEffect.read,
    ValueSchema? arguments,
  }) : definition = ToolDefinition(
         name: name,
         description: 'Test tool',
         effect: effect,
         arguments: arguments ?? ValueSchema.object(),
       );
  @override
  FutureOr<ToolOutcome> execute(ToolContext context) => action(context);
}

Workflow<ChatState> buildChat(
  List<AgentTool> tools, {
  ToolPolicy authorize = readOnlyToolPolicy,
  String modelId = 'test',
  int version = 1,
}) => chatWorkflow(
  id: 'test-chat',
  version: version,
  modelId: modelId,
  systemPrompt: 'Test.',
  tools: ToolRegistry(tools),
  authorize: authorize,
);

List<ModelEvent> answer(String text) => [
  ModelText(text),
  ModelFinished(ModelFinishReason.stop),
];
List<ModelEvent> calls(List<ToolCall> calls) => [
  ...calls.map(ModelToolCall.new),
  ModelFinished(ModelFinishReason.toolCalls),
];

Future<RunCheckpoint> turn(
  AgentRuntime runtime,
  Workflow<ChatState> workflow, {
  String thread = 'thread',
  String text = 'Hello',
}) async => (await runtime.start(
  workflow: workflow,
  threadId: thread,
  input: {'text': text},
)).done;

class IntCodec implements StateCodec<int> {
  @override
  int decode(JsonMap json) => json['value']! as int;
  @override
  JsonMap encode(int state) => {'value': state};
}

Workflow<int> intWorkflow(WorkflowNode<int> node) => Workflow(
  id: 'counter',
  entryNode: 'count',
  codec: IntCodec(),
  initialize: (previous, input) => previous ?? 0,
  nodes: {'count': node},
);
