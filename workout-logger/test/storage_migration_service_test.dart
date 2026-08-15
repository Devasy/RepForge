import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/storage_service.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:repforge/services/storage_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService hiveStorage;
  late SqliteStorageService sqliteStorage;

  setUpAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == 'getApplicationDocumentsDirectory' ? './test/tmp_hive_migration_service' : null,
    );
    Hive.init('./test/tmp_hive_migration_service');
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

  test('migrate copies every entity type from Hive to SQLite', () async {
    await hiveStorage.saveWorkoutSession(WorkoutSession(
      id: 'sess1', date: DateTime(2026, 5, 1), duration: 40,
      exercises: [ExerciseLog(exerciseId: 'bench_press', sets: [WorkoutSet(weight: 70, reps: 8)])],
    ));
    await hiveStorage.saveRoutine(Routine(id: 'r1', name: 'Push Day', exerciseIds: ['bench_press']));
    await hiveStorage.saveTarget(Target(id: 't1', exerciseId: 'bench_press', targetType: 'weight', targetValue: 100));
    await hiveStorage.savePersonalRecord(PersonalRecord(
      exerciseId: 'bench_press', bestWeight: 90, bestReps: 5, bestVolume: 450, achievedAt: DateTime(2026, 4, 1),
    ));
    await hiveStorage.saveCustomExercise(Exercise(
      id: 'custom_mig', name: 'Migrated Exercise', category: 'isolation', isCustom: true,
      muscleActivations: [MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100)],
    ));
    await hiveStorage.saveConversation(Conversation(id: 'conv1', title: 'Chat', messages: []));
    await hiveStorage.saveSetting('user_name', 'Alex');
    await hiveStorage.saveTrainingProgram(TrainingProgram(
      id: 'prog1', name: 'Push Pull Legs', totalWeeks: 6, phases: const [], weeks: const [],
    ));
    // Growth rate starts at the seeded default (0); modify it on the Hive
    // side so the migrated value can be distinguished from an unmigrated one.
    await hiveStorage.updateMuscleGroupGrowthRate('chest', 0.42);

    await StorageMigrationService(hiveStorage, sqliteStorage).migrate();

    expect((await sqliteStorage.getWorkoutSession('sess1'))?.duration, 40);
    expect((await sqliteStorage.getRoutine('r1'))?.name, 'Push Day');
    expect((await sqliteStorage.getTarget('t1'))?.targetValue, 100);
    expect((await sqliteStorage.getPersonalRecord('bench_press'))?.bestWeight, 90);
    expect((await sqliteStorage.getExercise('custom_mig'))?.name, 'Migrated Exercise');
    expect((await sqliteStorage.getConversation('conv1'))?.title, 'Chat');
    expect(await sqliteStorage.getSetting('user_name'), 'Alex');
    expect((await sqliteStorage.getTrainingProgram('prog1'))?.name, 'Push Pull Legs');
    expect((await sqliteStorage.getMuscleGroup('chest'))?.growthRate, 0.42);
  });
}
