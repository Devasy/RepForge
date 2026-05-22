// Agent Intent Bridge
//
// Bridges Android AppFunction write invocations into the Flutter UI. The
// native layer either launches the app cold with the proposed write as intent
// extras (drained here via [fetchPending]) or pushes a write into an already
// running app through the `presentAgentAction` method call.

import 'package:flutter/services.dart';

import 'agent_action.dart';

/// Receives proposed agent writes from the native Android layer.
class AgentIntentBridge {
  static const MethodChannel channel = MethodChannel('repforge/agent');

  final void Function(AgentPendingAction action) onAction;

  AgentIntentBridge({required this.onAction});

  /// Start listening for writes pushed into a running app and drain any write
  /// delivered via the launch intent.
  Future<void> start() async {
    channel.setMethodCallHandler(_handle);
    await fetchPending();
  }

  Future<dynamic> _handle(MethodCall call) async {
    if (call.method == 'presentAgentAction') {
      final action = AgentPendingAction.tryParse(call.arguments as String?);
      if (action != null) onAction(action);
    }
    return null;
  }

  /// Ask the native layer for a write delivered via the cold-start intent.
  Future<void> fetchPending() async {
    try {
      final raw = await channel.invokeMethod<String>('getPendingAgentAction');
      final action = AgentPendingAction.tryParse(raw);
      if (action != null) onAction(action);
    } on MissingPluginException {
      // Native AppFunctions layer absent (Phase 1 / non-Android) — no-op.
    } catch (_) {
      // No pending action, or the native side reported an error — ignore.
    }
  }
}
