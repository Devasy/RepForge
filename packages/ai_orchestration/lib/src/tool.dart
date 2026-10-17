import 'dart:async';

import 'json.dart';
import 'model.dart';
import 'schema.dart';
import 'workflow.dart';

enum ToolEffect { read, write }

class ToolDefinition {
  final String name;
  final String description;
  final ValueSchema arguments;
  final ToolEffect effect;
  final bool replaySafe;
  ToolDefinition({
    required this.name,
    required this.description,
    required this.arguments,
    this.effect = ToolEffect.read,
    this.replaySafe = false,
  }) {
    if (name.isEmpty || arguments.definition['type'] != 'object') {
      throw ArgumentError('Tools require a name and object argument schema.');
    }
  }
}

class Artifact {
  final String id;
  final String type;
  final int version;
  final JsonMap payload;
  Artifact({
    required this.id,
    required this.type,
    this.version = 1,
    required JsonMap payload,
  }) : payload = jsonObject(payload);
  JsonMap toJson() => {
    'id': id,
    'type': type,
    'version': version,
    'payload': payload,
  };
  factory Artifact.fromJson(JsonMap json) => Artifact(
    id: json['id']! as String,
    type: json['type']! as String,
    version: json['version']! as int,
    payload: jsonObject(json['payload']),
  );
}

sealed class ToolOutcome {
  const ToolOutcome();
}

class ToolSuccess extends ToolOutcome {
  final JsonMap data;
  final List<Artifact> artifacts;
  ToolSuccess(JsonMap data, {List<Artifact> artifacts = const []})
    : data = jsonObject(data),
      artifacts = List.unmodifiable(artifacts);
}

class ToolNeedsInput extends ToolOutcome {
  final InputRequest request;
  const ToolNeedsInput(this.request);
}

class ToolContext {
  final String threadId;
  final String runId;
  final ToolCall call;
  final CancellationToken cancellation;
  final DateTime deadline;
  final int modelCallIndex;
  ToolContext({
    required this.threadId,
    required this.runId,
    required this.call,
    required this.cancellation,
    required this.deadline,
    this.modelCallIndex = 0,
  });
  String get operationId =>
      canonicalJson([threadId, runId, modelCallIndex, call.id]);
}

abstract interface class AgentTool {
  ToolDefinition get definition;
  FutureOr<ToolOutcome> execute(ToolContext context);
}

class ToolRegistry {
  final Map<String, AgentTool> _tools = {};
  ToolRegistry(Iterable<AgentTool> tools) {
    for (final tool in tools) {
      if (_tools.containsKey(tool.definition.name)) {
        throw ArgumentError('Duplicate tool: ${tool.definition.name}');
      }
      _tools[tool.definition.name] = tool;
    }
  }
  List<ToolDefinition> get definitions =>
      List.unmodifiable(_tools.values.map((tool) => tool.definition));
  AgentTool require(String name) =>
      _tools[name] ??
      (throw OrchestrationException(
        'unknown_tool',
        'Tool "$name" is not available.',
      ));
}

enum ToolAuthorization { allow, deny, requireApproval }

typedef ToolPolicy =
    FutureOr<ToolAuthorization> Function(
      ToolDefinition tool,
      ToolContext context,
    );

ToolAuthorization readOnlyToolPolicy(
  ToolDefinition tool,
  ToolContext context,
) => tool.effect == ToolEffect.read
    ? ToolAuthorization.allow
    : ToolAuthorization.deny;
