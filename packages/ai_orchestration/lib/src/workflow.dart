import 'dart:async';

import 'json.dart';
import 'model.dart';
import 'schema.dart';
import 'tool.dart';

abstract interface class StateCodec<S> {
  JsonMap encode(S state);
  S decode(JsonMap json);
}

class InputRequest {
  final String id;
  final String kind;
  final ValueSchema responseSchema;
  final JsonMap payload;
  final String? callId;
  InputRequest({
    String? id,
    this.kind = 'input',
    required this.responseSchema,
    JsonMap payload = const {},
    this.callId,
  }) : id = id ?? newIdentifier(),
       payload = jsonObject(payload);
  InputRequest forCall(String id) => InputRequest(
    id: this.id,
    kind: kind,
    responseSchema: responseSchema,
    payload: payload,
    callId: id,
  );
  JsonMap toJson() => {
    'id': id,
    'kind': kind,
    'schema': responseSchema.definition,
    'payload': payload,
    'callId': callId,
  };
  factory InputRequest.fromJson(JsonMap json) => InputRequest(
    id: json['id']! as String,
    kind: json['kind']! as String,
    responseSchema: ValueSchema(jsonObject(json['schema'])),
    payload: jsonObject(json['payload']),
    callId: json['callId'] as String?,
  );
}

class ResumeInput {
  final InputRequest request;
  final Object? value;
  ResumeInput(this.request, Object? value) : value = freezeJson(value);
  JsonMap toJson() => {'request': request.toJson(), 'value': value};
  factory ResumeInput.fromJson(JsonMap json) => ResumeInput(
    InputRequest.fromJson(jsonObject(json['request'])),
    json['value'],
  );
}

sealed class Transition {
  const Transition();
}

class ContinueAt extends Transition {
  final String nodeId;
  const ContinueAt(this.nodeId);
}

class SuspendAt extends Transition {
  final String nodeId;
  final InputRequest request;
  const SuspendAt(this.nodeId, this.request);
}

class Complete extends Transition {
  const Complete();
}

class NodeResult<S> {
  final S Function(S current) update;
  final Transition transition;
  const NodeResult({required this.update, required this.transition});
}

class WorkflowNode<S> {
  final FutureOr<NodeResult<S>> Function(NodeContext context, S state) execute;
  final Set<String> destinations;
  final bool replaySafe;
  WorkflowNode({
    required this.execute,
    Set<String> destinations = const {},
    this.replaySafe = false,
  }) : destinations = Set.unmodifiable(destinations);
}

class Workflow<S> {
  final String id;
  final int version;
  final String entryNode;
  final StateCodec<S> codec;
  final S Function(S? previous, JsonMap input) initialize;
  final Map<String, WorkflowNode<S>> nodes;
  final ToolRegistry tools;
  final ToolPolicy authorize;
  Workflow({
    required this.id,
    this.version = 1,
    required this.entryNode,
    required this.codec,
    required this.initialize,
    required Map<String, WorkflowNode<S>> nodes,
    ToolRegistry? tools,
    this.authorize = readOnlyToolPolicy,
  }) : nodes = Map.unmodifiable(nodes),
       tools = tools ?? ToolRegistry([]) {
    if (id.isEmpty ||
        version < 1 ||
        !nodes.containsKey(entryNode) ||
        nodes.values.any(
          (node) =>
              node.destinations.any((target) => !nodes.containsKey(target)),
        )) {
      throw ArgumentError('Invalid workflow identity, entry, or destination.');
    }
  }
}

class RunLimits {
  final int maxSteps;
  final int maxModelCalls;
  final int maxToolCalls;
  final Duration activeTimeout;
  const RunLimits({
    this.maxSteps = 64,
    this.maxModelCalls = 12,
    this.maxToolCalls = 32,
    this.activeTimeout = const Duration(minutes: 2),
  });
  JsonMap toJson() => {
    'maxSteps': maxSteps,
    'maxModelCalls': maxModelCalls,
    'maxToolCalls': maxToolCalls,
    'timeoutMicros': activeTimeout.inMicroseconds,
  };
  factory RunLimits.fromJson(JsonMap json) => RunLimits(
    maxSteps: json['maxSteps']! as int,
    maxModelCalls: json['maxModelCalls']! as int,
    maxToolCalls: json['maxToolCalls']! as int,
    activeTimeout: Duration(microseconds: json['timeoutMicros']! as int),
  );
  void validate() {
    if (maxSteps < 1 ||
        maxModelCalls < 0 ||
        maxToolCalls < 0 ||
        activeTimeout <= Duration.zero) {
      throw ArgumentError(
        'Run limits must be non-negative with positive steps and timeout.',
      );
    }
  }
}

class CancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void check() {
    if (isCancelled) {
      throw const OrchestrationException('cancelled', 'Run cancelled.');
    }
  }
}

abstract interface class NodeContext {
  String get threadId;
  String get runId;
  ResumeInput? get resumeInput;
  CancellationToken get cancellation;
  DateTime get deadline;
  Future<T> wait<T>(Future<T> operation);
  Future<ModelReply> callModel(ModelRequest request);
  Future<ToolOutcome> executeTool(ToolCall call);
}
