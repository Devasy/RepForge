// tool_metadata.dart — Rich metadata for agent tools.
//
// Each tool carries metadata that the runtime, UI, and tracing system
// use to decide how to display, route, and log tool activity.

import '../runtime/agent_artifact.dart';

/// Classification of what a tool does.
enum ToolKind {
  /// Read-only data query (e.g. get_exercise_performance).
  query,

  /// Data mutation (e.g. create_routine, update_routine).
  mutation,

  /// UI output (e.g. show_graph — produces an artifact for display).
  ui,

  /// Requires human input before the run can continue.
  interrupt,

  /// Analytics / telemetry (future).
  analytics,
}

/// Describes a tool's identity, classification, and display properties.
class ToolMetadata {
  /// Human-readable name shown in the UI (e.g. 'Bench Press performance').
  final String displayName;

  /// What kind of tool this is.
  final ToolKind kind;

  /// Whether the tool only reads data (true) or mutates state (false).
  final bool readOnly;

  /// Optional progress label template shown while the tool is running.
  /// May contain `{arg}` placeholders filled from tool args at runtime.
  final String? progressLabel;

  /// If this tool produces a typed artifact, what kind.
  final AgentArtifactKind? outputKind;

  const ToolMetadata({
    required this.displayName,
    required this.kind,
    required this.readOnly,
    this.progressLabel,
    this.outputKind,
  });

  @override
  String toString() => 'ToolMetadata($displayName, $kind)';
}
