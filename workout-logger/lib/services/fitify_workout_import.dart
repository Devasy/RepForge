import 'dart:convert';
import '../models/health_connect_workout.dart';
import '../models/models.dart';
import 'extended_exercise_library.dart';

enum FitifyImportAction { add, update, current, unresolved, conflict }

class FitifyImportEntry {
  const FitifyImportEntry(
    this.record,
    this.action, {
    this.session,
    this.message,
  });
  final HealthConnectWorkout record;
  final FitifyImportAction action;
  final WorkoutSession? session;
  final String? message;
  bool get canImport =>
      action == FitifyImportAction.add || action == FitifyImportAction.update;
}

class FitifyImportReport {
  int added = 0, updated = 0, current = 0;
  final List<String> issues = [];
  String get summary =>
      '$added imported, $updated updated, $current already current, ${issues.length} need attention.';
}

class FitifyWorkoutImport {
  static const origin = 'com.fitifysync.app';

  static String localId(HealthConnectWorkout record) =>
      'hc:fitify:${base64Url.encode(utf8.encode(record.clientRecordId?.isNotEmpty == true ? record.clientRecordId! : record.recordId))}';

  /// Excludes sync/source metadata so local edits can be detected on reimport.
  static String contentSnapshot(WorkoutSession session) => jsonEncode({
    'date': session.date.toUtc().toIso8601String(),
    'duration': session.duration,
    'routineId': session.routineId,
    'programId': session.programId,
    'programDayId': session.programDayId,
    'programWeekNumber': session.programWeekNumber,
    'notes': session.notes,
    'sessionEffort': session.sessionEffort,
    'exercises': [for (final log in session.exercises) log.toJson()],
  });

  static FitifyImportEntry inspect(
    HealthConnectWorkout record, {
    required List<Exercise> exercises,
    WorkoutSession? existing,
  }) {
    try {
      final converted = convert(record, exercises: exercises);
      if (existing == null) {
        return FitifyImportEntry(
          record,
          FitifyImportAction.add,
          session: converted,
        );
      }
      final source = existing.importSource;
      if (source == null || source['origin'] != origin) {
        return FitifyImportEntry(
          record,
          FitifyImportAction.conflict,
          message:
              'A different local workout uses this identity. It was not replaced.',
        );
      }
      final version = source['version'];
      if (version is! int) {
        throw const FormatException('Invalid stored import version.');
      }
      if (version >= record.version) {
        return FitifyImportEntry(record, FitifyImportAction.current);
      }
      if (source['contentSnapshot'] != contentSnapshot(existing)) {
        return FitifyImportEntry(
          record,
          FitifyImportAction.conflict,
          message:
              'This imported workout was edited in RepForge. Your edits were kept.',
        );
      }
      return FitifyImportEntry(
        record,
        FitifyImportAction.update,
        session: converted,
      );
    } on FormatException catch (error) {
      return FitifyImportEntry(
        record,
        FitifyImportAction.unresolved,
        message: error.message,
      );
    }
  }

  static WorkoutSession convert(
    HealthConnectWorkout record, {
    required List<Exercise> exercises,
  }) {
    if (record.origin != origin ||
        record.recordId.isEmpty ||
        record.version < 0 ||
        !record.end.isAfter(record.start) ||
        record.segments.length > 3000) {
      throw const FormatException('Invalid FitifySync workout source.');
    }
    final notes = record.notes;
    if (notes == null || utf8.encode(notes).length > 64 * 1024) {
      throw const FormatException(
        'Missing or oversized FitifySync exercise payload. Re-sync using the updated FitifySync app.',
      );
    }
    final trimmed = notes.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
        'FitifySync notes are empty. Re-sync using the updated FitifySync app.',
      );
    }
    final payloadText = trimmed.startsWith('{')
        ? trimmed
        : trimmed.substring(trimmed.lastIndexOf('\n\n') + 2);
    final payload = jsonDecode(payloadText);
    if (payload is! Map ||
        payload['schema'] != 'fitifysync.exercise_segments' ||
        payload['version'] is! int ||
        payload['version'] != 1 ||
        payload['exercises'] is! List) {
      throw const FormatException(
        'Unsupported FitifySync notes schema. Re-sync using the updated FitifySync app.',
      );
    }
    final available = {for (final exercise in exercises) exercise.id: exercise};
    final seen = <int>{};
    final groups = <({String exerciseId, List<WorkoutSet> sets})>[];
    DateTime cursor = record.start;
    for (final segment in record.segments) {
      if (segment.start.isBefore(cursor) ||
          !segment.end.isAfter(segment.start) ||
          segment.end.isAfter(record.end) ||
          (segment.repetitions ?? 0) < 0 ||
          (segment.weightKg != null &&
              (!segment.weightKg!.isFinite || segment.weightKg! < 0))) {
        throw const FormatException(
          'Invalid or overlapping exercise segments.',
        );
      }
      cursor = segment.end;
    }
    final items = List<dynamic>.from(payload['exercises'] as List);
    for (final item in items) {
      if (item is! Map ||
          item['segment_index'] is! int ||
          item['code'] is! String ||
          item['name'] is! String ||
          item['timing_kind'] != 'reconstructed') {
        throw const FormatException(
          'Invalid exercise identity or timing provenance.',
        );
      }
      final index = item['segment_index'] as int;
      if (index < 0 ||
          index >= record.segments.length ||
          !seen.add(index) ||
          record.segments[index].isRest) {
        throw const FormatException('Invalid exercise segment index.');
      }
    }
    items.sort(
      (a, b) =>
          (a['segment_index'] as int).compareTo(b['segment_index'] as int),
    );
    for (final item in items) {
      final code = item['code'] as String;
      final builtIn = ExtendedExerciseLibrary.builtInIdForCode(code);
      final exercise = available[builtIn] ?? available['fitify:$code'];
      if (code.isEmpty || exercise == null) {
        throw FormatException(
          'Exercise code "$code" is unresolved. Download the extended library or update it before importing.',
        );
      }
      final segment = record.segments[item['segment_index'] as int];
      final reps = segment.repetitions ?? 0;
      final seconds = segment.end.difference(segment.start).inSeconds;
      if (reps == 0 && seconds <= 0) {
        throw const FormatException(
          'Exercise has no usable repetitions or duration.',
        );
      }
      if (groups.isEmpty || groups.last.exerciseId != exercise.id) {
        groups.add((exerciseId: exercise.id, sets: <WorkoutSet>[]));
      }
      groups.last.sets.add(
        WorkoutSet(
          weight: segment.weightKg ?? 0,
          reps: reps,
          timeTaken: seconds,
          timestamp: segment.end.toLocal(),
          loadMode: segment.weightKg == null
              ? WorkoutLoadMode.unknown
              : WorkoutLoadMode.external,
        ),
      );
    }
    if (seen.length != record.segments.where((s) => !s.isRest).length ||
        groups.isEmpty) {
      throw const FormatException(
        'The payload does not identify every active exercise segment. Re-sync using the updated FitifySync app.',
      );
    }
    final session = WorkoutSession(
      id: localId(record),
      date: record.start.toLocal(),
      duration: (record.end.difference(record.start).inSeconds / 60).ceil(),
      notes:
          'Imported from FitifySync${record.title == null ? '' : ': ${record.title}'}',
      exercises: [
        for (final entry in groups)
          ExerciseLog(
            exerciseId: entry.exerciseId,
            sets: entry.sets,
            notes:
                'FitifySync: reconstructed segment timing. Missing loads are unknown; no bodyweight is inferred.',
          ),
      ],
    );
    return session.copyWith(
      importSource: {
        'origin': record.origin,
        'recordId': record.recordId,
        'clientRecordId': record.clientRecordId,
        'version': record.version,
        'rawRecord': record.toJson(),
        'contentSnapshot': contentSnapshot(session),
      },
    );
  }
}
