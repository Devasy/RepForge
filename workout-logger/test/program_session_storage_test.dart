import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/sqlite_storage_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
    'SQLite keeps exact program context through save, edit and reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('program-context-');
      final path = '${dir.path}/test.db';
      var storage = SqliteStorageService(databasePathOverride: path);
      try {
        await storage.init();
        final session = WorkoutSession(
          id: 's',
          date: DateTime(2026, 1, 1),
          duration: 10,
          programId: 'p',
          programWeekNumber: 2,
          programDayId: 'day',
          exercises: [
            ExerciseLog(
              exerciseId: 'bench_press',
              sets: [WorkoutSet(weight: 40, reps: 8)],
            ),
          ],
        );
        await storage.saveWorkoutSession(session);
        await storage.saveWorkoutSession(session.copyWith(notes: 'edited'));
        await storage.close();
        storage = SqliteStorageService(databasePathOverride: path);
        await storage.init();
        final saved = (await storage.getAllWorkoutSessions()).single;
        expect(saved.programId, 'p');
        expect(saved.programWeekNumber, 2);
        expect(saved.programDayId, 'day');
        expect(saved.notes, 'edited');
        expect(saved.exercises.single.sets.single.reps, 8);
      } finally {
        await storage.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'v7 migration preserves legacy session without inventing completion',
    () async {
      final dir = await Directory.systemTemp.createTemp('program-v7-');
      final path = '${dir.path}/test.db';
      final old = await openDatabase(
        path,
        version: 7,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE muscle_groups (id TEXT PRIMARY KEY, name TEXT, growth_rate REAL, last_updated TEXT)',
          );
          await db.execute(
            'CREATE TABLE sessions (id TEXT PRIMARY KEY, date TEXT, routine_id TEXT, duration_min INTEGER, notes TEXT, hc_synced_at TEXT, session_effort INTEGER)',
          );
          await db.insert('sessions', {
            'id': 'legacy',
            'date': '2026-01-01',
            'duration_min': 10,
            'notes': 'keep',
          });
        },
      );
      await old.close();
      final storage = SqliteStorageService(databasePathOverride: path);
      try {
        await storage.init();
        final db = await openDatabase(path, singleInstance: false);
        final rows = await db.query('sessions');
        expect(rows.single['notes'], 'keep');
        expect(rows.single['program_id'], isNull);
        expect(rows.single['program_day_id'], isNull);
        expect(rows.single['program_week_number'], isNull);
        await db.close();
      } finally {
        await storage.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
