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

  static const _statusDeadline = Duration(seconds: 5);
  static const _queryDeadline = Duration(seconds: 10);
  static const _hrQueryDeadline = Duration(seconds: 20);

  Future<HealthConnector?> _getConnector() async {
    try {
      _connector ??= await HealthConnector.create().timeout(_statusDeadline);
      return _connector;
    } catch (e) {
      debugPrint('[HC] _getConnector failed: $e');
      return null;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final status = await HealthConnector.getHealthPlatformStatus().timeout(_statusDeadline);
      debugPrint('[HC] isAvailable: platform status = $status');
      return status == HealthPlatformStatus.available;
    } catch (e) {
      debugPrint('[HC] isAvailable: exception = $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final connector = await _getConnector();
      if (connector == null) return false;
      final results = await connector.requestPermissions([
        HealthDataType.exerciseSession.writePermission,
        HealthDataType.exerciseSession.readPermission,
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
      final connector = await _getConnector();
      if (connector == null) return false;
      final status = await connector.getPermissionStatus(
        HealthDataType.exerciseSession.writePermission,
      ).timeout(_statusDeadline);
      return status == PermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  static final Map<HealthReadType, HealthDataPermission> _readPermissions = {
    HealthReadType.sleep: HealthDataType.sleepSession.readPermission,
    // heartRateSeries maps to Android HeartRateRecord (series with samples).
    // heartRate is iOS-only and throws UNSUPPORTED_OPERATION on Health Connect.
    HealthReadType.heartRate: HealthDataType.heartRateSeries.readPermission,
    HealthReadType.restingHeartRate:
        HealthDataType.restingHeartRate.readPermission,
    HealthReadType.hrv: HealthDataType.heartRateVariabilityRMSSD.readPermission,
  };

  @override
  Future<bool> requestReadPermissions() async {
    debugPrint('[HC] requestReadPermissions: requesting ${_readPermissions.length} permissions individually');
    final connector = await _getConnector();
    if (connector == null) return false;
    var anyGranted = false;
    for (final entry in _readPermissions.entries) {
      try {
        final results = await connector.requestPermissions([entry.value]);
        final granted = results.any((r) => r.status == PermissionStatus.granted);
        debugPrint('[HC] requestReadPermissions: ${entry.key} → granted=$granted');
        if (granted) anyGranted = true;
      } catch (e) {
        debugPrint('[HC] requestReadPermissions: ${entry.key} unsupported, skipping ($e)');
      }
    }
    debugPrint('[HC] requestReadPermissions: anyGranted = $anyGranted');
    return anyGranted;
  }

  @override
  Future<Set<HealthReadType>> grantedReadTypes() async {
    final connector = await _getConnector();
    if (connector == null) return {};
    final granted = <HealthReadType>{};
    for (final entry in _readPermissions.entries) {
      try {
        final status = await connector.getPermissionStatus(entry.value).timeout(_statusDeadline);
        debugPrint('[HC] grantedReadTypes: ${entry.key} → $status');
        if (status == PermissionStatus.granted) granted.add(entry.key);
      } catch (e) {
        debugPrint('[HC] grantedReadTypes: ${entry.key} unsupported, skipping ($e)');
      }
    }
    debugPrint('[HC] grantedReadTypes: result = $granted');
    return granted;
  }

  @override
  Future<List<SleepPeriod>> readSleepSessions(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final connector = await _getConnector();
      if (connector == null) return const [];
      final response = await connector.readRecords(
        HealthDataType.sleepSession.readInTimeRange(
          startTime: start,
          endTime: end,
        ),
      ).timeout(_queryDeadline);
      final result = response.records.map((r) {
        // Tally stage durations from embedded SleepStageSamples and build
        // an ordered stage timeline for HR segment colouring.
        var light = 0, deep = 0, rem = 0, awake = 0;
        final timeline = <SleepStageInterval>[];
        var cursor = r.startTime;
        for (final s in r.samples) {
          final segEnd = cursor.add(s.duration);
          final mins = s.duration.inMinutes;
          switch (s.stageType) {
            case SleepStage.light:
            case SleepStage.sleeping: // generic "asleep" — count as light
              light += mins;
              timeline.add(SleepStageInterval(start: cursor, end: segEnd, stage: 'light'));
            case SleepStage.deep:
              deep += mins;
              timeline.add(SleepStageInterval(start: cursor, end: segEnd, stage: 'deep'));
            case SleepStage.rem:
              rem += mins;
              timeline.add(SleepStageInterval(start: cursor, end: segEnd, stage: 'rem'));
            case SleepStage.awake:
            case SleepStage.outOfBed:
            case SleepStage.inBed:
              awake += mins;
              timeline.add(SleepStageInterval(start: cursor, end: segEnd, stage: 'awake'));
            case SleepStage.unknown:
              break;
          }
          cursor = segEnd;
        }
        final hasStages = r.samples.isNotEmpty;
        final period = SleepPeriod(
          start: r.startTime,
          end: r.endTime,
          lightMinutes: hasStages ? light : null,
          deepMinutes: hasStages ? deep : null,
          remMinutes: hasStages ? rem : null,
          awakeMinutes: hasStages ? awake : null,
          stageTimeline: timeline,
        );
        debugPrint('[HC]   sleep ${r.startTime.toLocal().hour}:${r.startTime.toLocal().minute.toString().padLeft(2, '0')}'
            '→${r.endTime.toLocal().hour}:${r.endTime.toLocal().minute.toString().padLeft(2, '0')}'
            ' actual=${period.minutes}min'
            '${hasStages ? " (L=$light D=$deep R=$rem A=$awake)" : " (no stages)"}');
        return period;
      }).toList();
      debugPrint('[HC] readSleepSessions [$start → $end]: ${result.length} records');
      return result;
    } catch (e) {
      debugPrint('[HC] readSleepSessions failed: $e');
      return const [];
    }
  }

  @override
  Future<List<HealthSample>> readRestingHeartRate(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final connector = await _getConnector();
      if (connector == null) return const [];
      final response = await connector.readRecords(
        HealthDataType.restingHeartRate.readInTimeRange(
          startTime: start,
          endTime: end,
        ),
      ).timeout(_queryDeadline);
      final result = response.records
          .map((r) => HealthSample(time: r.time, value: r.rate.inPerMinute))
          .toList();
      debugPrint('[HC] readRestingHeartRate [$start → $end]: ${result.length} records');
      return result;
    } catch (e) {
      debugPrint('[HC] readRestingHeartRate failed: $e');
      return const [];
    }
  }

  @override
  Future<List<HealthSample>> readHrvRmssd(DateTime start, DateTime end) async {
    try {
      final connector = await _getConnector();
      if (connector == null) return const [];
      final response = await connector.readRecords(
        HealthDataType.heartRateVariabilityRMSSD.readInTimeRange(
          startTime: start,
          endTime: end,
        ),
      ).timeout(_queryDeadline);
      final result = response.records
          .map((r) => HealthSample(time: r.time, value: r.rmssd.inMilliseconds))
          .toList();
      debugPrint('[HC] readHrvRmssd [$start → $end]: ${result.length} records');
      return result;
    } catch (e) {
      debugPrint('[HC] readHrvRmssd failed: $e');
      return const [];
    }
  }

  @override
  Future<List<HealthSample>> readHeartRateSamples(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final connector = await _getConnector();
      if (connector == null) return const [];
      // heartRateSeries = Android HeartRateRecord (container with BPM samples).
      // heartRate is iOS-only and throws UNSUPPORTED_OPERATION on Health Connect.
      final response = await connector.readRecords(
        HealthDataType.heartRateSeries.readInTimeRange(
          startTime: start,
          endTime: end,
          pageSize: 5000,
        ),
      ).timeout(_hrQueryDeadline);
      final samples = response.records
          .expand(
            (r) => r.samples.map(
              (s) => HealthSample(time: s.time, value: s.rate.inPerMinute),
            ),
          )
          .toList();
      debugPrint('[HC] readHeartRateSamples [$start → $end]: '
          '${response.records.length} series records, ${samples.length} samples');
      return samples;
    } catch (e) {
      debugPrint('[HC] readHeartRateSamples failed: $e');
      return const [];
    }
  }

  @override
  Future<bool> syncWorkoutSession(WorkoutSession session, {String? title}) async {
    try {
      final connector = await _getConnector();
      if (connector == null) return false;

      final sessionStart = session.date;
      final durationMinutes = max(session.duration, 1);
      final sessionEnd = sessionStart.add(Duration(minutes: durationMinutes));
      final segments = _buildSegments(session, sessionStart, sessionEnd);

      final record = ExerciseSessionRecord(
        startTime: sessionStart,
        endTime: sessionEnd,
        exerciseType: ExerciseType.strengthTraining,
        metadata: Metadata.manualEntry(clientRecordId: 'workout_${session.id}'),
        title: title?.isNotEmpty == true ? title : null,
        notes: session.notes?.isNotEmpty == true ? session.notes : null,
        events: segments,
      );

      await connector.writeRecords([record]).timeout(_queryDeadline);
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
    // Collect (segmentType, reps, timestamp, weightKg) for every valid set.
    final allSets = <(ExerciseSegmentType, int, DateTime, double)>[];

    for (final log in session.exercises) {
      final type =
          _segmentTypeMap[log.exerciseId] ?? ExerciseSegmentType.otherWorkout;
      for (final set in log.sets) {
        if (set.reps > 0) {
          allSets.add((type, set.reps, set.timestamp, set.weight));
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
          return (s.$1, s.$2, ts, s.$4);
        })
        .toList();

    // Fall back to evenly-spaced distribution whenever the clamped timestamps
    // would produce an invalid segment layout.  This happens when:
    //   • Timestamps are not fully unique (legacy data, sub-ms resolution, or
    //     multiple sets clamped to the same boundary).
    //   • The last clamped timestamp equals sessionEnd, which makes the final
    //     segment zero-duration (start == end == sessionEnd) — the common case
    //     where exactly one set was logged a few seconds after the stored
    //     duration ended and was clamped to sessionEnd.
    // Zero-duration / overlapping segments cause ExerciseSessionRecord's
    // constructor to throw an ArgumentError, silently aborting the sync.
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
        weight: clampedSets[i].$4 > 0 ? Mass.kilograms(clampedSets[i].$4) : null,
      ));
    }
    return segments;
  }
}
