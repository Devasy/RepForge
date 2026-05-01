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

    // Check whether timestamps are meaningful: if every set has the exact same
    // timestamp it almost certainly means they were created with DateTime.now()
    // at the same instant (legacy data or unit-test stubs).  In that case fall
    // back to the original even-distribution algorithm.
    final allSameTimestamp = allSets.every((s) => s.$3 == allSets.first.$3);
    if (allSameTimestamp) {
      final totalMs = sessionEnd.difference(sessionStart).inMilliseconds;
      final slotMs = totalMs ~/ allSets.length;
      return List.generate(allSets.length, (i) {
        final start = sessionStart.add(Duration(milliseconds: slotMs * i));
        final end = i < allSets.length - 1
            ? sessionStart.add(Duration(milliseconds: slotMs * (i + 1)))
            : sessionEnd;
        return ExerciseSessionSegmentEvent(
          startTime: start,
          endTime: end,
          segmentType: allSets[i].$1,
          repetitions: allSets[i].$2,
        );
      });
    }

    // Build segments using real timestamps.
    // Each segment's startTime is the set's timestamp clamped to [sessionStart, sessionEnd].
    // endTime is the next set's timestamp (or sessionEnd for the last set),
    // clamped so start <= end <= sessionEnd.
    final segments = <ExerciseSessionSegmentEvent>[];
    for (var i = 0; i < allSets.length; i++) {
      final rawStart = allSets[i].$3;
      final start = rawStart.isBefore(sessionStart)
          ? sessionStart
          : rawStart.isAfter(sessionEnd)
              ? sessionEnd
              : rawStart;

      final DateTime rawEnd;
      if (i < allSets.length - 1) {
        rawEnd = allSets[i + 1].$3;
      } else {
        rawEnd = sessionEnd;
      }
      // Clamp: end must be >= start and <= sessionEnd.
      final end = rawEnd.isBefore(start)
          ? start
          : rawEnd.isAfter(sessionEnd)
              ? sessionEnd
              : rawEnd;

      segments.add(ExerciseSessionSegmentEvent(
        startTime: start,
        endTime: end,
        segmentType: allSets[i].$1,
        repetitions: allSets[i].$2,
      ));
    }
    return segments;
  }
}
