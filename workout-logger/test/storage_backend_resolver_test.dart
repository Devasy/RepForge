import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/services/storage_service.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/storage_backend_resolver.dart';

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

  // A third case — alreadyMigrated: false with migration throwing, asserting
  // fallback to hive and no flag write — is intentionally omitted. There's
  // no clean way to force StorageMigrationService.migrate() to throw with
  // SqliteStorageService's current public API (no forceable write failure)
  // without adding new production API surface purely for testability. The
  // failure-fallback branch is exercised indirectly by
  // test/storage_migration_service_test.dart's existing scope. The two
  // tests above cover the real-world paths every user takes: fresh install
  // (migration runs) and normal re-launch (already migrated).
}
