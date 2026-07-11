import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/ai/agent_event.dart';
import 'package:repforge/services/ai/runtime/agent_context.dart';
import 'package:repforge/services/ai/runtime/agent_graph.dart';
import 'package:repforge/services/ai/runtime/agent_interrupt.dart';
import 'package:repforge/services/ai/runtime/agent_node.dart';
import 'package:repforge/services/ai/runtime/agent_run_state.dart';
import 'package:repforge/services/ai/runtime/agent_runtime.dart';
import 'package:repforge/services/ai/tools/tool_registry.dart';

import '../../../test_utils/fake_model_runtime.dart';

// Dummy nodes for testing
class _StartNode implements AgentNode {
  @override
  String get id => 'start';
  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    ctx.emit(const AgentStatusUpdate('Starting...'));
    return const NextNode('middle');
  }
}

class _MiddleNode implements AgentNode {
  @override
  String get id => 'middle';
  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    return const NextNode('end');
  }
}

class _EndNode implements AgentNode {
  @override
  String get id => 'end';
  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    return const CompleteRun();
  }
}

class _InterruptingNode implements AgentNode {
  @override
  String get id => 'interrupt';
  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    return InterruptRun(AwaitUserQuestions(PendingQuestions(questions: [])));
  }
}

class _AwaitUserInputNode implements AgentNode {
  @override
  String get id => 'await_user_input';
  @override
  Future<AgentNodeResult> execute(AgentContext ctx, AgentRunState state) async {
    final payload = state.workingMemory['resumePayload'];
    ctx.emit(AgentStatusUpdate('Resumed with $payload'));
    return const CompleteRun();
  }
}

void main() {
  group('DefaultAgentRuntime', () {
    test('executes a simple linear graph', () async {
      final graph = AgentGraph(
        id: 'test_graph',
        entryNodeId: 'start',
        nodes: {
          'start': _StartNode(),
          'middle': _MiddleNode(),
          'end': _EndNode(),
        },
      );

      final runtime = DefaultAgentRuntime(
        model: FakeModelRuntime(),
        tools: const ToolRegistry.empty(),
      );

      final events = await runtime.run(
        graph: graph,
        input: const AgentRunInput(userMessage: 'test'),
      ).toList();

      final textEvents = events.whereType<AgentStatusUpdate>().map((e) => e.status).toList();
      expect(textEvents, contains('Starting...'));

      final traceEvents = events.whereType<AgentTraceEvent>().toList();
      expect(traceEvents.last.nodeId, 'end');
      expect(traceEvents.last.message, 'Run complete');
    });

    test('suspends and resumes an interrupted graph', () async {
      final graph = AgentGraph(
        id: 'test_graph',
        entryNodeId: 'interrupt',
        nodes: {
          'interrupt': _InterruptingNode(),
          'await_user_input': _AwaitUserInputNode(),
        },
      );

      final runtime = DefaultAgentRuntime(
        model: FakeModelRuntime(),
        tools: const ToolRegistry.empty(),
      );

      // Run until interrupt
      final run1Events = await runtime.run(
        graph: graph,
        input: const AgentRunInput(userMessage: 'test'),
      ).toList();

      expect(run1Events.any((e) => e is AgentRunStarted), isTrue);
      expect(run1Events.any((e) => e is AgentInterrupted), isTrue);

      final startEvent = run1Events.firstWhere((e) => e is AgentRunStarted) as AgentRunStarted;
      final runId = startEvent.runId;

      // Resume the run
      final stream = await runtime.resume(
        runId: runId,
        payload: {'answer': 'yes'},
      );
      final run2Events = await stream.toList();

      expect(run2Events.any((e) => e is AgentRunStarted), isFalse); // Should not emit started on resume
      
      final textEvents = run2Events.whereType<AgentStatusUpdate>().map((e) => e.status).toList();
      expect(textEvents, contains('Resumed with {answer: yes}'));

      final traceEvents = run2Events.whereType<AgentTraceEvent>().toList();
      expect(traceEvents.last.nodeId, 'await_user_input');
      expect(traceEvents.last.message, 'Run complete');
    });
  });
}
