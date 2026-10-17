import 'package:ai_orchestration/ai_orchestration.dart';

/// A deterministic provider makes this example runnable without credentials.
class ExpenseModel implements ModelProvider {
  int _turn = 0;
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (_turn++ == 0) {
      yield ModelToolCall(ToolCall(id: 'category-1', name: 'choose_category'));
      yield ModelFinished(ModelFinishReason.toolCalls);
    } else {
      final category = request.messages.last.result!['response'];
      yield ModelText('Showing your $category expenses.');
      yield ModelFinished(ModelFinishReason.stop);
    }
  }
}

class ChooseCategory implements AgentTool {
  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'choose_category',
    description: 'Ask which expense category the user wants to inspect.',
    arguments: ValueSchema.object(),
    replaySafe: true,
  );
  @override
  ToolOutcome execute(ToolContext context) => ToolNeedsInput(
    InputRequest(
      responseSchema: ValueSchema.string(values: ['food', 'travel']),
      payload: {
        'question': 'Which category?',
        'options': ['food', 'travel'],
      },
    ),
  );
}

Future<void> main() async {
  final store = MemoryCheckpointStore();
  final model = ExpenseModel();
  final workflow = chatWorkflow(
    id: 'expense-assistant',
    modelId: 'demo',
    systemPrompt: 'Help the user inspect expenses.',
    tools: ToolRegistry([ChooseCategory()]),
  );
  final runtime = AgentRuntime(store: store, model: model);
  final started = await runtime.start(
    workflow: workflow,
    threadId: 'expense-chat',
    input: {'text': 'Help me inspect my spending.'},
  );
  final paused = await started.done;
  print('${paused.status.name}: ${paused.interrupt!.payload['question']}');
  final resumed = await AgentRuntime(store: store, model: model).resume(
    workflow: workflow,
    threadId: paused.threadId,
    runId: paused.runId,
    interruptId: paused.interrupt!.id,
    expectedRevision: paused.revision,
    value: 'food',
  );
  final completed = await resumed.done;
  print(const ChatStateCodec().decode(completed.state).messages.last.text);
}
