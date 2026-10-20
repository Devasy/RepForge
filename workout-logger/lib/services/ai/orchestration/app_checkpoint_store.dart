import 'dart:convert';

import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:ai_orchestration_sqlite/ai_orchestration_sqlite.dart';

import '../../interfaces/storage_service_interface.dart';
import '../../sqlite_storage_service.dart';

class AppCheckpointStore implements CheckpointStore {
  final IStorageService storage;
  Future<CheckpointStore>? _ready;
  AppCheckpointStore(this.storage);

  Future<CheckpointStore> _open() async {
    final source = storage;
    if (source is SqliteStorageService) {
      final store = SqliteCheckpointStore(
        source.database,
        namespace: 'repforge_ai',
      );
      await store.initialize();
      return store;
    }
    return _SettingsCheckpoints(storage);
  }

  Future<CheckpointStore> get _store async {
    final opening = _ready ??= _open();
    try {
      return await opening;
    } catch (_) {
      if (identical(_ready, opening)) _ready = null;
      rethrow;
    }
  }

  @override
  Future<RunCheckpoint?> load(String threadId) async =>
      (await _store).load(threadId);
  @override
  Future<void> save(
    RunCheckpoint checkpoint, {
    required int? expectedRevision,
  }) async =>
      (await _store).save(checkpoint, expectedRevision: expectedRevision);
}

class _SettingsCheckpoints implements CheckpointStore {
  final IStorageService storage;
  Future<void> _tail = Future.value();
  _SettingsCheckpoints(this.storage);
  String _key(String thread) => 'aiCheckpoint:$thread';
  @override
  Future<RunCheckpoint?> load(String threadId) async {
    await _tail;
    final raw = await storage.getSetting(_key(threadId));
    return raw == null || raw.isEmpty
        ? null
        : RunCheckpoint.fromJson(jsonObject(jsonDecode(raw)));
  }

  @override
  Future<void> save(
    RunCheckpoint checkpoint, {
    required int? expectedRevision,
  }) {
    final operation = _tail.then((_) async {
      final raw = await storage.getSetting(_key(checkpoint.threadId));
      final current = raw == null || raw.isEmpty
          ? null
          : RunCheckpoint.fromJson(jsonObject(jsonDecode(raw)));
      if (current?.revision != expectedRevision ||
          checkpoint.revision != (expectedRevision ?? -1) + 1) {
        throw const CheckpointConflict();
      }
      await storage.saveSetting(
        _key(checkpoint.threadId),
        jsonEncode(checkpoint.toJson()),
      );
    });
    _tail = operation.then<void>(
      (_) => null,
      onError: (Object _, StackTrace _) => null,
    );
    return operation;
  }
}
