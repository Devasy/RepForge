import 'package:flutter/widgets.dart';

import 'agent_controller.dart';
import 'agent_view_state.dart';

typedef AgentViewBuilder<S> =
    Widget Function(BuildContext context, AgentViewState<S> state);
typedef AgentInputSubmit = Future<bool> Function(Object? response);
typedef AgentInputWidgetBuilder =
    Widget Function(
      BuildContext context,
      PendingAgentInput pending,
      AgentInputSubmit submit,
      bool isSubmitting,
    );

class AgentRunBuilder<S> extends StatelessWidget {
  final AgentController<S> controller;
  final AgentViewBuilder<S> builder;
  const AgentRunBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<AgentViewState<S>>(
        valueListenable: controller,
        builder: (context, state, _) => builder(context, state),
      );
}

class AgentInputBuilder<S> extends StatelessWidget {
  final AgentController<S> controller;
  final AgentInputWidgetBuilder builder;
  final AgentViewBuilder<S>? whenIdle;
  const AgentInputBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.whenIdle,
  });
  @override
  Widget build(BuildContext context) => AgentRunBuilder<S>(
    controller: controller,
    builder: (context, state) {
      final pending = state.pendingInput;
      if (pending == null) {
        return whenIdle?.call(context, state) ?? const SizedBox.shrink();
      }
      return builder(
        context,
        pending,
        (response) => controller.isDisposed
            ? Future.value(false)
            : controller.submitInput(pending, response),
        state.isCommandPending,
      );
    },
  );
}
