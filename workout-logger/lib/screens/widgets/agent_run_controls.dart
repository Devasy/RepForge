import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/material.dart';
import '../../services/ai/orchestration/agent_change_review.dart';
import '../../theme/app_theme.dart';
import 'agent_change_queue.dart';

class AgentRunControls extends StatelessWidget {
  final PendingAgentInput? pending;
  final AgentChangeReview? review;
  final bool needsRecovery;
  final bool isRunning;
  final String statusText;
  final Future<bool> Function(PendingAgentInput target, Object? response)
  onSubmit;
  final Future<void> Function() onStop;
  const AgentRunControls({
    super.key,
    required this.pending,
    required this.needsRecovery,
    required this.onSubmit,
    required this.onStop,
    this.review,
    this.isRunning = false,
    this.statusText = '',
  });

  @override
  Widget build(BuildContext context) {
    final target = pending;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (review != null)
          AgentChangeQueue(
            review: review!,
            pending: pending,
            onSubmit: onSubmit,
          )
        else if (target?.request.kind == 'tool_approval')
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AgentApprovalPrompt(
              pending: target!,
              title: agentChangeTitle(
                target.request.payload['tool']! as String,
              ),
              details: Text(
                (target.request.payload['arguments']! as Map<String, Object?>)
                    .entries
                    .map((e) => '${e.key.replaceAll('_', ' ')}: ${e.value}')
                    .join('\n'),
              ),
              onSubmit: (value) => onSubmit(target, value),
            ),
          ),
        if (needsRecovery)
          TextButton(
            onPressed: onStop,
            child: const Text('Stop interrupted reply'),
          )
        else if (isRunning)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(statusText.isEmpty ? 'Working…' : statusText),
                  ),
                ),
                TextButton(onPressed: onStop, child: const Text('Stop')),
              ],
            ),
          ),
      ],
    );
  }
}
