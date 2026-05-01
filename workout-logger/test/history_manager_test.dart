import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/history_manager.dart';
import 'package:repforge/services/interfaces/health_sync_manager_interface.dart';
import 'test_utils/mock_storage_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

WorkoutSession _session({
  String id = 's1',
  DateTime? date,
  List<ExerciseLog> exercises = const [],
}) =>
    WorkoutSession(
      id: id,
      date: date ?? DateTime(2026, 5, 1, 10),
      exercises: exercises,
      duration: 30,
    );

ExerciseLog _log(String exerciseId) => ExerciseLog(
      exerciseId: exerciseId,
      sets: [WorkoutSet(weight: 60, reps: 10)],
    );

// Stub that records calls
class _StubSync implements IHealthSyncManager {
  final List<WorkoutSession> synced = [];
  void Function(WorkoutSession updated)? capturedOnSynced;

  @override
  void syncSession(
    WorkoutSession session, {
    String? routineName,
    void Function(WorkoutSession updated)? onSynced,
  }) {
    synced.add(session);
    capturedOnSynced = onSynced;
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockStorageService storage;
  late HistoryManager manager;

  setUp(() {
    storage = MockStorageService();
    manager = HistoryManager(storage);
  });

  group('loadSessions', () {
    test('populates sessions from storage sorted newest-first', () async {
      final older = _session(id: 'old', date: DateTime(2026, 1, 1));
      final newer = _session(id: 'new', date: DateTime(2026, 4, 1));
      storage.addMockSession(older);
      storage.addMockSession(newer);

      await manager.loadSessions();

      expect(manager.sessions.map((s) => s.id), ['new', 'old']);
    });

    test('notifies listeners', () async {
      var notified = false;
      manager.addListener(() => notified = true);

      await manager.loadSessions();

      expect(notified, isTrue);
    });
  });

  group('addSession', () {
    test('inserts session at head and persists to storage', () async {
      final s = _session();
      await manager.addSession(s);

      expect(manager.sessions.first.id, s.id);
      expect(storage.sessions.any((x) => x.id == s.id), isTrue);
    });

    test('calls onSessionsChanged with affected exercise IDs', () async {
      Set<String>? reported;
      manager = HistoryManager(storage, onSessionsChanged: (ids) => reported = ids);

      final s = _session(exercises: [_log('bench_press'), _log('squat')]);
      await manager.addSession(s);

      expect(reported, {'bench_press', 'squat'});
    });

    test('fires HC sync when healthSyncManager is provided', () async {
      final stub = _StubSync();
      manager = HistoryManager(storage, healthSyncManager: stub);
      final s = _session();

      await manager.addSession(s, routineName: 'Push Day');

      expect(stub.synced.length, 1);
      expect(stub.synced.first.id, s.id);
    });

    test('does not fire HC sync without healthSyncManager', () async {
      // No exception and sessions list is populated — coverage of null path.
      final s = _session();
      await manager.addSession(s);
      expect(manager.sessions.length, 1);
    });
  });

  group('deleteSession', () {
    test('removes session from memory and storage', () async {
      final s = _session();
      await manager.addSession(s);

      await manager.deleteSession(s.id);

      expect(manager.sessions, isEmpty);
      expect(storage.sessions.any((x) => x.id == s.id), isFalse);
    });

    test('calls onSessionsChanged with affected exercise IDs', () async {
      Set<String>? reported;
      manager = HistoryManager(storage, onSessionsChanged: (ids) => reported = ids);

      final s = _session(exercises: [_log('deadlift')]);
      await manager.addSession(s);
      reported = null; // reset after addSession

      await manager.deleteSession(s.id);

      expect(reported, {'deadlift'});
    });

    test('is a no-op for unknown session ID', () async {
      final s = _session();
      await manager.addSession(s);

      // Should not throw
      await manager.deleteSession('does_not_exist');
      expect(manager.sessions.length, 1);
    });
  });

  group('updateSession', () {
    test('replaces session in memory and storage', () async {
      final original = _session(exercises: [_log('squat')]);
      await manager.addSession(original);

      final updated = original.copyWith(notes: 'felt strong');
      await manager.updateSession(updated);

      expect(manager.sessions.first.notes, 'felt strong');
      expect(storage.sessions.first.notes, 'felt strong');
    });

    test('preserves sort order after date change', () async {
      final s1 = _session(id: 's1', date: DateTime(2026, 3, 1));
      final s2 = _session(id: 's2', date: DateTime(2026, 4, 1));
      await manager.addSession(s1);
      await manager.addSession(s2);

      // Move s1 to be the most recent
      final movedS1 = s1.copyWith(date: DateTime(2026, 5, 1));
      await manager.updateSession(movedS1);

      expect(manager.sessions.first.id, 's1');
    });

    test('throws StateError for unknown session ID', () async {
      await expectLater(
        () => manager.updateSession(_session(id: 'ghost')),
        throwsStateError,
      );
    });
  });

  group('evictSession (cache-only, no storage I/O)', () {
    test('removes session from memory without touching storage', () async {
      final s = _session();
      storage.addMockSession(s);
      await manager.loadSessions(); // prime the cache

      manager.evictSession(s.id);

      expect(manager.sessions, isEmpty);
      // Storage still has it — evict is cache-only
      expect(storage.sessions.any((x) => x.id == s.id), isTrue);
    });

    test('notifies listeners', () async {
      final s = _session();
      await manager.addSession(s);

      var notified = false;
      manager.addListener(() => notified = true);
      manager.evictSession(s.id);

      expect(notified, isTrue);
    });

    test('is a no-op for unknown ID', () async {
      final s = _session();
      await manager.addSession(s);

      // Should not throw
      manager.evictSession('ghost');
      expect(manager.sessions.length, 1);
    });
  });

  group('patchSession (cache-only, no storage I/O)', () {
    test('updates session in memory without touching storage', () async {
      final s = _session();
      await manager.addSession(s);
      final original = storage.sessions.first.notes;

      final patched = s.copyWith(notes: 'patched');
      manager.patchSession(patched);

      expect(manager.sessions.first.notes, 'patched');
      // Storage unchanged
      expect(storage.sessions.first.notes, original);
    });

    test('notifies listeners', () async {
      final s = _session();
      await manager.addSession(s);

      var notified = false;
      manager.addListener(() => notified = true);
      manager.patchSession(s.copyWith(notes: 'x'));

      expect(notified, isTrue);
    });

    test('is a no-op for unknown ID', () async {
      final s = _session();
      await manager.addSession(s);

      // Should not throw
      manager.patchSession(_session(id: 'ghost'));
      expect(manager.sessions.length, 1);
    });

    test('maintains sort order after date patch', () async {
      final s1 = _session(id: 's1', date: DateTime(2026, 3, 1));
      final s2 = _session(id: 's2', date: DateTime(2026, 4, 1));
      await manager.addSession(s1);
      await manager.addSession(s2);
      // s2 is first (newer)
      expect(manager.sessions.first.id, 's2');

      // Patch s1 to be the newest
      manager.patchSession(s1.copyWith(date: DateTime(2026, 5, 1)));

      expect(manager.sessions.first.id, 's1');
    });
  });

  group('syncSession (manual HC trigger)', () {
    test('delegates to IHealthSyncManager', () async {
      final stub = _StubSync();
      manager = HistoryManager(storage, healthSyncManager: stub);
      final s = _session();
      await manager.addSession(s);

      manager.syncSession(s, routineName: 'Legs');

      // addSession already called syncSession once; this is the second call
      expect(stub.synced.length, 2);
      expect(stub.synced.last.id, s.id);
    });

    test('_onHcSynced patches cache and re-persists', () async {
      final stub = _StubSync();
      manager = HistoryManager(storage, healthSyncManager: stub);
      final s = _session();
      await manager.addSession(s);

      // Simulate the sync completing
      final synced = s.copyWith(hcSyncedAt: DateTime(2026, 5, 1, 12));
      stub.capturedOnSynced?.call(synced);
      // Give async storage write time to settle
      await Future<void>.delayed(Duration.zero);

      expect(manager.sessions.first.hcSyncedAt, isNotNull);
      expect(storage.sessions.first.hcSyncedAt, isNotNull);
    });
  });
}
