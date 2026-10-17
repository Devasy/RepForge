import 'json.dart';
import 'workflow.dart';

enum RunStatus { running, suspended, completed, failed, cancelled, exhausted }

class RunCheckpoint {
  final String threadId;
  final String runId;
  final String workflowId;
  final int workflowVersion;
  final int revision;
  final String nextNode;
  final RunStatus status;
  final JsonMap state;
  final JsonMap limits;
  final int steps;
  final int modelCalls;
  final int toolCalls;
  final int sequence;
  final int activeMicroseconds;
  final InputRequest? interrupt;
  final ResumeInput? resumeInput;
  final JsonMap? failure;
  RunCheckpoint({
    required this.threadId,
    required this.runId,
    required this.workflowId,
    required this.workflowVersion,
    required this.revision,
    required this.nextNode,
    required this.status,
    required JsonMap state,
    required JsonMap limits,
    this.steps = 0,
    this.modelCalls = 0,
    this.toolCalls = 0,
    this.sequence = 0,
    this.activeMicroseconds = 0,
    this.interrupt,
    this.resumeInput,
    JsonMap? failure,
  }) : state = jsonObject(state),
       limits = jsonObject(limits),
       failure = failure == null ? null : jsonObject(failure);

  JsonMap toJson() => {
    'format': 1,
    'threadId': threadId,
    'runId': runId,
    'workflowId': workflowId,
    'workflowVersion': workflowVersion,
    'revision': revision,
    'nextNode': nextNode,
    'status': status.name,
    'state': state,
    'limits': limits,
    'steps': steps,
    'modelCalls': modelCalls,
    'toolCalls': toolCalls,
    'sequence': sequence,
    'activeMicroseconds': activeMicroseconds,
    'interrupt': interrupt?.toJson(),
    'resumeInput': resumeInput?.toJson(),
    'failure': failure,
  };
  factory RunCheckpoint.fromJson(JsonMap json) {
    if (json['format'] != 1) {
      throw const FormatException('Unsupported checkpoint format.');
    }
    return RunCheckpoint(
      threadId: json['threadId']! as String,
      runId: json['runId']! as String,
      workflowId: json['workflowId']! as String,
      workflowVersion: json['workflowVersion']! as int,
      revision: json['revision']! as int,
      nextNode: json['nextNode']! as String,
      status: RunStatus.values.byName(json['status']! as String),
      state: jsonObject(json['state']),
      limits: jsonObject(json['limits']),
      steps: json['steps']! as int,
      modelCalls: json['modelCalls']! as int,
      toolCalls: json['toolCalls']! as int,
      sequence: json['sequence']! as int,
      activeMicroseconds: json['activeMicroseconds']! as int,
      interrupt: json['interrupt'] == null
          ? null
          : InputRequest.fromJson(jsonObject(json['interrupt'])),
      resumeInput: json['resumeInput'] == null
          ? null
          : ResumeInput.fromJson(jsonObject(json['resumeInput'])),
      failure: json['failure'] == null ? null : jsonObject(json['failure']),
    );
  }

  RunCheckpoint update(JsonMap changes) =>
      RunCheckpoint.fromJson({...toJson(), ...changes});
}

class CheckpointConflict extends OrchestrationException {
  const CheckpointConflict()
    : super('conflict', 'Checkpoint revision changed. Reload before retrying.');
}

abstract interface class CheckpointStore {
  Future<RunCheckpoint?> load(String threadId);
  Future<void> save(RunCheckpoint checkpoint, {required int? expectedRevision});
}

class MemoryCheckpointStore implements CheckpointStore {
  final Map<String, RunCheckpoint> _runs = {};
  @override
  Future<RunCheckpoint?> load(String threadId) async => _runs[threadId];
  @override
  Future<void> save(
    RunCheckpoint checkpoint, {
    required int? expectedRevision,
  }) async {
    if (_runs[checkpoint.threadId]?.revision != expectedRevision ||
        checkpoint.revision != (expectedRevision ?? -1) + 1) {
      throw const CheckpointConflict();
    }
    _runs[checkpoint.threadId] = checkpoint;
  }
}
