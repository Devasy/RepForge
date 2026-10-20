import 'dart:async';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:flutter/foundation.dart';

import 'agent_view_state.dart';

final _observers = Expando<RunObserver>('orchestration run observations');

/// One subscription per handle keeps in-flight progress across view detachments.
RunObserver observeRun(RunHandle handle) =>
    _observers[handle] ??= RunObserver(handle);

class RunObserver extends ChangeNotifier {
  final RunHandle handle;
  late RunCheckpoint checkpoint = handle.snapshot;
  String streamingText = '';
  final Map<String, ActiveAgentTool> activeTools = {};
  final Map<String, Artifact> artifacts = {};
  AgentControllerFailure? failure;
  bool ended = false;
  int _lastSequence = -1;
  late final StreamSubscription<RunEvent> _subscription;

  RunObserver(this.handle) {
    _subscription = handle.events.listen(_event, onError: _error);
    unawaited(handle.done.then(_finished, onError: _error));
  }

  void _event(RunEvent event) {
    if (ended ||
        event.runId != checkpoint.runId ||
        event.sequence <= _lastSequence) {
      return;
    }
    _lastSequence = event.sequence;
    if (event.sequence <= checkpoint.sequence) return;
    switch (event.type) {
      case RunEventType.textDelta:
        streamingText += event.data['text']! as String;
      case RunEventType.toolStarted:
        final id = event.callId;
        if (id != null) {
          activeTools[id] = ActiveAgentTool(
            callId: id,
            name: event.data['tool']! as String,
          );
        }
      case RunEventType.toolCompleted:
        activeTools.remove(event.callId);
      case RunEventType.artifact:
        final artifact = Artifact.fromJson(event.data);
        artifacts[artifact.id] = artifact;
      case RunEventType.checkpoint ||
          RunEventType.interrupted ||
          RunEventType.completed ||
          RunEventType.failed ||
          RunEventType.cancelled ||
          RunEventType.exhausted:
        checkpoint = handle.snapshot;
        _clearProgress();
      case RunEventType.started ||
          RunEventType.resumed ||
          RunEventType.nodeStarted:
        break;
    }
    notifyListeners();
  }

  void _clearProgress() {
    streamingText = '';
    activeTools.clear();
    artifacts.clear();
  }

  void _finished(RunCheckpoint saved) {
    if (ended) return;
    ended = true;
    checkpoint = saved;
    _clearProgress();
    notifyListeners();
    unawaited(_subscription.cancel());
    dispose();
  }

  void _error(Object error, StackTrace stack) {
    if (ended) return;
    ended = true;
    checkpoint = handle.snapshot;
    failure = AgentControllerFailure.from(error);
    _clearProgress();
    notifyListeners();
    unawaited(_subscription.cancel());
    dispose();
  }
}
