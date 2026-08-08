// Decides which storage backend the app should use: SQLite if already
// migrated, otherwise runs the one-time migration and falls back to Hive
// on any failure. Pure decision logic, factored out of main.dart's
// _resolveStorageBackend so it's directly testable without booting Flutter.

import 'package:flutter/foundation.dart';

import 'interfaces/storage_service_interface.dart';
import 'storage_service.dart';
import 'sqlite_storage_service.dart';
import 'storage_migration_service.dart';

const storageMigratedFlagKey = 'storage_migrated_v1';

/// Given the already-initialized Hive and SQLite storage instances and
/// whether the migration flag was already set, decides which backend to
/// use — running the one-time migration and writing the flag on success,
/// or falling back to Hive on any failure. Does not call init() on either
/// argument; the caller is responsible for that.
Future<IStorageService> resolveStorageBackend({
  required StorageService hiveStorage,
  required SqliteStorageService sqliteStorage,
  required bool alreadyMigrated,
}) async {
  if (alreadyMigrated) {
    return sqliteStorage;
  }

  try {
    await StorageMigrationService(hiveStorage, sqliteStorage).migrate();
    await hiveStorage.saveSetting(storageMigratedFlagKey, 'true');
    return sqliteStorage;
  } catch (e, st) {
    debugPrint('Storage migration to SQLite failed, staying on Hive: $e\n$st');
    return hiveStorage;
  }
}
