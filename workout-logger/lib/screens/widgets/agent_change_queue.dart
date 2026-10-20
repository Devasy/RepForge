import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/material.dart';
import '../../services/ai/orchestration/agent_change_review.dart';
import '../../theme/app_theme.dart';

String agentChangeTitle(String tool) => switch (tool) {
  'create_routine' => 'Create routine',
  'update_routine' => 'Update routine',
  'add_custom_exercise' => 'Create exercise',
  'update_exercise' => 'Update exercise',
  _ => 'Apply proposed change',
};

class AgentChangeQueue extends StatelessWidget {
  final AgentChangeReview review;
  final PendingAgentInput? pending;
  final Future<bool> Function(PendingAgentInput, Object?) onSubmit;
  const AgentChangeQueue({
    super.key,
    required this.review,
    required this.pending,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            'Review changes ${review.position}/${review.changes.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Text(
          'Changes in this proposal. Review each before it is applied.',
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height:
              ((MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom) *
                      .35)
                  .clamp(80, 320),
          child: SingleChildScrollView(
            key: ValueKey(review.id),
            child: Column(
              children: [
                for (var i = 0; i < review.changes.length; i++)
                  _ChangeRow(
                    key: ValueKey(review.changes[i].call.id),
                    change: review.changes[i],
                    position: i + 1,
                    total: review.changes.length,
                    pending: pending,
                    onSubmit: onSubmit,
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChangeRow extends StatelessWidget {
  final AgentChange change;
  final int position;
  final int total;
  final PendingAgentInput? pending;
  final Future<bool> Function(PendingAgentInput, Object?) onSubmit;
  const _ChangeRow({
    super.key,
    required this.change,
    required this.position,
    required this.total,
    required this.pending,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final target = pending;
    final details = Text(
      change.call.arguments.entries
          .where((e) => e.value != null)
          .map(
            (e) =>
                '${e.key.replaceAll('_', ' ')}: ${e.value is List ? (e.value! as List).join(', ') : e.value}',
          )
          .join('\n'),
    );
    final title = agentChangeTitle(change.call.name);
    final active =
        change.status == AgentChangeStatus.review &&
        target?.request.callId == change.call.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Text(
            'Change $position/$total',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (active)
            AgentApprovalPrompt(
              pending: target!,
              title: title,
              details: details,
              onSubmit: (value) => onSubmit(target, value),
            )
          else ...[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            details,
            Semantics(
              liveRegion: true,
              child: Text(switch (change.status) {
                AgentChangeStatus.waiting ||
                AgentChangeStatus.review => 'Waiting for review',
                AgentChangeStatus.applying => 'Applying…',
                AgentChangeStatus.applied => 'Applied',
                AgentChangeStatus.declined => 'Declined',
                AgentChangeStatus.failed =>
                  'Needs checking — the action did not finish normally',
                AgentChangeStatus.interrupted =>
                  'Stopped — check any changes already made',
              }),
            ),
          ],
        ],
      ),
    );
  }
}
