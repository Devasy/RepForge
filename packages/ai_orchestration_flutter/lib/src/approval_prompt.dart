import 'package:flutter/material.dart';

import 'agent_view_state.dart';
import 'builders.dart';

class AgentApprovalPrompt extends StatefulWidget {
  final PendingAgentInput pending;
  final AgentInputSubmit onSubmit;
  final Widget details;
  final bool isSubmitting;
  final String title;
  final String approveLabel;
  final String declineLabel;
  final String failureLabel;
  final String submittingLabel;
  AgentApprovalPrompt({
    super.key,
    required this.pending,
    required this.onSubmit,
    required this.details,
    this.isSubmitting = false,
    this.title = 'Review action',
    this.approveLabel = 'Approve',
    this.declineLabel = 'Decline',
    this.failureLabel = 'The response was not accepted. Please try again.',
    this.submittingLabel = 'Submitting response',
  }) {
    if (pending.request.kind != 'tool_approval' ||
        pending.request.responseSchema.definition['type'] != 'boolean') {
      throw ArgumentError(
        'Use this widget only for boolean tool approval requests.',
      );
    }
  }
  @override
  State<AgentApprovalPrompt> createState() => _AgentApprovalPromptState();
}

class _AgentApprovalPromptState extends State<AgentApprovalPrompt> {
  bool _submitting = false;
  bool _failed = false;
  bool _accepted = false;
  bool get _busy => _submitting || _accepted || widget.isSubmitting;

  bool _sameInput(PendingAgentInput a, PendingAgentInput b) =>
      a.threadId == b.threadId &&
      a.runId == b.runId &&
      a.revision == b.revision &&
      a.request.id == b.request.id;

  @override
  void didUpdateWidget(covariant AgentApprovalPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameInput(oldWidget.pending, widget.pending)) {
      _failed = false;
      _accepted = false;
    }
  }

  Future<void> _submit(bool approved) async {
    if (_busy) return;
    final pending = widget.pending;
    setState(() {
      _submitting = true;
      _failed = false;
    });
    var accepted = false;
    try {
      accepted = await widget.onSubmit(approved);
    } catch (_) {
      accepted = false;
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (_sameInput(widget.pending, pending)) {
        _failed = !accepted;
        _accepted = accepted;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      widget.details,
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: _busy ? null : () => _submit(false),
            child: Text(widget.declineLabel),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _submit(true),
            child: Text(widget.approveLabel),
          ),
        ],
      ),
      if (_submitting || widget.isSubmitting)
        Semantics(
          label: widget.submittingLabel,
          liveRegion: true,
          child: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        ),
      if (_failed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              widget.failureLabel,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
    ],
  );
}
