import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUpAll(() async {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return './test/tmp_hive_storage_service';
        }
        return null;
      },
    );
    Hive.init('./test/tmp_hive_storage_service');
  });

  setUp(() async {
    storage = StorageService();
    await storage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  group('StorageService CRUD & Operations', () {
    test('init initializes default muscle groups', () async {
      final groups = await storage.getAllMuscleGroups();
      expect(groups, isNotEmpty);
      expect(groups.any((g) => g.name == 'Chest'), isTrue);
    });

    test('WorkoutSession save, get, getAll, getSessionsInDateRange, and delete', () async {
      final session1 = WorkoutSession(
        id: 's_101',
        date: DateTime(2026, 7, 10),
        duration: 45,
        exercises: [
          ExerciseLog(
            exerciseId: 'squat_id',
            sets: [WorkoutSet(weight: 100, reps: 5)],
          ),
        ],
      );

      final session2 = WorkoutSession(
        id: 's_102',
        date: DateTime(2026, 7, 15),
        duration: 60,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_id',
            sets: [WorkoutSet(weight: 80, reps: 8)],
          ),
        ],
      );

      await storage.saveWorkoutSession(session1);
      await storage.saveWorkoutSession(session2);

      final fetched1 = await storage.getWorkoutSession('s_101');
      expect(fetched1, isNotNull);
      expect(fetched1!.duration, equals(45));

      final allSessions = await storage.getAllWorkoutSessions();
      expect(allSessions.length, greaterThanOrEqualTo(2));
      // Verify most recent session first sorting
      expect(allSessions.first.date.isAfter(allSessions[1].date), isTrue);

      final forSquat = await storage.getSessionsForExercise('squat_id');
      expect(forSquat.length, equals(1));
      expect(forSquat.first.id, equals('s_101'));

      final rangeSessions = await storage.getSessionsInDateRange(
        DateTime(2026, 7, 12),
        DateTime(2026, 7, 20),
      );
      expect(rangeSessions.length, equals(1));
      expect(rangeSessions.first.id, equals('s_102'));

      await storage.deleteWorkoutSession('s_101');
      expect(await storage.getWorkoutSession('s_101'), isNull);
    });

    test('Routine CRUD', () async {
      final routine = Routine(
        id: 'r_101',
        name: 'Push Pull Legs - Push',
        exerciseIds: ['ex_bench', 'ex_ohp'],
      );

      await storage.saveRoutine(routine);

      final fetched = await storage.getRoutine('r_101');
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Push Pull Legs - Push'));

      final allRoutines = await storage.getAllRoutines();
      expect(allRoutines.any((r) => r.id == 'r_101'), isTrue);

      await storage.deleteRoutine('r_101');
      expect(await storage.getRoutine('r_101'), isNull);
    });

    test('Target CRUD and getTargetsForExercise', () async {
      final target = Target(
        id: 't_101',
        exerciseId: 'ex_bench',
        targetValue: 100.0,
        targetType: 'weight',
      );

      await storage.saveTarget(target);

      final fetched = await storage.getTarget('t_101');
      expect(fetched, isNotNull);
      expect(fetched!.targetValue, equals(100.0));

      final targetsForBench = await storage.getTargetsForExercise('ex_bench');
      expect(targetsForBench.length, equals(1));
      expect(targetsForBench.first.id, equals('t_101'));

      await storage.deleteTarget('t_101');
      expect(await storage.getTarget('t_101'), isNull);
    });

    test('Custom Exercise save, getAllExercises, getExercise, delete', () async {
      final customEx = Exercise(
        id: 'custom_ex_999',
        name: 'Bulgarian Split Squat Special',
        category: 'compound',
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'quadriceps', activationPercentage: 100),
        ],
        isCustom: true,
      );

      await storage.saveCustomExercise(customEx);

      final customList = await storage.getCustomExercises();
      expect(customList.any((e) => e.id == 'custom_ex_999'), isTrue);

      final allExercises = await storage.getAllExercises();
      expect(allExercises.any((e) => e.id == 'custom_ex_999'), isTrue);

      final fetched = await storage.getExercise('custom_ex_999');
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Bulgarian Split Squat Special'));

      await storage.deleteCustomExercise('custom_ex_999');
      expect(await storage.getCustomExercises().then((l) => l.any((e) => e.id == 'custom_ex_999')), isFalse);
    });

    test('Export and import data payload', () async {
      await storage.saveSetting('test_setting_key', 'test_val');

      final exportJsonStr = await storage.exportAllData();
      expect(exportJsonStr, isNotEmpty);

      final exportedMap = jsonDecode(exportJsonStr) as Map<String, dynamic>;
      expect(exportedMap.containsKey('settings'), isTrue);
      expect(exportedMap.containsKey('exportDate'), isTrue);

      // Re-import payload
      await storage.importData(exportJsonStr);
      final val = await storage.getSetting('test_setting_key');
      expect(val, equals('test_val'));
    });

    test('getAllSettingsForMigration returns every saved key/value', () async {
      await storage.saveSetting('mig_key_1', 'value_1');
      await storage.saveSetting('mig_key_2', 'value_2');

      final all = await storage.getAllSettingsForMigration();

      expect(all['mig_key_1'], 'value_1');
      expect(all['mig_key_2'], 'value_2');
    });
  });
}
