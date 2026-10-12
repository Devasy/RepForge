import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late Directory testDirectory;

  setUpAll(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'repforge-hive-test-',
    );
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return testDirectory.path;
          }
          return null;
        });
    Hive.init(testDirectory.path);
  });

  setUp(() async {
    storage = StorageService();
    await storage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('initialization migrates composite PR keys without losing attachments', () async {
    final box = Hive.box<String>('personal_records');
    for (final handle in ['migration-rope', 'migration-bar']) {
      await box.put('cable_curl:$handle', jsonEncode({'exerciseId': 'cable_curl:$handle', 'bestWeight': 50, 'bestReps': 8, 'bestVolume': 400, 'achievedAt': '2026-01-01'}));
    }
    await StorageService().init();
    expect(box.containsKey('cable_curl:migration-rope'), isFalse);
    final records = (await storage.getAllPersonalRecords()).where((r) => r.handle?.startsWith('migration-') ?? false).toList();
    expect(records, hasLength(2));
    expect(records.every((r) => r.exerciseId == 'cable_curl' && r.bestWeight == 50), isTrue);
  });

  group('StorageService CRUD & Operations', () {
    test('init initializes default muscle groups', () async {
      final groups = await storage.getAllMuscleGroups();
      expect(groups, isNotEmpty);
      expect(groups.any((g) => g.name == 'Chest'), isTrue);
    });

    test(
      'WorkoutSession save, get, getAll, getSessionsInDateRange, and delete',
      () async {
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
      },
    );

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

    test(
      'Custom Exercise save, getAllExercises, getExercise, delete',
      () async {
        final customEx = Exercise(
          id: 'custom_ex_999',
          name: 'Bulgarian Split Squat Special',
          category: 'compound',
          muscleActivations: [
            MuscleActivation(
              muscleGroupId: 'quadriceps',
              activationPercentage: 100,
            ),
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
        expect(
          await storage.getCustomExercises().then(
            (l) => l.any((e) => e.id == 'custom_ex_999'),
          ),
          isFalse,
        );
      },
    );

    test(
      'backup restores each PR handle and measurement convention independently',
      () async {
        final id = 'backup-variant-exercise';
        for (final handle in ['Rope', 'Bar']) {
          for (final version in [0, 1]) {
            await storage.savePersonalRecord(
              PersonalRecord(
                exerciseId: id,
                handle: handle,
                loadEncodingVersion: version,
                bestWeight: 50 + version.toDouble(),
                bestReps: 8,
                bestVolume: 400,
                achievedAt: DateTime(2026, 1, 1),
              ),
            );
          }
        }
        final backup =
            jsonDecode(await storage.exportAllData()) as Map<String, dynamic>;
        final records = (backup['personalRecords'] as List)
            .where((r) => r['exerciseId'] == id)
            .toList();
        expect(records, hasLength(4));
        for (final record in records) {
          record['exerciseId'] = 'restored-variant-exercise';
        }
        final weighted = WorkoutSet(
          weight: 10,
          reps: 5,
          loadMode: WorkoutLoadMode.weighted,
          bodyWeightAtLog: 70,
        );
        await storage.importData(
          jsonEncode({
            'personalRecords': records,
            'sessions': [
              WorkoutSession(
                id: 'weighted-import',
                date: DateTime(2026, 1, 1),
                duration: 20,
                exercises: [
                  ExerciseLog(exerciseId: 'push_ups', sets: [weighted]),
                ],
              ).toJson(),
            ],
          }),
        );
        await storage.importData(jsonEncode({'personalRecords': records}));
        expect(
          (await storage.getAllPersonalRecords()).where(
            (r) => r.exerciseId == 'restored-variant-exercise',
          ),
          hasLength(4),
        );
        final restored = (await storage.getWorkoutSession(
          'weighted-import',
        ))!.exercises.single.sets.single;
        expect(restored.loadMode, WorkoutLoadMode.weighted);
        expect(restored.loadEncodingVersion, 1);
        expect(restored.volume, 400);
      },
    );

    test('backup preserves session effort and modern set fields', () async {
      final session = WorkoutSession(
        id: 'backup-modern-session',
        date: DateTime(2026, 1, 1),
        duration: 30,
        sessionEffort: 2,
        exercises: [
          ExerciseLog(
            exerciseId: 'pull_ups',
            handle: 'Rope',
            sets: [
              WorkoutSet(
                weight: 10,
                reps: 5,
                assistWeight: 10,
                extraWeight: 2,
                bodyWeightAtLog: 70,
                handle: 'Rope',
                timeTaken: 30,
                isDropset: true,
                drops: [DropsetEntry(id: 'drop', weight: 5, reps: 3)],
              ),
            ],
          ),
        ],
      );
      await storage.saveWorkoutSession(session);
      final exported =
          jsonDecode(await storage.exportAllData()) as Map<String, dynamic>;
      final row = (exported['sessions'] as List).firstWhere(
        (s) => s['id'] == session.id,
      );
      expect(row['sessionEffort'], 2);
      row['id'] = 'restored-modern-session';
      await storage.importData(
        jsonEncode({
          'sessions': [row],
        }),
      );
      final restored = (await storage.getWorkoutSession(
        'restored-modern-session',
      ))!.toJson();
      final expected = session.toJson()..['id'] = 'restored-modern-session';
      expect(restored, expected);
    });

    test(
      'invalid later records are rejected before any merge writes',
      () async {
        await expectLater(
          storage.importData(
            jsonEncode({
              'sessions': [
                {
                  'id': 'must-not-import',
                  'date': '2026-01-01T00:00:00.000',
                  'duration': 10,
                  'exercises': [],
                },
              ],
              'conversations': [{}],
            }),
          ),
          throwsA(isA<Error>()),
        );
        expect(await storage.getWorkoutSession('must-not-import'), isNull);
      },
    );
    test(
      'legacy JSON-string rows import and future formats are rejected',
      () async {
        await storage.importData(
          jsonEncode({
            'sessions': [
              jsonEncode({
                'id': 'legacy-backup',
                'date': '2026-01-01T00:00:00.000',
                'duration': 10,
                'exercises': [],
              }),
            ],
          }),
        );
        expect(await storage.getWorkoutSession('legacy-backup'), isNotNull);
        await expectLater(
          storage.importData(
            jsonEncode({'backupFormatVersion': 2, 'sessions': []}),
          ),
          throwsFormatException,
        );
      },
    );

    test(
      'backup restores programs, records and both chat kinds with attachments',
      () async {
        final program = TrainingProgram(
          id: 'backup-program',
          name: 'Strength',
          totalWeeks: 4,
          phases: [],
          weeks: [],
        );
        final record = PersonalRecord(
          exerciseId: 'backup-exercise',
          bestWeight: 90,
          bestReps: 5,
          bestVolume: 450,
          achievedAt: DateTime(2026, 1, 1),
        );
        final conversations = [
          for (final kind in ['coach', 'optimizer'])
            Conversation(
              id: 'backup-$kind',
              title: kind,
              kind: kind,
              messages: [
                ChatMessage(
                  role: 'model',
                  text:
                      '{"component":"StatCard","props":{"title":"Volume","value":"12k"}}',
                  toolCalls: ['get_personal_records'],
                  imageBytesBase64: 'aGVsbG8=',
                  imageMimeType: 'image/png',
                ),
              ],
            ),
        ];
        await storage.saveTrainingProgram(program);
        await storage.savePersonalRecord(record);
        for (final conversation in conversations) {
          await storage.saveConversation(conversation);
        }
        final exported =
            jsonDecode(await storage.exportAllData()) as Map<String, dynamic>;
        expect(exported['backupFormatVersion'], 1);
        // Use fresh identifiers so the merge actually restores data.
        (exported['trainingPrograms'] as List).first['id'] = 'restored-program';
        (exported['personalRecords'] as List).first['exerciseId'] =
            'restored-exercise';
        for (final chat in exported['conversations'] as List) {
          chat['id'] = 'restored-${chat['id']}';
        }
        await storage.importData(jsonEncode(exported));
        expect(
          (await storage.getTrainingProgram('restored-program'))!.name,
          program.name,
        );
        expect(
          (await storage.getPersonalRecord('restored-exercise'))!.bestWeight,
          90,
        );
        for (final original in conversations) {
          final restored = await storage.getConversation(
            'restored-${original.id}',
          );
          expect(restored!.kind, original.kind);
          expect(
            restored.messages.single.toJson(),
            original.messages.single.toJson(),
          );
        }
        // Reimport preserves existing records and does not duplicate chats.
        await storage.importData(jsonEncode(exported));
        expect(
          (await storage.getAllConversations())
              .where((c) => c.id.startsWith('restored-'))
              .length,
          2,
        );
      },
    );

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
