import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/exercise_media_store.dart';
import 'package:repforge/services/interfaces/storage_service_interface.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/storage_service.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_utils/mock_storage_service.dart';

final gif = base64Decode(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
);

class _FailingStorage extends MockStorageService {
  @override
  Future<void> saveCustomExercise(Exercise exercise) async =>
      throw StateError('disk full');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final originalStore = ExerciseMediaStore.instance;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'repforge-media-persistence-',
    );
    ExerciseMediaStore.instance = ExerciseMediaStore(
      directory: Directory('${directory.path}/media'),
    );
    Hive.init('${directory.path}/hive');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => '${directory.path}/hive',
        );
  });
  tearDown(() async {
    await Hive.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    ExerciseMediaStore.instance = originalStore;
    await directory.delete(recursive: true);
  });

  for (final backend in ['SQLite', 'Hive']) {
    test(
      '$backend persists media for custom exercises and built-in overrides',
      () async {
        final IStorageService storage;
        if (backend == 'SQLite') {
          final sqlite = SqliteStorageService(
            databasePathOverride: '${directory.path}/source.db',
          );
          await sqlite.init();
          storage = sqlite;
          addTearDown(sqlite.close);
        } else {
          final hive = StorageService();
          await hive.init();
          storage = hive;
        }
        final media = await ExerciseMediaStore.instance.importImage(gif);
        final builtin = ExerciseDatabase.getById(
          'bench_press',
        )!.copyWith(media: [media]);
        final custom = builtin.copyWith(
          id: 'custom_media',
          isCustom: true,
          name: 'My press',
        );
        await storage.saveCustomExercise(builtin);
        await storage.saveCustomExercise(custom);
        expect(
          (await storage.getExercise('bench_press'))!.media.single.fileName,
          media.fileName,
        );
        expect(
          (await storage.getAllExercises())
              .where((e) => e.id == 'bench_press')
              .length,
          1,
        );
        expect(
          (await storage.getExercise('custom_media'))!.media.single.kind,
          ExerciseMediaKind.gif,
        );
        final backup = await storage.exportAllData();
        expect(jsonDecode(backup)['backupFormatVersion'], 2);
        expect(backup, isNot(contains(directory.path)));
        final newStore = ExerciseMediaStore(
          directory: Directory('${directory.path}/restored-media'),
        );
        ExerciseMediaStore.instance = newStore;
        final restored = SqliteStorageService(
          databasePathOverride: '${directory.path}/restored.db',
        );
        await restored.init();
        addTearDown(restored.close);
        await restored.importData(backup);
        expect(
          (await restored.getExercise('bench_press'))!.media.single.fileName,
          media.fileName,
        );
        expect(
          (await restored.getExercise('custom_media'))!.media.single.fileName,
          media.fileName,
        );
        expect(await (await newStore.fileFor(media)).readAsBytes(), gif);
        await restored.saveCustomExercise(
          custom.copyWith(name: 'Local edit', media: []),
        );
        await restored.importData(backup);
        expect((await restored.getExercise(custom.id))!.name, 'Local edit');
        expect((await restored.getExercise(custom.id))!.media, isEmpty);
      },
    );

    test(
      '$backend validates corrupt media before any records are imported',
      () async {
        final IStorageService storage;
        if (backend == 'SQLite') {
          final sqlite = SqliteStorageService(
            databasePathOverride: '${directory.path}/source.db',
          );
          await sqlite.init();
          storage = sqlite;
          addTearDown(sqlite.close);
        } else {
          final hive = StorageService();
          await hive.init();
          storage = hive;
        }
        final media = await ExerciseMediaStore.instance.importImage(gif);
        final custom = ExerciseDatabase.getById(
          'bench_press',
        )!.copyWith(id: 'custom_bad', isCustom: true, media: [media]);
        final payload = {
          'backupFormatVersion': 2,
          'customExercises': [custom.toJson()],
          'exerciseMedia': {media.fileName: 'AA=='},
        };
        await expectLater(
          storage.importData(jsonEncode(payload)),
          throwsFormatException,
        );
        expect(await storage.getExercise(custom.id), isNull);
      },
    );
  }

  test(
    'v6 to v7 migration preserves exercises and defaults media to empty',
    () async {
      final path = '${directory.path}/legacy.db';
      final initial = SqliteStorageService(databasePathOverride: path);
      await initial.init();
      await initial.saveCustomExercise(
        ExerciseDatabase.getById('bench_press')!.copyWith(name: 'My bench'),
      );
      await initial.close();
      final legacy = await databaseFactory.openDatabase(path);
      await legacy.execute('ALTER TABLE exercises DROP COLUMN media_json');
      await legacy.setVersion(6);
      await legacy.close();
      final upgraded = SqliteStorageService(databasePathOverride: path);
      await upgraded.init();
      addTearDown(upgraded.close);
      final exercise = await upgraded.getExercise('bench_press');
      expect(exercise!.name, 'My bench');
      expect(exercise.media, isEmpty);
    },
  );

  test('failed media save leaves provider exercise unchanged', () async {
    final storage = _FailingStorage();
    final provider = WorkoutProvider(
      storage,
      programManager: ProgramManager(storage),
    );
    await provider.init();
    final media = await ExerciseMediaStore.instance.importImage(gif);
    await expectLater(
      provider.updateExercise(id: 'bench_press', media: [media]),
      throwsStateError,
    );
    expect(provider.getExercise('bench_press')!.media, isEmpty);
  });

  test(
    'provider preserves media for ordinary edits and allows explicit removal',
    () async {
      final storage = MockStorageService();
      final provider = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await provider.init();
      final media = await ExerciseMediaStore.instance.importImage(gif);
      await provider.updateExercise(id: 'bench_press', media: [media]);
      await provider.updateExercise(id: 'bench_press', name: 'My bench');
      expect(
        provider.getExercise('bench_press')!.media.single.fileName,
        media.fileName,
      );
      await provider.updateExercise(id: 'bench_press', media: []);
      expect(provider.getExercise('bench_press')!.media, isEmpty);
      await expectLater(
        provider.updateExercise(
          id: 'bench_press',
          media: List.filled(5, media),
        ),
        throwsArgumentError,
      );
    },
  );
}
