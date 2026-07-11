// agent_runtime.dart — The graph-walking agent runtime engine.
//
// Executes an AgentGraph by starting at the entry node and following
// NextNode transitions until CompleteRun or InterruptRun. Emits AgentEvents
// throughout so the UI can react in real-time.
//
// Supports suspend/resume for human-in-the-loop via the resume() method.

import 'dart:async';

import 'package:uuid/uuid.dart';

import '../agent_event.dart';
import '../provider/model_runtime.dart';
import '../tools/tool_registry.dart';
import 'agent_context.dart';
import 'agent_graph.dart';
import 'agent_node.dart';
import 'agent_policies.dart';
import 'agent_run_state.dart';
import 'agent_trace.dart';

/// Input for starting an agent run.
class AgentRunInput {
  final String userMessage;
  final String? conversationId;

  const AgentRunInput({
    required this.userMessage,
    this.conversationId,
  });
}

/// The graph-walking agent runtime.
///
/// Call [run] to start a new agent execution. The returned stream emits
/// [AgentEvent]s as the graph executes. For human-in-the-loop, the stream
/// emits [AgentInterrupted] and pauses; call [resume] to continue.
class DefaultAgentRuntime {
  final ModelRuntime _model;
  final ToolRegistry _tools;
  final AgentPolicies _policies;

  /// Active suspended runs waiting for resume().
  final Map<String, _SuspendedRun> _suspendedRuns = {};

  DefaultAgentRuntime({
    required ModelRuntime model,
    required ToolRegistry tools,
    AgentPolicies policies = const AgentPolicies(),
  })  : _model = model,
        _tools = tools,
        _policies = policies;

  /// Whether the underlying model provider is configured.
  bool get isConfigured => _model.isConfigured;

  /// Start a new agent run, yielding [AgentEvent]s as the graph executes.
  Stream<AgentEvent> run({
    required AgentGraph graph,
    required AgentRunInput input,
  }) async* {
    final runId = const Uuid().v4();
    final trace = AgentTrace(runId);

    var state = AgentRunState(
      runId: runId,
      graphId: graph.id,
      userMessage: input.userMessage,
    );

    final controller = StreamController<AgentEvent>();

    void emit(AgentEvent event) {
      if (!controller.isClosed) controller.add(event);
    }

    // Emit the run start event so consumers can capture the run ID.
    emit(AgentRunStarted(runId));

    void updateState(AgentRunState newState) {
      state = newState;
    }

    final ctx = AgentContext(
      model: _model,
      tools: _tools,
      emit: emit,
      updateState: updateState,
      policies: _policies,
      trace: trace,
    );

    // Run the graph in a separate zone so events stream out while nodes execute.
    final graphFuture = _executeGraph(graph, ctx, state, emit, (s) {
      state = s;
    }).whenComplete(() {
      if (!controller.isClosed) controller.close();
    });

    // Merge: yield events as they arrive, then wait for completion.
    yield* controller.stream;
    await graphFuture;
  }

  /// Resume a suspended run with user input.
  Future<Stream<AgentEvent>> resume({
    required String runId,
    required Map<String, Object?> payload,
  }) async {
    final suspended = _suspendedRuns.remove(runId);
    if (suspended == null) {
      throw StateError('No suspended run found with id "$runId"');
    }

    // Set the resume payload in working memory.
    final resumedState = suspended.state.copyWith(
      workingMemory: {
        ...suspended.state.workingMemory,
        'resumePayload': payload,
      },
    );

    final controller = StreamController<AgentEvent>();

    void emit(AgentEvent event) {
      if (!controller.isClosed) controller.add(event);
    }

    final ctx = AgentContext(
      model: _model,
      tools: _tools,
      emit: emit,
      updateState: (s) {},
      policies: _policies,
      trace: suspended.trace,
    );

    // Continue from the await_user_input node.
    final graphFuture = _executeGraph(
      suspended.graph,
      ctx,
      resumedState,
      emit,
      (s) {},
      startNodeId: 'await_user_input',
    );

    // Don't await here — return the stream immediately.
    graphFuture.whenComplete(() {
      if (!controller.isClosed) controller.close();
    });

    return controller.stream;
  }

  /// Walk the graph from [startNodeId] (or graph.entryNodeId).
  Future<void> _executeGraph(
    AgentGraph graph,
    AgentContext ctx,
    AgentRunState state,
    void Function(AgentEvent) emit,
    void Function(AgentRunState) updateState, {
    String? startNodeId,
  }) async {
    var currentNodeId = startNodeId ?? graph.entryNodeId;
    var currentState = state;

    // Reconstruct context with our local updateState.
    final localCtx = AgentContext(
      model: ctx.model,
      tools: ctx.tools,
      emit: emit,
      updateState: (s) {
        currentState = s;
        updateState(s);
      },
      policies: ctx.policies,
      trace: ctx.trace,
    );

    try {
      while (true) {
        final node = graph.nodes[currentNodeId];
        if (node == null) {
          emit(AgentError('Graph "${graph.id}" has no node "$currentNodeId"'));
          break;
        }

        ctx.trace.add(TraceEntry.now(
          nodeId: currentNodeId,
          type: 'enter',
        ));

        final result = await node.execute(localCtx, currentState);

        switch (result) {
          case NextNode(:final nodeId):
            currentNodeId = nodeId;

          case CompleteRun():
            emit(AgentTraceEvent(currentNodeId, 'Run complete'));
            return;

          case InterruptRun(:final interrupt):
            emit(AgentInterrupted(interrupt));
            emit(AgentTraceEvent(
                currentNodeId, 'Run interrupted: $interrupt'));

            // Suspend this run for later resume.
            _suspendedRuns[currentState.runId] = _SuspendedRun(
              state: currentState,
              graph: graph,
              trace: ctx.trace,
            );
            return;
        }
      }
    } catch (e) {
      emit(AgentError('Runtime error: $e'));
    }
  }
}

/// A suspended run waiting for resume().
class _SuspendedRun {
  final AgentRunState state;
  final AgentGraph graph;
  final AgentTrace trace;

  const _SuspendedRun({
    required this.state,
    required this.graph,
    required this.trace,
  });
}
