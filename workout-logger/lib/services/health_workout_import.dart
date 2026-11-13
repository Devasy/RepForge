import 'dart:convert';
import '../models/health_connect_workout.dart';
import '../models/models.dart';
import 'fitify_workout_decoder.dart';

enum WorkoutImportAction { add, update, current, unresolved, conflict }

class WorkoutImportEntry {
  const WorkoutImportEntry(
    this.record,
    this.action, {
    this.session,
    this.message,
  });
  final HealthConnectWorkout record;
  final WorkoutImportAction action;
  final WorkoutSession? session;
  final String? message;
  bool get canImport =>
      action == WorkoutImportAction.add || action == WorkoutImportAction.update;
}

class WorkoutImportReport {
  int added = 0, updated = 0, current = 0;
  bool refreshPending = false;
  final List<String> issues = [];
  String get summary =>
      '$added imported, $updated updated, $current already current, ${issues.length} need attention.${refreshPending ? ' Workouts saved; analysis needs refreshing.' : ''}';
}

class HealthWorkoutImport {
  static const origin = 'com.fitifysync.app';

  static String localId(HealthConnectWorkout record) =>
      'hc:${record.origin == origin ? 'fitify' : base64Url.encode(utf8.encode(record.origin))}:${base64Url.encode(utf8.encode(record.clientRecordId?.isNotEmpty == true ? record.clientRecordId! : record.recordId))}';

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
    'exercises': [
      for (final log in session.exercises) log.toJson(utcTimestamps: true),
    ],
  });

  static String _legacyContentSnapshot(WorkoutSession session) {
    final content =
        jsonDecode(contentSnapshot(session)) as Map<String, dynamic>;
    content['exercises'] = [for (final log in session.exercises) log.toJson()];
    return jsonEncode(content);
  }

  static WorkoutImportEntry inspect(
    HealthConnectWorkout record, {
    required List<Exercise> exercises,
    WorkoutSession? existing,
  }) {
    try {
      final converted = convert(record, exercises: exercises);
      if (existing == null) {
        return WorkoutImportEntry(
          record,
          WorkoutImportAction.add,
          session: converted,
          message: converted.importSource?['incompleteExerciseDetails'] == true
              ? 'Limited exercise details; workout summary available.'
              : null,
        );
      }
      final source = existing.importSource;
      if (source == null || source['origin'] != record.origin) {
        return WorkoutImportEntry(
          record,
          WorkoutImportAction.conflict,
          message:
              'A different local workout uses this identity. It was not replaced.',
        );
      }
      final version = source['version'];
      if (version is! int) {
        throw const FormatException('Invalid stored import version.');
      }
      if (version > record.version ||
          (version == record.version &&
              (record.origin == origin ||
                  jsonEncode(source['rawRecord']) ==
                      jsonEncode(record.toJson())))) {
        return WorkoutImportEntry(record, WorkoutImportAction.current);
      }
      if (source['contentSnapshot'] != contentSnapshot(existing) &&
          !(source['snapshotVersion'] == null &&
              source['contentSnapshot'] == _legacyContentSnapshot(existing))) {
        return WorkoutImportEntry(
          record,
          WorkoutImportAction.conflict,
          message:
              'This imported workout was edited in RepForge. Your edits were kept.',
        );
      }
      return WorkoutImportEntry(
        record,
        WorkoutImportAction.update,
        session: converted,
        message: converted.importSource?['incompleteExerciseDetails'] == true
            ? 'Limited exercise details; workout summary available.'
            : null,
      );
    } on FormatException catch (error) {
      return WorkoutImportEntry(
        record,
        WorkoutImportAction.unresolved,
        message: error.message,
      );
    }
  }

  static WorkoutSession convert(
    HealthConnectWorkout record, {
    required List<Exercise> exercises,
  }) {
    if (record.origin.isEmpty ||
        isRepForgeOrigin(record.origin) ||
        record.recordId.isEmpty ||
        record.version < 0 ||
        !record.end.isAfter(record.start) ||
        record.segments.length > 3000) {
      throw const FormatException('Invalid workout source.');
    }
    var cursor = record.start;
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
    final detailed = record.origin == origin;
    final logs = detailed
        ? FitifyWorkoutDecoder.decode(record, exercises)
        : _nativeLogs(record, exercises);
    final unresolved =
        !detailed &&
        record.segments
            .where(
              (s) => !s.isRest && !exercises.any((e) => e.id == s.exerciseId),
            )
            .isNotEmpty;
    final session = WorkoutSession(
      id: localId(record),
      date: record.start.toLocal(),
      duration: (record.end.difference(record.start).inSeconds / 60).ceil(),
      notes: [
        'Imported from Health Connect',
        if (unresolved || logs.isEmpty)
          'The source did not provide complete supported exercise details.',
        if (!detailed && record.notes?.trim().isNotEmpty == true)
          record.notes!.trim(),
      ].join('\n'),
      exercises: logs,
    );
    return session.copyWith(
      importSource: {
        'origin': record.origin,
        'recordId': record.recordId,
        'clientRecordId': record.clientRecordId,
        'version': record.version,
        'rawRecord': record.toJson(),
        'contentSnapshot': contentSnapshot(session),
        'snapshotVersion': 2,
        'timingReconstructed': detailed,
        'incompleteExerciseDetails': unresolved || logs.isEmpty,
      },
    );
  }

  static bool isRepForgeOrigin(String value) =>
      value == 'com.devasy.repforge' || value == 'com.devasy.repforge.debug';

  static List<ExerciseLog> _nativeLogs(
    HealthConnectWorkout record,
    List<Exercise> exercises,
  ) {
    final available = {for (final e in exercises) e.id};
    final logs = <ExerciseLog>[];
    for (final segment in record.segments) {
      final id = segment.exerciseId;
      if (segment.isRest || id == null || !available.contains(id)) continue;
      if (logs.isEmpty || logs.last.exerciseId != id)
        logs.add(ExerciseLog(exerciseId: id, sets: []));
      logs.last.sets.add(
        WorkoutSet(
          weight: segment.weightKg ?? 0,
          reps: segment.repetitions ?? 0,
          timeTaken: segment.end.difference(segment.start).inSeconds,
          timestamp: segment.end.toLocal(),
          loadMode: segment.weightKg == null
              ? WorkoutLoadMode.unknown
              : WorkoutLoadMode.external,
        ),
      );
    }
    return logs;
  }
}
