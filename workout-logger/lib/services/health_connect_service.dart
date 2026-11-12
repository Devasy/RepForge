import 'dart:math' show max;

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:health_connector/health_connector.dart';

import '../models/models.dart' hide ExerciseType;
import '../models/skin_temperature_sample.dart';
import '../models/health_connect_workout.dart';
import 'interfaces/workout_import_health_service.dart';
import 'interfaces/health_connect_service_interface.dart';
import 'utils/hc_session_builder.dart';

class HealthConnectService
    implements IHealthConnectService, IWorkoutImportHealthService {
  HealthConnector? _connector;

  static const _statusDeadline = Duration(seconds: 5);
  static const _queryDeadline = Duration(seconds: 10);
  static const _hrQueryDeadline = Duration(seconds: 20);

  @override
  Future<WorkoutImportAccess> requestWorkoutImportAccess({
    bool includeHistory = false,
  }) async {
    final connector = await _getConnector();
    if (connector == null) throw StateError('Health Connect is not available.');
    final read = HealthDataType.exerciseSession.readPermission;
    final history = HealthPlatformFeature.readHealthDataHistory;
    final canRequestHistory =
        includeHistory &&
        await connector.getFeatureStatus(history) ==
            HealthPlatformFeatureStatus.available;
    await connector.requestPermissions([
      read,
      if (canRequestHistory) history.permission,
    ]);
    return WorkoutImportAccess(
      exerciseGranted:
          await connector.getPermissionStatus(read) == PermissionStatus.granted,
      historyGranted:
          canRequestHistory &&
          await connector.getPermissionStatus(history.permission) ==
              PermissionStatus.granted,
    );
  }

  @override
  Future<List<HealthConnectWorkout>> readFitifyWorkouts(
    DateTime start,
    DateTime end,
  ) async {
    final connector = await _getConnector();
    if (connector == null) throw StateError('Health Connect is not available.');
    var request = HealthDataType.exerciseSession.readInTimeRange(
      startTime: start,
      endTime: end,
      dataOrigins: const [DataOrigin('com.fitifysync.app')],
      pageSize: 100,
    );
    final records = <HealthConnectWorkout>[];
    final tokens = <String>{};
    while (true) {
      final response = await connector
          .readRecords(request)
          .timeout(_queryDeadline);
      for (final record in response.records) {
        final origin = record.metadata.dataOrigin?.packageName;
        if (origin != 'com.fitifysync.app') continue;
        records.add(
          HealthConnectWorkout(
            recordId: record.id.value,
            origin: origin!,
            clientRecordId: record.metadata.clientRecordId,
            version: record.metadata.clientRecordVersion ?? 0,
            start: record.startTime,
            end: record.endTime,
            title: record.title,
            notes: record.notes,
            segments: [
              for (final segment in record.segmentEvents)
                HealthConnectWorkoutSegment(
                  start: segment.startTime,
                  end: segment.endTime,
                  isRest:
                      segment.segmentType == ExerciseSegmentType.rest ||
                      segment.segmentType == ExerciseSegmentType.pause,
                  repetitions: segment.repetitions,
                  weightKg: segment.weight?.inKilograms,
                ),
            ],
          ),
        );
        if (records.length > 2000) {
          throw StateError('Too many workouts. Choose a shorter date range.');
        }
      }
      final next = response.nextPageRequest;
      if (next == null) break;
      request = next;
      if (request.pageToken case final String token) {
        if (!tokens.add(token)) {
          throw StateError(
            'Health Connect repeated a page token; import stopped.',
          );
        }
      }
    }
    return records;
  }

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
      final status = await HealthConnector.getHealthPlatformStatus().timeout(
        _statusDeadline,
      );
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
      final status = await connector
          .getPermissionStatus(HealthDataType.exerciseSession.writePermission)
          .timeout(_statusDeadline);
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
    HealthReadType.skinTemperature:
        HealthDataType.skinTemperatureDeltaSeries.readPermission,
  };

  @override
  Future<bool> requestReadPermissions() async {
    debugPrint(
      '[HC] requestReadPermissions: requesting ${_readPermissions.length} permissions individually',
    );
    final connector = await _getConnector();
    if (connector == null) return false;
    var anyGranted = false;
    for (final entry in _readPermissions.entries) {
      try {
        final results = await connector.requestPermissions([entry.value]);
        final granted = results.any(
          (r) => r.status == PermissionStatus.granted,
        );
        debugPrint(
          '[HC] requestReadPermissions: ${entry.key} → granted=$granted',
        );
        if (granted) anyGranted = true;
      } catch (e) {
        debugPrint(
          '[HC] requestReadPermissions: ${entry.key} unsupported, skipping ($e)',
        );
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
        final status = await connector
            .getPermissionStatus(entry.value)
            .timeout(_statusDeadline);
        debugPrint('[HC] grantedReadTypes: ${entry.key} → $status');
        if (status == PermissionStatus.granted) granted.add(entry.key);
      } catch (e) {
        debugPrint(
          '[HC] grantedReadTypes: ${entry.key} unsupported, skipping ($e)',
        );
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
      final response = await connector
          .readRecords(
            HealthDataType.sleepSession.readInTimeRange(
              startTime: start,
              endTime: end,
            ),
          )
          .timeout(_queryDeadline);
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
              timeline.add(
                SleepStageInterval(start: cursor, end: segEnd, stage: 'light'),
              );
            case SleepStage.deep:
              deep += mins;
              timeline.add(
                SleepStageInterval(start: cursor, end: segEnd, stage: 'deep'),
              );
            case SleepStage.rem:
              rem += mins;
              timeline.add(
                SleepStageInterval(start: cursor, end: segEnd, stage: 'rem'),
              );
            case SleepStage.awake:
            case SleepStage.outOfBed:
            case SleepStage.inBed:
              awake += mins;
              timeline.add(
                SleepStageInterval(start: cursor, end: segEnd, stage: 'awake'),
              );
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
        debugPrint(
          '[HC]   sleep ${r.startTime.toLocal().hour}:${r.startTime.toLocal().minute.toString().padLeft(2, '0')}'
          '→${r.endTime.toLocal().hour}:${r.endTime.toLocal().minute.toString().padLeft(2, '0')}'
          ' actual=${period.minutes}min'
          '${hasStages ? " (L=$light D=$deep R=$rem A=$awake)" : " (no stages)"}',
        );
        return period;
      }).toList();
      debugPrint(
        '[HC] readSleepSessions [$start → $end]: ${result.length} records',
      );
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
      final response = await connector
          .readRecords(
            HealthDataType.restingHeartRate.readInTimeRange(
              startTime: start,
              endTime: end,
            ),
          )
          .timeout(_queryDeadline);
      final result = response.records
          .map((r) => HealthSample(time: r.time, value: r.rate.inPerMinute))
          .toList();
      debugPrint(
        '[HC] readRestingHeartRate [$start → $end]: ${result.length} records',
      );
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
      final response = await connector
          .readRecords(
            HealthDataType.heartRateVariabilityRMSSD.readInTimeRange(
              startTime: start,
              endTime: end,
            ),
          )
          .timeout(_queryDeadline);
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
      final response = await connector
          .readRecords(
            HealthDataType.heartRateSeries.readInTimeRange(
              startTime: start,
              endTime: end,
              pageSize: 5000,
            ),
          )
          .timeout(_hrQueryDeadline);
      final samples = response.records
          .expand(
            (r) => r.samples.map(
              (s) => HealthSample(time: s.time, value: s.rate.inPerMinute),
            ),
          )
          .toList();
      debugPrint(
        '[HC] readHeartRateSamples [$start → $end]: '
        '${response.records.length} series records, ${samples.length} samples',
      );
      return samples;
    } catch (e) {
      debugPrint('[HC] readHeartRateSamples failed: $e');
      return const [];
    }
  }

  @override
  Future<List<SkinTemperatureSample>> readSkinTemperature(
    DateTime start,
    DateTime end,
  ) async {
    final connector = await _getConnector();
    if (connector == null) throw StateError('Health Connect unavailable');
    var response = await connector
        .readRecords(
          HealthDataType.skinTemperatureDeltaSeries.readInTimeRange(
            startTime: start,
            endTime: end,
          ),
        )
        .timeout(_queryDeadline);
    final result = <SkinTemperatureSample>[];
    while (true) {
      result.addAll(mapSkinTemperatureRecords(response.records));
      final next = response.nextPageRequest;
      if (next == null) break;
      response = await connector.readRecords(next).timeout(_queryDeadline);
    }
    return result;
  }

  @visibleForTesting
  static List<SkinTemperatureSample> mapSkinTemperatureRecords(
    List<SkinTemperatureDeltaSeriesRecord> records,
  ) => [
    for (final record in records)
      for (final sample in record.samples)
        SkinTemperatureSample(
          recordId: record.id.value,
          recordStart: record.startTime,
          recordEnd: record.endTime,
          time: sample.time,
          deltaCelsius: sample.temperatureDelta.inCelsius,
          baselineCelsius: record.baseline?.inCelsius,
          sourcePackage: record.metadata.dataOrigin?.packageName ?? '',
          measurementLocation: record.measurementLocation.name,
        ),
  ];

  static bool _segmentWeightUnsupported = false;

  @visibleForTesting
  static void resetSegmentWeightSupport() => _segmentWeightUnsupported = false;

  /// Runs [write] with segment weights, retrying once without them when the
  /// device's Health Connect module predates SDK Extension 21. Without this
  /// the whole session — reps, segments and all — would fail to sync there.
  @visibleForTesting
  static Future<bool> writeWithWeightFallback(
    Future<void> Function({required bool includeWeight}) write,
  ) async {
    try {
      await write(includeWeight: !_segmentWeightUnsupported);
      return true;
    } on UnsupportedOperationException catch (e) {
      if (_segmentWeightUnsupported) {
        debugPrint('[HC] write failed without segment weight: $e');
        return false;
      }
      _segmentWeightUnsupported = true;
      debugPrint('[HC] segment weight unsupported, retrying without it: $e');
      try {
        await write(includeWeight: false);
        return true;
      } catch (retryError) {
        debugPrint('[HC] weightless retry failed: $retryError');
        return false;
      }
    }
  }

  @override
  Future<bool> syncWorkoutSession(
    WorkoutSession session, {
    String? title,
    Map<String, String>? exerciseNames,
  }) async {
    if (session.importSource != null) return false;
    try {
      final connector = await _getConnector();
      if (connector == null) return false;

      final sessionStart = session.date;
      final durationMinutes = max(session.duration, 1);
      final sessionEnd = sessionStart.add(Duration(minutes: durationMinutes));

      Future<void> write({required bool includeWeight}) async {
        final record = ExerciseSessionRecord(
          startTime: sessionStart,
          endTime: sessionEnd,
          exerciseType: ExerciseType.strengthTraining,
          metadata: Metadata.manualEntry(
            clientRecordId: 'workout_${session.id}',
          ),
          title: title?.isNotEmpty == true ? title : null,
          notes: buildHcNotes(
            session: session,
            exerciseNames: exerciseNames ?? const {},
          ),
          events: buildHcSegments(
            session: session,
            sessionStart: sessionStart,
            sessionEnd: sessionEnd,
            includeWeight: includeWeight,
          ),
        );
        await connector.writeRecords([record]).timeout(_queryDeadline);
      }

      return await writeWithWeightFallback(write);
    } catch (e) {
      debugPrint('Health Connect sync failed: $e');
      return false;
    }
  }
}
