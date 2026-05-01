// Unit tests for HealthSyncManager


import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/managers/health_sync_manager.dart';
import 'package:repforge/services/settings_provider.dart';
import 'test_utils/mock_storage_service.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockHcService implements IHealthConnectService {
  int syncCallCount = 0;
  WorkoutSession? lastSession;
  String? lastTitle;
  bool returnValue;
  bool shouldThrow;

  _MockHcService({this.returnValue = true, this.shouldThrow = false});

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> hasPermissions() async => true;

  @override
  Future<bool> syncWorkoutSession(
    WorkoutSession session, {
    String? title,
  }) async {
    if (shouldThrow) throw Exception('mock HC error');
    syncCallCount++;
    lastSession = session;
    lastTitle = title;
    return returnValue;
  }
}

WorkoutSession _makeSession({String id = 'session_1'}) => WorkoutSession(
  id: id,
  date: DateTime(2026, 5, 1, 10),
  exercises: [],
  duration: 45,
);

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('HealthSyncManager', () {
    late MockStorageService storage;
    late SettingsProvider settings;
    late _MockHcService hc;

    setUp(() async {
      storage = MockStorageService();
      settings = SettingsProvider(storage);
      await settings.init(); // healthConnectEnabled defaults to false
      hc = _MockHcService();
    });

    test('does nothing when healthConnectEnabled is false', () async {
      final manager = HealthSyncManager(hc, settings);
      manager.syncSession(_makeSession());

      // Give the async chain time to settle
      await Future<void>.delayed(Duration.zero);

      expect(hc.syncCallCount, 0);
    });

    test('calls syncWorkoutSession when enabled', () async {
      await settings.setHealthConnectEnabled(true);
      final manager = HealthSyncManager(hc, settings);
      final session = _makeSession();

      manager.syncSession(session, routineName: 'Push Day');
      await Future<void>.delayed(Duration.zero);

      expect(hc.syncCallCount, 1);
      expect(hc.lastSession?.id, session.id);
      expect(hc.lastTitle, 'Push Day');
    });

    test('calls onSynced with updated session when sync succeeds', () async {
      await settings.setHealthConnectEnabled(true);
      hc = _MockHcService(returnValue: true);
      final manager = HealthSyncManager(hc, settings);

      WorkoutSession? syncedSession;
      manager.syncSession(
        _makeSession(),
        onSynced: (s) => syncedSession = s,
      );
      await Future<void>.delayed(Duration.zero);

      expect(syncedSession, isNotNull);
      expect(syncedSession!.hcSyncedAt, isNotNull);
    });

    test('does NOT call onSynced when sync returns false', () async {
      await settings.setHealthConnectEnabled(true);
      hc = _MockHcService(returnValue: false);
      final manager = HealthSyncManager(hc, settings);

      WorkoutSession? syncedSession;
      manager.syncSession(
        _makeSession(),
        onSynced: (s) => syncedSession = s,
      );
      await Future<void>.delayed(Duration.zero);

      expect(syncedSession, isNull);
    });

    test('does not rethrow when HC throws', () async {
      await settings.setHealthConnectEnabled(true);
      hc = _MockHcService(shouldThrow: true);
      final manager = HealthSyncManager(hc, settings);

      // Must complete without throwing — just run and let test fail on exception.
      manager.syncSession(_makeSession());
      await Future<void>.delayed(Duration.zero);
      // If we reach here, no exception propagated.
    });
  });
}
