import 'package:ai_orchestration_flutter/ai_orchestration_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AgentRunControls extends StatelessWidget {
  final PendingAgentInput? pending;
  final bool needsRecovery;
  final Future<bool> Function(PendingAgentInput target, Object? response)
  onSubmit;
  final Future<void> Function() onStop;
  const AgentRunControls({
    super.key,
    required this.pending,
    required this.needsRecovery,
    required this.onSubmit,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final target = pending;
    if (target?.request.kind == 'tool_approval') {
      final payload = target!.request.payload;
      final name = switch (payload['tool']) {
        'create_routine' => 'Create routine',
        'update_routine' => 'Update routine',
        'add_custom_exercise' => 'Create exercise',
        'update_exercise' => 'Update exercise',
        _ => 'Apply proposed change',
      };
      final arguments = payload['arguments']! as Map<String, Object?>;
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: SingleChildScrollView(
            child: AgentApprovalPrompt(
              pending: target,
              title: name,
              details: Text(
                arguments.entries
                    .where((entry) => entry.value != null)
                    .map(
                      (entry) =>
                          '${entry.key.replaceAll('_', ' ')}: ${entry.value}',
                    )
                    .join('\n'),
              ),
              onSubmit: (value) => onSubmit(target, value),
            ),
          ),
        ),
      );
    }
    if (needsRecovery) {
      return TextButton(
        onPressed: onStop,
        child: const Text('Stop interrupted reply'),
      );
    }
    return const SizedBox.shrink();
  }
}
