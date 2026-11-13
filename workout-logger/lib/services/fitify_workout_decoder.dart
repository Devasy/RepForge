import 'dart:convert';
import '../models/health_connect_workout.dart';
import '../models/models.dart';
import 'extended_exercise_library.dart';

class FitifyWorkoutDecoder {
  static List<ExerciseLog> decode(
    HealthConnectWorkout record,
    List<Exercise> exercises,
  ) {
    final notes = record.notes;
    if (notes == null || utf8.encode(notes).length > 64 * 1024) {
      throw const FormatException(
        'Missing or oversized exercise details. Sync the source app again.',
      );
    }
    final trimmed = notes.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
        'Exercise details are empty. Sync the source app again.',
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
        'Unsupported exercise details. Update and sync the source app again.',
      );
    }
    final available = {for (final exercise in exercises) exercise.id: exercise};
    final seen = <int>{};
    final groups = <({String exerciseId, List<WorkoutSet> sets})>[];
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
          'An exercise is not in your library. Download or update the extended library before importing.',
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
        'The payload does not identify every active exercise segment. Sync the source app again.',
      );
    }
    return [
      for (final entry in groups)
        ExerciseLog(
          exerciseId: entry.exerciseId,
          sets: entry.sets,
          notes: 'Segment timings were reconstructed by the source app.',
        ),
    ];
  }
}
