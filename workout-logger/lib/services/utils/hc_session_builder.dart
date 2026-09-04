// Health Connect session builder.
//
// Pure functions turning a WorkoutSession into Health Connect segments.
// Kept out of HealthConnectService so segment layout is unit-testable
// without a platform channel.

import 'package:health_connector/health_connector.dart';

import '../../models/models.dart';

/// RepForge exercise IDs → Health Connect ExerciseSegmentType values.
/// Unmapped IDs (custom exercises) fall back to otherWorkout.
const _segmentTypeMap = <String, ExerciseSegmentType>{
  'bench_press': ExerciseSegmentType.benchPress,
  'incline_bench_press': ExerciseSegmentType.benchPress,
  'dumbbell_bench_press': ExerciseSegmentType.benchPress,
  'incline_dumbbell_press': ExerciseSegmentType.benchPress,
  'close_grip_bench': ExerciseSegmentType.benchPress,
  'push_ups': ExerciseSegmentType.otherWorkout,
  'dips': ExerciseSegmentType.otherWorkout,
  'cable_fly': ExerciseSegmentType.otherWorkout,
  'pec_deck': ExerciseSegmentType.otherWorkout,
  'lat_pulldown': ExerciseSegmentType.latPullDown,
  'pull_ups': ExerciseSegmentType.pullUp,
  'chin_ups': ExerciseSegmentType.pullUp,
  'barbell_row': ExerciseSegmentType.otherWorkout,
  'dumbbell_row': ExerciseSegmentType.dumbbellRow,
  'seated_cable_row': ExerciseSegmentType.otherWorkout,
  't_bar_row': ExerciseSegmentType.otherWorkout,
  'deadlift': ExerciseSegmentType.deadlift,
  'romanian_deadlift': ExerciseSegmentType.deadlift,
  'face_pull': ExerciseSegmentType.otherWorkout,
  'overhead_press': ExerciseSegmentType.barbellShoulderPress,
  'dumbbell_shoulder_press': ExerciseSegmentType.shoulderPress,
  'lateral_raise': ExerciseSegmentType.dumbbellLateralRaise,
  'front_raise': ExerciseSegmentType.dumbbellFrontRaise,
  'rear_delt_fly': ExerciseSegmentType.otherWorkout,
  'shrugs': ExerciseSegmentType.otherWorkout,
  'squat': ExerciseSegmentType.squat,
  'leg_press': ExerciseSegmentType.legPress,
  'leg_extension': ExerciseSegmentType.legExtension,
  'leg_curl': ExerciseSegmentType.legCurl,
  'lunges': ExerciseSegmentType.lunge,
  'hip_thrust': ExerciseSegmentType.hipThrust,
  'calf_raise': ExerciseSegmentType.otherWorkout,
  'bicep_curl': ExerciseSegmentType.armCurl,
  'hammer_curl': ExerciseSegmentType.armCurl,
  'preacher_curl': ExerciseSegmentType.armCurl,
  'concentration_curl': ExerciseSegmentType.armCurl,
  'tricep_pushdown': ExerciseSegmentType.otherWorkout,
  'skull_crushers': ExerciseSegmentType.otherWorkout,
  'overhead_tricep_extension': ExerciseSegmentType.doubleArmTricepsExtension,
  'plank': ExerciseSegmentType.plank,
  'crunches': ExerciseSegmentType.crunch,
  'cable_crunch': ExerciseSegmentType.crunch,
  'russian_twist': ExerciseSegmentType.crunch,
  'leg_raises': ExerciseSegmentType.legRaise,
};

/// The Health Connect segment type for a RepForge exercise ID.
ExerciseSegmentType hcSegmentTypeFor(String exerciseId) =>
    _segmentTypeMap[exerciseId] ?? ExerciseSegmentType.otherWorkout;

/// Builds non-overlapping segments for [session] inside
/// [sessionStart]–[sessionEnd], ordered by each set's recorded timestamp.
///
/// Falls back to an evenly-spaced layout when the recorded timestamps cannot
/// produce a valid layout (duplicate timestamps on legacy data, or a final
/// set clamped onto [sessionEnd]), since zero-duration or overlapping
/// segments make Health Connect reject the whole record.
List<ExerciseSessionSegmentEvent> buildHcSegments({
  required WorkoutSession session,
  required DateTime sessionStart,
  required DateTime sessionEnd,
}) {
  final allSets = <(ExerciseSegmentType, int, DateTime, double)>[];

  for (final log in session.exercises) {
    final type = hcSegmentTypeFor(log.exerciseId);
    for (final set in log.sets) {
      if (set.reps > 0) {
        allSets.add((type, set.reps, set.timestamp, set.weight));
      }
    }
  }

  if (allSets.isEmpty) return [];

  allSets.sort((a, b) => a.$3.compareTo(b.$3));

  final clampedSets = allSets.map((s) {
    var ts = s.$3;
    if (ts.isBefore(sessionStart)) ts = sessionStart;
    if (ts.isAfter(sessionEnd)) ts = sessionEnd;
    return (s.$1, s.$2, ts, s.$4);
  }).toList();

  final uniqueTimestamps = clampedSets.map((s) => s.$3).toSet();
  if (uniqueTimestamps.length < clampedSets.length ||
      clampedSets.last.$3 == sessionEnd) {
    final totalMs = sessionEnd.difference(sessionStart).inMilliseconds;
    final slotMs = totalMs ~/ clampedSets.length;
    return List.generate(clampedSets.length, (i) {
      final start = sessionStart.add(Duration(milliseconds: slotMs * i));
      final end = i < clampedSets.length - 1
          ? sessionStart.add(Duration(milliseconds: slotMs * (i + 1)))
          : sessionEnd;
      return ExerciseSessionSegmentEvent(
        startTime: start,
        endTime: end,
        segmentType: clampedSets[i].$1,
        repetitions: clampedSets[i].$2,
        weight: clampedSets[i].$4 > 0 ? Mass.kilograms(clampedSets[i].$4) : null,
      );
    });
  }

  final segments = <ExerciseSessionSegmentEvent>[];
  for (var i = 0; i < clampedSets.length; i++) {
    final start = clampedSets[i].$3;
    final end = i < clampedSets.length - 1 ? clampedSets[i + 1].$3 : sessionEnd;
    segments.add(ExerciseSessionSegmentEvent(
      startTime: start,
      endTime: end,
      segmentType: clampedSets[i].$1,
      repetitions: clampedSets[i].$2,
      weight: clampedSets[i].$4 > 0 ? Mass.kilograms(clampedSets[i].$4) : null,
    ));
  }
  return segments;
}
