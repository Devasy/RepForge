import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/sqlite_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'fresh database restore repairs split library PRs and merges maxima',
    () async {
      final storage = SqliteStorageService(
        databasePathOverride: inMemoryDatabasePath,
      );
      await storage.init();
      addTearDown(storage.close);
      const exerciseId = 'fitify:bo999_example';
      final canonical = PersonalRecord(
        exerciseId: exerciseId,
        bestWeight: 60,
        bestReps: 8,
        bestVolume: 480,
        achievedAt: DateTime(2026, 1, 2),
        bestDuration: 90,
      );
      final split = PersonalRecord(
        exerciseId: 'fitify',
        handle: 'bo999_example',
        bestWeight: 80,
        bestReps: 6,
        bestVolume: 400,
        achievedAt: DateTime(2026, 1, 3),
        bestDuration: 120,
      );
      final actualHandle = PersonalRecord(
        exerciseId: exerciseId,
        handle: 'Rope',
        bestWeight: 30,
        bestReps: 12,
        bestVolume: 360,
        achievedAt: DateTime(2026, 1, 1),
      );
      final payload = jsonEncode({
        'backupFormatVersion': 1,
        'sessions': [
          WorkoutSession(
            id: 'restored-library-session',
            date: DateTime(2026, 1, 3),
            duration: 20,
            exercises: [
              ExerciseLog(
                exerciseId: exerciseId,
                sets: [WorkoutSet(weight: 10, reps: 5)],
              ),
            ],
          ).toJson(),
        ],
        'personalRecords': [
          canonical.toJson(),
          split.toJson(),
          actualHandle.toJson(),
        ],
      });

      await storage.importData(payload);
      final records = await storage.getAllPersonalRecords();
      expect(records, hasLength(2));
      expect(
        records.every((record) => record.exerciseId == exerciseId),
        isTrue,
      );
      final repaired = records.singleWhere((record) => record.handle == null);
      expect(repaired.bestWeight, 80);
      expect(repaired.bestReps, 8);
      expect(repaired.bestVolume, 480);
      expect(repaired.bestDuration, 120);
      expect(repaired.achievedAt, DateTime(2026, 1, 3));
      expect(
        records.singleWhere((record) => record.handle == 'Rope').toJson(),
        actualHandle.toJson(),
      );

      await storage.importData(payload);
      expect(
        (await storage.getAllPersonalRecords()).map((r) => r.toJson()).toList(),
        records.map((r) => r.toJson()).toList(),
      );
    },
  );
}
