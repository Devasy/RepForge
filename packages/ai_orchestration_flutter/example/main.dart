import 'dart:async';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const BridgeExampleApp());

class BridgeExampleApp extends StatefulWidget {
  const BridgeExampleApp({super.key});
  @override
  State<BridgeExampleApp> createState() => _BridgeExampleAppState();
}

class _BridgeExampleAppState extends State<BridgeExampleApp> {
  final runtime = AgentRuntime(
    store: MemoryCheckpointStore(),
    model: _DemoModel(),
  );
  late final workflow = chatWorkflow(
    id: 'counter-demo',
    modelId: 'scripted',
    systemPrompt: 'Use the counter tool.',
    tools: ToolRegistry([_IncrementTool()]),
    authorize: (_, _) => ToolAuthorization.requireApproval,
  );
  bool _visible = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Orchestration bridge')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(
              onPressed: () => setState(() {
                _visible = !_visible;
              }),
              child: Text(_visible ? 'Hide panel' : 'Show panel'),
            ),
            const SizedBox(height: 12),
            if (_visible)
              Expanded(
                child: _RunPanel(runtime: runtime, workflow: workflow),
              ),
          ],
        ),
      ),
    ),
  );
}

class _RunPanel extends StatefulWidget {
  final AgentRuntime runtime;
  final Workflow<ChatState> workflow;
  const _RunPanel({required this.runtime, required this.workflow});
  @override
  State<_RunPanel> createState() => _RunPanelState();
}

class _RunPanelState extends State<_RunPanel> {
  late final controller = AgentController.chat(
    runtime: widget.runtime,
    workflow: widget.workflow,
    threadId: 'demo',
  );
  final registry = ArtifactRegistry([
    ArtifactRenderer(
      type: 'demo.counter',
      payloadSchema: ValueSchema.object(
        properties: {'count': ValueSchema.integer()},
        required: ['count'],
      ),
      builder: (_, artifact) => Text('Count: ${artifact.payload['count']}'),
    ),
  ]);
  @override
  void initState() {
    super.initState();
    unawaited(controller.restore());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AgentRunBuilder<ChatState>(
    controller: controller,
    builder: (context, state) => ListView(
      children: [
        Text('Status: ${state.status?.name ?? 'idle'}'),
        if (state.streamingText.isNotEmpty) Text(state.streamingText),
        if (state.error case final error?) Text(error.message),
        for (final artifact in state.artifacts)
          AgentArtifactView(artifact: artifact, registry: registry),
        const SizedBox(height: 16),
        AgentInputBuilder<ChatState>(
          controller: controller,
          builder: (_, pending, submit, busy) => AgentApprovalPrompt(
            key: ValueKey(pending.request.id),
            pending: pending,
            onSubmit: submit,
            isSubmitting: busy,
            details: const Text('Increase the demo counter by one.'),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: state.canStart
                  ? () => unawaited(
                      controller.start(input: {'text': 'Increment'}),
                    )
                  : null,
              child: const Text('Start'),
            ),
            TextButton(
              onPressed:
                  !state.isCommandPending &&
                      (state.isRunning || state.pendingInput != null)
                  ? () => unawaited(controller.cancel())
                  : null,
              child: const Text('Cancel run'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DemoModel implements ModelProvider {
  int _call = 0;
  @override
  Stream<ModelEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    if (request.messages.last.role == 'user') {
      yield ModelToolCall(
        ToolCall(id: 'increment-${_call++}', name: 'increment'),
      );
      yield ModelFinished(ModelFinishReason.toolCalls);
    } else {
      yield ModelText(
        request.messages.last.result!['skipped'] == true
            ? 'Declined.'
            : 'Counter updated.',
      );
      yield ModelFinished(ModelFinishReason.stop);
    }
  }
}

class _IncrementTool implements AgentTool {
  int _count = 0;
  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'increment',
    description: 'Increment the demo counter.',
    arguments: ValueSchema.object(),
    effect: ToolEffect.write,
  );
  @override
  ToolOutcome execute(ToolContext context) {
    context.cancellation.check();
    _count++;
    return ToolSuccess(
      {'count': _count},
      artifacts: [
        Artifact(
          id: 'counter',
          type: 'demo.counter',
          payload: {'count': _count},
        ),
      ],
    );
  }
}
