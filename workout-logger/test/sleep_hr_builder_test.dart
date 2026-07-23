import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/models/sleep_hr_models.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/utils/sleep_hr_builder.dart';

class _StubHcService implements IHealthConnectService {
  final List<SleepPeriod> sleepPeriods;
  final List<HealthSample> hrSamples;
  final List<HealthSample> restingHrSamples;

  _StubHcService({
    this.sleepPeriods = const [],
    this.hrSamples = const [],
    this.restingHrSamples = const [],
  });

  @override
  Future<List<SleepPeriod>> readSleepSessions(DateTime start, DateTime end) async => sleepPeriods;
  @override
  Future<List<HealthSample>> readHeartRateSamples(DateTime start, DateTime end) async => hrSamples;
  @override
  Future<List<HealthSample>> readRestingHeartRate(DateTime start, DateTime end) async => restingHrSamples;
  @override
  Future<Set<HealthReadType>> grantedReadTypes() async => {HealthReadType.heartRate, HealthReadType.sleep};
  @override
  Future<List<HealthSample>> readHrvRmssd(DateTime start, DateTime end) async => const [];
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> hasPermissions() async => true;
  @override
  Future<bool> requestReadPermissions() async => true;
  @override
  Future<bool> syncWorkoutSession(WorkoutSession session, {String? title}) async => true;
}

void main() {
  final granted = <HealthReadType>{HealthReadType.heartRate, HealthReadType.sleep};

  group('Sleep & HR Builder Utils', () {
    test('buildHrDaySnapshot returns null when no HR samples or resting HR present', () async {
      final stubHc = _StubHcService();
      final snapshot = await buildHrDaySnapshot(stubHc, DateTime(2026, 7, 23), granted);

      expect(snapshot, isNull);
    });

    test('buildHrDaySnapshot builds buckets and resting HR for day', () async {
      final day = DateTime(2026, 7, 23);
      final sample1 = HealthSample(
        time: DateTime(2026, 7, 23, 10, 0),
        value: 70.0,
      );
      final sample2 = HealthSample(
        time: DateTime(2026, 7, 23, 10, 15),
        value: 120.0,
      );
      final resting = HealthSample(
        time: DateTime(2026, 7, 23, 8, 0),
        value: 58.0,
      );

      final stubHc = _StubHcService(
        hrSamples: [sample1, sample2],
        restingHrSamples: [resting],
      );

      final snapshot = await buildHrDaySnapshot(stubHc, day, granted);

      expect(snapshot, isNotNull);
      expect(snapshot!.minBpm, equals(70));
      expect(snapshot.maxBpm, equals(120));
      expect(snapshot.buckets, isNotEmpty);
    });

    test('buildSleepHrSnapshot calculates sleep stage stats correctly', () async {
      final sleepStart = DateTime(2026, 7, 23, 1, 0);
      final sleepEnd = DateTime(2026, 7, 23, 7, 0);

      final sleepPeriod = SleepPeriod(
        start: sleepStart,
        end: sleepEnd,
        stageTimeline: [
          SleepStageInterval(start: sleepStart, end: sleepStart.add(const Duration(hours: 2)), stage: 'deep'),
          SleepStageInterval(start: sleepStart.add(const Duration(hours: 2)), end: sleepEnd, stage: 'light'),
        ],
      );

      final hrSample1 = HealthSample(
        time: DateTime(2026, 7, 23, 2, 0),
        value: 55.0,
      );
      final hrSample2 = HealthSample(
        time: DateTime(2026, 7, 23, 2, 3),
        value: 57.0,
      );
      final hrSample3 = HealthSample(
        time: DateTime(2026, 7, 23, 2, 8),
        value: 58.0,
      );

      final stubHc = _StubHcService(
        sleepPeriods: [sleepPeriod],
        hrSamples: [hrSample1, hrSample2, hrSample3],
      );

      final snapshot = await buildSleepHrSnapshot(stubHc, DateTime(2026, 7, 23), granted);

      expect(snapshot, isNotNull);
      expect(snapshot!.segments, isNotEmpty);
      expect(snapshot.stageStats, isNotEmpty);
    });
  });
}
