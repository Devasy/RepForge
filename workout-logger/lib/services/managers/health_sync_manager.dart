// Health Sync Manager (Single Responsibility Principle)
//
// Responsible ONLY for orchestrating Health Connect sync after a workout session
// is saved. It:
// - Checks the user's HC-enabled setting via SettingsProvider (in-memory, sync).
// - Calls IHealthConnectService.syncWorkoutSession in a fire-and-forget pattern.
// - On success, invokes the optional onSynced callback with the updated session.
// - Swallows all errors so callers are never affected.

import 'package:flutter/foundation.dart' show debugPrint;

import '../../models/models.dart';
import '../interfaces/health_connect_service_interface.dart';
import '../interfaces/health_sync_manager_interface.dart';
import '../settings_provider.dart';

/// Orchestrates Health Connect sync after a workout session is saved.
///
/// Following Single Responsibility Principle: this class only manages
/// the HC sync concern. History persistence and active workout state
/// are handled by other managers.
class HealthSyncManager implements IHealthSyncManager {
  final IHealthConnectService _hc;
  final SettingsProvider _settings;

  HealthSyncManager(this._hc, this._settings);

  @override
  void syncSession(
    WorkoutSession session, {
    String? routineName,
    void Function(WorkoutSession updated)? onSynced,
  }) {
    // Synchronous in-memory flag check — no I/O, no await.
    if (!_settings.healthConnectEnabled) return;

    _hc
        .syncWorkoutSession(session, title: routineName)
        .then((success) {
          if (success) {
            onSynced?.call(session.copyWith(hcSyncedAt: DateTime.now()));
          }
        })
        .catchError((Object e) {
          debugPrint('HealthSyncManager: sync error: $e');
        });
  }
}
