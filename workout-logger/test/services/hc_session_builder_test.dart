import 'package:flutter_test/flutter_test.dart';
import 'package:health_connector/health_connector.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/utils/hc_session_builder.dart';

WorkoutSession _session({
  required DateTime start,
  required int durationMinutes,
  required List<ExerciseLog> exercises,
  String? notes,
}) =>
    WorkoutSession(
      id: 'sess_1',
      date: start,
      duration: durationMinutes,
      exercises: exercises,
      notes: notes,
    );

void main() {
  final start = DateTime(2026, 9, 4, 18);

  group('hcSegmentTypeFor', () {
    test('maps a known exercise to its Health Connect segment type', () {
      expect(hcSegmentTypeFor('bench_press'), ExerciseSegmentType.benchPress);
    });

    test('falls back to otherWorkout for an unknown custom exercise', () {
      expect(hcSegmentTypeFor('custom_abc'), ExerciseSegmentType.otherWorkout);
    });
  });

  group('buildHcSegments', () {
    test('returns empty when no set has reps', () {
      final session = _session(
        start: start,
        durationMinutes: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [WorkoutSet(weight: 60, reps: 0, timestamp: start)],
          ),
        ],
      );

      final segments = buildHcSegments(
        session: session,
        sessionStart: start,
        sessionEnd: start.add(const Duration(minutes: 30)),
      );

      expect(segments, isEmpty);
    });

    test('spaces segments evenly when set timestamps are identical', () {
      final session = _session(
        start: start,
        durationMinutes: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [
              WorkoutSet(weight: 60, reps: 10, timestamp: start),
              WorkoutSet(weight: 70, reps: 8, timestamp: start),
            ],
          ),
        ],
      );

      final segments = buildHcSegments(
        session: session,
        sessionStart: start,
        sessionEnd: start.add(const Duration(minutes: 30)),
      );

      expect(segments.length, 2);
      expect(segments.first.startTime, start);
      expect(segments.first.endTime, start.add(const Duration(minutes: 15)));
      expect(segments.last.endTime, start.add(const Duration(minutes: 30)));
      expect(segments.first.repetitions, 10);
      expect(segments.first.weight, const Mass.kilograms(60));
    });

    test('never emits overlapping segments for distinct timestamps', () {
      final session = _session(
        start: start,
        durationMinutes: 30,
        exercises: [
          ExerciseLog(
            exerciseId: 'squat',
            sets: [
              WorkoutSet(weight: 80, reps: 5, timestamp: start.add(const Duration(minutes: 5))),
              WorkoutSet(weight: 90, reps: 5, timestamp: start.add(const Duration(minutes: 12))),
              WorkoutSet(weight: 100, reps: 3, timestamp: start.add(const Duration(minutes: 20))),
            ],
          ),
        ],
      );

      final segments = buildHcSegments(
        session: session,
        sessionStart: start,
        sessionEnd: start.add(const Duration(minutes: 30)),
      );

      for (var i = 0; i < segments.length - 1; i++) {
        expect(segments[i].endTime.isAfter(segments[i + 1].startTime), isFalse);
        expect(segments[i].endTime.isAfter(segments[i].startTime), isTrue);
      }
      expect(segments.first.startTime.isBefore(start), isFalse);
      expect(segments.last.endTime.isAfter(start.add(const Duration(minutes: 30))), isFalse);
    });

    test('omits weight when the set weight is zero', () {
      final session = _session(
        start: start,
        durationMinutes: 20,
        exercises: [
          ExerciseLog(
            exerciseId: 'pull_ups',
            sets: [
              WorkoutSet(weight: 0, reps: 8, timestamp: start.add(const Duration(minutes: 4))),
              WorkoutSet(weight: 0, reps: 6, timestamp: start.add(const Duration(minutes: 10))),
            ],
          ),
        ],
      );

      final segments = buildHcSegments(
        session: session,
        sessionStart: start,
        sessionEnd: start.add(const Duration(minutes: 20)),
      );

      expect(segments, isNotEmpty);
      expect(segments.every((s) => s.weight == null), isTrue);
    });
  });
}
