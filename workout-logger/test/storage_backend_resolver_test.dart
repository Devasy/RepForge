import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/storage_service.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/storage_backend_resolver.dart';

/// Forces the migration to fail without adding new production API surface —
/// [SqliteStorageService.saveWorkoutSession] is the first write
/// [StorageMigrationService.migrate] performs against a seeded hiveStorage.
class _FailingSqliteStorage extends SqliteStorageService {
  _FailingSqliteStorage() : super(databasePathOverride: inMemoryDatabasePath);

  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async =>
      throw StateError('forced migration failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService hiveStorage;
  late SqliteStorageService sqliteStorage;

  setUpAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == 'getApplicationDocumentsDirectory' ? './test/tmp_hive_backend_resolver' : null,
    );
    Hive.init('./test/tmp_hive_backend_resolver');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    hiveStorage = StorageService();
    await hiveStorage.init();
    sqliteStorage = SqliteStorageService(databasePathOverride: inMemoryDatabasePath);
    await sqliteStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  // Runs before the "migration succeeds" test below, which writes the
  // migrated flag onto the same on-disk Hive box — this assertion needs the
  // flag to still be unset.
  test('alreadyMigrated false, migration fails, falls back to hive and writes no flag',
      () async {
    // migrate() only reaches saveWorkoutSession if there's a session to
    // migrate — seed one so the forced failure actually triggers.
    await hiveStorage.saveWorkoutSession(WorkoutSession(
      id: 'fail1', date: DateTime(2026, 5, 1), duration: 10, exercises: const [],
    ));
    final failing = _FailingSqliteStorage();
    await failing.init();
    addTearDown(failing.close);

    final result = await resolveStorageBackend(
      hiveStorage: hiveStorage,
      sqliteStorage: failing,
      alreadyMigrated: false,
    );

    expect(result, same(hiveStorage));
    expect(await hiveStorage.getSetting(storageMigratedFlagKey), isNull);
  });

  test('alreadyMigrated true returns sqlite without touching migration', () async {
    final result = await resolveStorageBackend(
      hiveStorage: hiveStorage,
      sqliteStorage: sqliteStorage,
      alreadyMigrated: true,
    );
    expect(result, same(sqliteStorage));
  });

  test('alreadyMigrated false, migration succeeds, returns sqlite and writes flag', () async {
    final result = await resolveStorageBackend(
      hiveStorage: hiveStorage,
      sqliteStorage: sqliteStorage,
      alreadyMigrated: false,
    );
    expect(result, same(sqliteStorage));
    expect(await hiveStorage.getSetting(storageMigratedFlagKey), 'true');
  });
}
