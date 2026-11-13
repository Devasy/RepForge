import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/data/exercise_database.dart';
import 'package:repforge/services/extended_exercise_library.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_utils/mock_ml_service.dart';

void main() {
  late Directory directory;
  late SqliteStorageService storage;
  final json = File('../catalogues/fitify-v1.json').readAsStringSync();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('repforge-library-');
    storage = SqliteStorageService(
      databasePathOverride: '${directory.path}/test.db',
    );
    await storage.init();
  });
  tearDown(() async {
    await storage.close();
    await directory.delete(recursive: true);
  });

  test(
    'download validates HTTP status, size, format and source before accepting data',
    () async {
      final valid = MockClient((request) async {
        expect(request.url, ExtendedExerciseLibrary.downloadUri);
        return http.Response(
          json,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      expect(await ExtendedExerciseLibrary.download(client: valid), json);
      await expectLater(
        ExtendedExerciseLibrary.download(
          client: MockClient((_) async => http.Response('missing', 404)),
        ),
        throwsStateError,
      );
      await expectLater(
        ExtendedExerciseLibrary.download(
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
        throwsFormatException,
      );
      await expectLater(
        ExtendedExerciseLibrary.download(
          client: MockClient(
            (_) async => http.Response(
              'x' * (ExtendedExerciseLibrary.maxBytes + 1),
              200,
            ),
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'cached download survives restart, preserves edits and restores through backup',
    () async {
      final provider = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await provider.init();
      expect(provider.hasExtendedLibrary, isFalse);
      final original = provider.getExercise('bench_press')!;
      await provider.loadExtendedLibrary(json);
      expect(provider.allExercises, hasLength(949));
      expect(provider.getExercise('bench_press')!.toJson(), original.toJson());
      await provider.updateExercise(
        id: 'fitify:yo003_boat',
        name: 'My boat hold',
      );
      await provider.loadExtendedLibrary(json);
      expect(provider.allExercises, hasLength(949));
      expect(provider.getExercise('fitify:yo003_boat')!.name, 'My boat hold');
      expect(
        (await storage.getExercise('fitify:yo003_boat'))!.name,
        'My boat hold',
      );
      await expectLater(
        provider.loadExtendedLibrary('{}'),
        throwsFormatException,
      );
      expect(
        await storage.getSetting(ExtendedExerciseLibrary.settingKey),
        json,
      );
      final backup = await storage.exportAllData();
      final path = storage.databasePath;
      await storage.close();
      storage = SqliteStorageService(databasePathOverride: path);
      await storage.init();
      final reopened = await storage.getAllExercises();
      expect(reopened, hasLength(949));
      expect(
        reopened.singleWhere((e) => e.id == 'fitify:yo003_boat').name,
        'My boat hold',
      );
      final restored = SqliteStorageService(
        databasePathOverride: '${directory.path}/restored.db',
      );
      await restored.init();
      try {
        await restored.importData(backup);
        expect(await restored.getAllExercises(), hasLength(949));
        expect(
          (await restored.getExercise('fitify:yo003_boat'))!.name,
          'My boat hold',
        );
        expect(
          (await restored.getAllMuscleGroups()).map((g) => g.id),
          containsAll(['abs', 'obliques', 'neck_front', 'adductors']),
        );
      } finally {
        await restored.close();
      }
      provider.dispose();
    },
  );

  test('adding new muscle groups preserves existing learned rates', () async {
    await storage.updateMuscleGroupGrowthRate('chest', 1.25);
    final path = storage.databasePath;
    await storage.close();
    storage = SqliteStorageService(databasePathOverride: path);
    await storage.init();
    expect((await storage.getMuscleGroup('chest'))!.growthRate, 1.25);
    expect(
      await storage.getAllMuscleGroups(),
      hasLength(MuscleGroups.getAll().length),
    );
  });
}
