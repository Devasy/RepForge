import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/models/sleep_hr_models.dart';
import 'package:repforge/services/interfaces/health_connect_service_interface.dart';
import 'package:repforge/services/utils/sleep_hr_builder.dart';
import 'test_utils/stub_health_connect_service.dart';

void main() {
  final granted = <HealthReadType>{
    HealthReadType.heartRate,
    HealthReadType.sleep,
    HealthReadType.restingHeartRate,
  };

  group('Sleep & HR Builder Utils', () {
    test('buildHrDaySnapshot returns null when no HR samples or resting HR present', () async {
      const stubHc = StubHcService();
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

      final stubHc = StubHcService(
        hrSamples: [sample1, sample2],
        restingHrSamples: [resting],
      );

      final snapshot = await buildHrDaySnapshot(stubHc, day, granted);

      expect(snapshot, isNotNull);
      expect(snapshot!.minBpm, equals(70));
      expect(snapshot.maxBpm, equals(120));
      expect(snapshot.restingBpm, equals(58));
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

      final stubHc = StubHcService(
        sleepPeriods: [sleepPeriod],
        hrSamples: [hrSample1, hrSample2, hrSample3],
      );

      final snapshot = await buildSleepHrSnapshot(stubHc, DateTime(2026, 7, 23), granted);

      expect(snapshot, isNotNull);
      expect(snapshot!.segments, isNotEmpty);
      expect(snapshot.stageStats, isNotEmpty);

      // Verify representative calculated values in snapshot.segments and snapshot.stageStats
      final deepStats = snapshot.statsFor('deep');
      expect(deepStats, isNotNull);
      expect(deepStats!.stage, equals('deep'));
      expect(deepStats.minBpm, equals(55));
      expect(deepStats.maxBpm, equals(58));
      expect(deepStats.sampleCount, equals(3));

      final firstSegment = snapshot.segments.first;
      expect(firstSegment.stage, equals('deep'));
      expect(firstSegment.minBpm, equals(55));
      expect(firstSegment.maxBpm, equals(58));
    });
  });
}
