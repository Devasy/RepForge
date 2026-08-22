// PRManager — detects and persists personal records per exercise.
//
// After each workout session is saved, call checkAndUpdatePRs() to compare
// every logged set against the stored PR for that exercise.  Returns a list
// of NewPRResult describing which record types were broken so the UI can
// display badges on the summary screen.

import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';

class NewPRResult {
  final String exerciseId;
  final Set<String> types; // 'weight' | 'reps' | 'volume'

  const NewPRResult({required this.exerciseId, required this.types});
}

class PRManager extends ChangeNotifier {
  final IStorageService _storage;

  // exerciseId → best known record
  final Map<String, PersonalRecord> _cache = {};

  PRManager(this._storage);

  Future<void> load() async {
    final records = await _storage.getAllPersonalRecords();
    _cache.clear();
    for (final r in records) {
      _cache[r.exerciseId] = r;
    }
  }

  List<PersonalRecord> get allRecords => List.unmodifiable(_cache.values.toList());

  /// Seed PRs from historical sessions when no stored records exist yet.
  ///
  /// Sessions must be sorted oldest → newest so later sessions win on ties.
  Future<void> backfillFromSessions(List<WorkoutSession> sessions) async {
    final sorted = [...sessions]..sort((a, b) => a.date.compareTo(b.date));
    for (final s in sorted) {
      await checkAndUpdatePRs(s);
    }
  }

  PersonalRecord? getRecord(String exerciseId, {String? handle}) {
    final key = (handle != null && handle.isNotEmpty) ? '$exerciseId:$handle' : exerciseId;
    return _cache[key] ?? _cache[exerciseId];
  }

  /// Compare each exercise log in [session] against stored PRs.
  ///
  /// Updates storage + in-memory cache for any broken records.
  /// Returns only entries where at least one record was broken.
  Future<List<NewPRResult>> checkAndUpdatePRs(WorkoutSession session) async {
    final results = <NewPRResult>[];

    for (final log in session.exercises) {
      if (log.sets.isEmpty) continue;

      final broken = await _checkExercise(log, session.date);
      if (broken.isNotEmpty) {
        results.add(NewPRResult(exerciseId: log.exerciseId, types: broken));
      }
    }

    if (results.isNotEmpty) notifyListeners();
    return results;
  }

  Future<Set<String>> _checkExercise(ExerciseLog log, DateTime date) async {
    final handle = log.handle ?? log.sets.where((s) => s.handle != null).firstOrNull?.handle;
    final key = (handle != null && handle.isNotEmpty) ? '${log.exerciseId}:$handle' : log.exerciseId;
    final existing = _cache[key];

    double newBestWeight = existing?.bestWeight ?? 0;
    int newBestReps = existing?.bestReps ?? 0;
    double newBestVolume = existing?.bestVolume ?? 0;

    for (final set in log.sets) {
      if (set.weight > newBestWeight) newBestWeight = set.weight;
      if (set.reps > newBestReps) newBestReps = set.reps;
      if (set.volume > newBestVolume) newBestVolume = set.volume;
    }

    final broken = <String>{};
    if (existing == null) {
      broken.addAll(['weight', 'reps', 'volume']);
    } else {
      if (newBestWeight > existing.bestWeight) broken.add('weight');
      if (newBestReps > existing.bestReps) broken.add('reps');
      if (newBestVolume > existing.bestVolume) broken.add('volume');
    }

    if (broken.isEmpty) return broken;

    final updated = PersonalRecord(
      exerciseId: key,
      bestWeight: newBestWeight,
      bestReps: newBestReps,
      bestVolume: newBestVolume,
      achievedAt: date,
    );
    _cache[key] = updated;
    await _storage.savePersonalRecord(updated);

    return broken;
  }
}
