// Health Sync Manager Interface (Dependency Inversion Principle)
//
// Abstracts the orchestration of Health Connect sync after a session is saved.
// WorkoutProvider and HistoryManager depend on this abstraction, not the
// concrete HealthSyncManager, so the sync implementation can be swapped or
// mocked in tests without touching callers.

import '../../models/models.dart';

/// Contract for post-session Health Connect sync orchestration.
abstract class IHealthSyncManager {
  /// Schedules a best-effort HC sync for [session].
  ///
  /// - [routineName] is forwarded as the HC exercise session title.
  /// - [onSynced] is called with the updated session (hcSyncedAt set) if the
  ///   sync succeeds. It is never called on failure.
  /// - This method is fire-and-forget: it never throws and does not block.
  void syncSession(
    WorkoutSession session, {
    String? routineName,
    void Function(WorkoutSession updated)? onSynced,
  });
}
