import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'repforge_tools.dart';

enum AgentChangeStatus {
  waiting,
  review,
  applying,
  applied,
  declined,
  failed,
  interrupted,
}

class AgentChange {
  final ToolCall call;
  final AgentChangeStatus status;
  const AgentChange(this.call, this.status);
}

class AgentChangeReview {
  final List<AgentChange> changes;
  final int position;
  final String id;
  const AgentChangeReview({
    required this.changes,
    required this.position,
    required this.id,
  });

  static AgentChangeReview? fromState(AgentViewState<ChatState> state) {
    final chat = state.data;
    if (chat == null || chat.pendingCalls.isEmpty) return null;
    final changes = <AgentChange>[];
    final results = {
      for (final message in chat.messages.reversed.takeWhile(
        (m) => m.role != 'assistant',
      ))
        if (message.role == 'tool') message.callId: message.result,
    };
    var position = 0;
    for (var index = 0; index < chat.pendingCalls.length; index++) {
      final call = chat.pendingCalls[index];
      if (!RepForgeTool.writes.contains(call.name)) continue;
      final result = results[call.id];
      final status = _status(state, chat, index, result);
      changes.add(AgentChange(call, status));
      if (index <= chat.nextCall) position = changes.length;
    }
    if (changes.isEmpty) return null;
    return AgentChangeReview(
      changes: List.unmodifiable(changes),
      position: position.clamp(1, changes.length),
      id: '${state.checkpoint!.runId}:${state.checkpoint!.modelCalls}',
    );
  }

  static AgentChangeStatus _status(
    AgentViewState<ChatState> state,
    ChatState chat,
    int index,
    JsonMap? result,
  ) {
    if (index < chat.nextCall) {
      if (result?['skipped'] == true) return AgentChangeStatus.declined;
      if (result?['error'] != null) return AgentChangeStatus.failed;
      return AgentChangeStatus.applied;
    }
    if (index != chat.nextCall) return AgentChangeStatus.waiting;
    if (state.needsRecovery || state.status == RunStatus.cancelled) {
      return AgentChangeStatus.interrupted;
    }
    if (state.status == RunStatus.failed ||
        state.status == RunStatus.exhausted) {
      return AgentChangeStatus.failed;
    }
    final id = chat.pendingCalls[index].id;
    if (state.pendingInput?.request.callId == id &&
        state.pendingInput?.request.kind == 'tool_approval') {
      return AgentChangeStatus.review;
    }
    if (state.isRunning &&
        state.checkpoint?.resumeInput?.request.callId == id &&
        state.checkpoint?.resumeInput?.value == true) {
      return AgentChangeStatus.applying;
    }
    return AgentChangeStatus.waiting;
  }
}
