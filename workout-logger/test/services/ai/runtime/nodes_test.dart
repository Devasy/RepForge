import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/provider/model_message.dart';
import 'package:repforge/services/ai/runtime/agent_context.dart';
import 'package:repforge/services/ai/runtime/agent_node.dart';
import 'package:repforge/services/ai/runtime/agent_run_state.dart';
import 'package:repforge/services/ai/runtime/agent_trace.dart';
import 'package:repforge/services/ai/runtime/nodes/await_user_input_node.dart';
import 'package:repforge/services/ai/runtime/nodes/execute_tools_node.dart';
import 'package:repforge/services/ai/runtime/agent_policies.dart';
import 'package:repforge/services/ai/tools/tool_registry.dart';
import 'package:repforge/services/ai/tools/agent_tool.dart';
import 'package:repforge/services/ai/tools/tool_spec.dart';
import 'package:repforge/services/ai/tools/tool_metadata.dart';
import 'package:repforge/services/ai/tools/tool_result.dart';

import '../../../test_utils/fake_model_runtime.dart';

class _MockTool implements AgentTool {
  @override
  String get id => 'test_tool';

  @override
  ToolMetadata get metadata => const ToolMetadata(
        displayName: 'Test',
        kind: ToolKind.query,
        readOnly: true,
      );

  @override
  ToolSpec get spec => const ToolSpec(name: 'test_tool', description: 'test', parameters: {});

  @override
  Future<ToolResult> execute(ToolExecutionContext ctx) async {
    return const ToolResult(data: {'status': 'ok'});
  }
}

void main() {
  group('ExecuteToolsNode', () {
    test('executes tools and updates state', () async {
      final node = ExecuteToolsNode();
      final trace = AgentTrace('run1');
      var state = AgentRunState(
        runId: 'run1', 
        graphId: 'g1', 
        userMessage: 'test',
        transcript: [
          AssistantMessage(
            '',
            toolCalls: [
              const ToolCallIntent(toolName: 'test_tool', args: {}, callId: 'call1'),
            ],
          )
        ],
      );

      final registry = ToolRegistry([_MockTool()]);
      
      final ctx = AgentContext(
        model: FakeModelRuntime(),
        tools: registry,
        emit: (e) {},
        updateState: (s) => state = s,
        policies: const AgentPolicies(),
        trace: trace,
      );

      final result = await node.execute(ctx, state);
      expect(result, isA<NextNode>());
      expect((result as NextNode).nodeId, 'model_step');

      expect(state.transcript.last, isA<ToolResultMessage>());
      final trm = state.transcript.last as ToolResultMessage;
      expect(trm.results.length, 1);
      expect(trm.results.first.toolName, 'test_tool');
      expect(trm.results.first.data['status'], 'ok');
    });
  });

  group('AwaitUserInputNode', () {
    test('resumes and returns next node', () async {
      final node = AwaitUserInputNode();
      final trace = AgentTrace('run1');
      var state = const AgentRunState(runId: 'run1', graphId: 'g1', userMessage: 'test')
          .copyWith(workingMemory: {'resumePayload': {'answers': ['yes']}});

      final ctx = AgentContext(
        model: FakeModelRuntime(),
        tools: const ToolRegistry.empty(),
        emit: (e) {},
        updateState: (s) => state = s,
        policies: const AgentPolicies(),
        trace: trace,
      );

      final result = await node.execute(ctx, state);
      expect(result, isA<NextNode>());
      expect((result as NextNode).nodeId, 'model_step');
      
      expect(state.workingMemory['resumePayload'], isNull);
      expect(state.transcript.last, isA<ToolResultMessage>());
      final trm = state.transcript.last as ToolResultMessage;
      expect(trm.results.first.data['answers'], contains('yes'));
    });
  });
}
