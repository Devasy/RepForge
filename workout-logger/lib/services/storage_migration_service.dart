// One-time migration from the Hive-backed StorageService to
// SqliteStorageService. Reads exclusively through StorageService's existing,
// already-correct read methods; writes exclusively through
// SqliteStorageService's write methods. Throws on any failure — the caller
// (main.dart) decides whether to fall back to Hive. See
// docs/superpowers/specs/2026-08-08-sqlite-migration-and-coach-sql-tool-design.md §6.

import 'storage_service.dart';
import 'sqlite_storage_service.dart';

class StorageMigrationService {
  StorageMigrationService(this._source, this._target);

  final StorageService _source;
  final SqliteStorageService _target;

  Future<void> migrate() async {
    for (final session in await _source.getAllWorkoutSessions()) {
      await _target.saveWorkoutSession(session);
    }
    for (final routine in await _source.getAllRoutines()) {
      await _target.saveRoutine(routine);
    }
    for (final target in await _source.getAllTargets()) {
      await _target.saveTarget(target);
    }
    for (final mg in await _source.getAllMuscleGroups()) {
      await _target.updateMuscleGroupGrowthRate(mg.id, mg.growthRate);
    }
    for (final exercise in await _source.getCustomExercises()) {
      await _target.saveCustomExercise(exercise);
    }
    for (final record in await _source.getAllPersonalRecords()) {
      await _target.savePersonalRecord(record);
    }
    for (final program in await _source.getAllTrainingPrograms()) {
      await _target.saveTrainingProgram(program);
    }
    for (final conversation in await _source.getAllConversations()) {
      await _target.saveConversation(conversation);
    }
    final settings = await _source.getAllSettingsForMigration();
    for (final entry in settings.entries) {
      await _target.saveSetting(entry.key, entry.value);
    }
  }
}
