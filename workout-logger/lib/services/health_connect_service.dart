import 'dart:math' show max;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:health_connector/health_connector.dart';

import '../models/models.dart';
import 'interfaces/health_connect_service_interface.dart';

class HealthConnectService implements IHealthConnectService {
  HealthConnector? _connector;

  // Maps RepForge exercise IDs to Health Connect ExerciseSegmentType enum values.
  // Custom exercises not in this map fall back to otherWorkout.
  static const _segmentTypeMap = <String, ExerciseSegmentType>{
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

  @override
  Future<bool> isAvailable() async {
    try {
      final status = await HealthConnector.getHealthPlatformStatus();
      return status == HealthPlatformStatus.available;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      _connector ??= await HealthConnector.create();
      final results = await _connector!.requestPermissions([
        HealthDataType.exerciseSession.writePermission,
      ]);
      return results.every((r) => r.status == PermissionStatus.granted);
    } catch (e) {
      debugPrint('Health Connect requestPermissions failed: $e');
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    try {
      _connector ??= await HealthConnector.create();
      final status = await _connector!.getPermissionStatus(
        HealthDataType.exerciseSession.writePermission,
      );
      return status == PermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> syncWorkoutSession(WorkoutSession session, {String? title}) async {
    try {
      _connector ??= await HealthConnector.create();

      final sessionStart = session.date;
      final durationMinutes = max(session.duration, 1);
      final sessionEnd = sessionStart.add(Duration(minutes: durationMinutes));
      final segments = _buildSegments(session, sessionStart, sessionEnd);

      final record = ExerciseSessionRecord(
        startTime: sessionStart,
        endTime: sessionEnd,
        exerciseType: ExerciseType.strengthTraining,
        metadata: Metadata.manualEntry(),
        title: title?.isNotEmpty == true ? title : null,
        notes: session.notes?.isNotEmpty == true ? session.notes : null,
        events: segments,
      );

      await _connector!.writeRecords([record]);
      return true;
    } catch (e) {
      debugPrint('Health Connect sync failed: $e');
      return false;
    }
  }

  // Builds non-overlapping ExerciseSessionSegmentEvents using per-set timestamps
  // from WorkoutSet.timestamp. Sets are sorted by their recorded timestamp so
  // that each segment's startTime reflects when the set was actually performed.
  //
  // Fallback: if all timestamps are identical (e.g. fabricated via DateTime.now()
  // default on legacy data) the method falls back to the original evenly-spaced
  // distribution so callers always receive valid, non-empty output.
  List<ExerciseSessionSegmentEvent> _buildSegments(
    WorkoutSession session,
    DateTime sessionStart,
    DateTime sessionEnd,
  ) {
    // Collect (segmentType, reps, timestamp) for every valid set.
    final allSets = <(ExerciseSegmentType, int, DateTime)>[];

    for (final log in session.exercises) {
      final type =
          _segmentTypeMap[log.exerciseId] ?? ExerciseSegmentType.otherWorkout;
      for (final set in log.sets) {
        if (set.reps > 0) {
          allSets.add((type, set.reps, set.timestamp));
        }
      }
    }

    if (allSets.isEmpty) return [];

    // Sort by recorded timestamp so segments follow real workout order.
    allSets.sort((a, b) => a.$3.compareTo(b.$3));

    // Clamp all set timestamps to [sessionStart, sessionEnd] before the
    // uniqueness check.  Without this, timestamps recorded after the session
    // window ends (e.g. the last set logged slightly past the stored duration)
    // all collapse to sessionEnd after clamping in the segment-build loop,
    // producing zero-duration segments that Health Connect rejects silently.
    final clampedSets = allSets
        .map((s) {
          var ts = s.$3;
          if (ts.isBefore(sessionStart)) ts = sessionStart;
          if (ts.isAfter(sessionEnd)) ts = sessionEnd;
          return (s.$1, s.$2, ts);
        })
        .toList();

    // Fall back to evenly-spaced distribution whenever clamped timestamps are
    // not fully unique.  Duplicate timestamps arise when:
    //   • All sets share the same instant (legacy data / unit-test stubs).
    //   • Two or more sets were logged within the same DateTime resolution tick
    //     (common on devices where DateTime.now() resolution is ~1 ms).
    //   • One or more timestamps were clamped to the same boundary value.
    // In any of these cases the real-timestamp path would produce overlapping or
    // zero-duration segments, which ExerciseSessionRecord's constructor rejects
    // with an ArgumentError, silently aborting the sync.
    final uniqueTimestamps = clampedSets.map((s) => s.$3).toSet();
    if (uniqueTimestamps.length < clampedSets.length) {
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
        );
      });
    }

    // Build segments using clamped timestamps (already within [sessionStart, sessionEnd]).
    final segments = <ExerciseSessionSegmentEvent>[];
    for (var i = 0; i < clampedSets.length; i++) {
      final start = clampedSets[i].$3;
      final end = i < clampedSets.length - 1 ? clampedSets[i + 1].$3 : sessionEnd;
      segments.add(ExerciseSessionSegmentEvent(
        startTime: start,
        endTime: end,
        segmentType: clampedSets[i].$1,
        repetitions: clampedSets[i].$2,
      ));
    }
    return segments;
  }
}
