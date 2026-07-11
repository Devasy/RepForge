// agent_event_mapper.dart — Maps AgentEvents to UI-specific display models.
//
// Provides backward compatibility between the old AgentChartData events
// and the new AgentArtifactReady(ChartArtifact) events. Also centralizes
// event-to-UI-state mapping that was duplicated across ViewModels.

import '../agent_event.dart';
import '../runtime/agent_artifact.dart';

/// Utility class for mapping agent events to UI state.
class AgentEventMapper {
  const AgentEventMapper._();

  /// Extract chart spec data from either an AgentChartData or
  /// AgentArtifactReady(ChartArtifact) event. Returns null if the event
  /// is not chart-related.
  static Map<String, Object?>? extractChartSpec(AgentEvent event) {
    switch (event) {
      case AgentChartData(:final chartSpec):
        return chartSpec;
      case AgentArtifactReady(:final artifact):
        if (artifact is ChartArtifact) return artifact.spec;
        return null;
      default:
        return null;
    }
  }

  /// Whether an event is a terminal event (run complete or error).
  static bool isTerminal(AgentEvent event) {
    return event is AgentError || event is AgentTraceEvent;
  }
}
