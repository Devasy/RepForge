import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/sleep_hr_models.dart';

void main() {
  group('Sleep HR Models Test', () {
    test('SleepHrSegment properties', () {
      final now = DateTime.now();
      final segment = SleepHrSegment(
        windowStart: now,
        minBpm: 50,
        maxBpm: 70,
        avgBpm: 60.0,
        stage: 'deep',
      );

      expect(segment.windowStart, equals(now));
      expect(segment.minBpm, equals(50));
      expect(segment.maxBpm, equals(70));
      expect(segment.avgBpm, equals(60.0));
      expect(segment.stage, equals('deep'));
    });

    test('SleepStageStats properties', () {
      final stats = SleepStageStats(
        stage: 'rem',
        minBpm: 55,
        p25Bpm: 60,
        avgBpm: 65.5,
        p75Bpm: 70,
        maxBpm: 80,
        sampleCount: 20,
      );

      expect(stats.stage, equals('rem'));
      expect(stats.minBpm, equals(55));
      expect(stats.p25Bpm, equals(60));
      expect(stats.avgBpm, equals(65.5));
      expect(stats.p75Bpm, equals(70));
      expect(stats.maxBpm, equals(80));
      expect(stats.sampleCount, equals(20));
    });

    test('SleepHrSnapshot statsFor helper method', () {
      final start = DateTime(2026, 1, 1, 23, 0);
      final end = DateTime(2026, 1, 2, 7, 0);

      const deepStats = SleepStageStats(
        stage: 'deep',
        minBpm: 45,
        p25Bpm: 50,
        avgBpm: 52.0,
        p75Bpm: 55,
        maxBpm: 60,
        sampleCount: 15,
      );

      final snapshot = SleepHrSnapshot(
        sleepStart: start,
        sleepEnd: end,
        p5Bpm: 48,
        p95Bpm: 72,
        segments: [],
        stageStats: [deepStats],
      );

      expect(snapshot.statsFor('deep'), equals(deepStats));
      expect(snapshot.statsFor('rem'), isNull);
    });

    test('HealthGranularity extensions', () {
      expect(HealthGranularity.day.label, equals('Day'));
      expect(HealthGranularity.week.label, equals('Week'));
      expect(HealthGranularity.month.label, equals('Month'));
      expect(HealthGranularity.year.label, equals('Year'));
    });

    test('HrBucket JSON roundtrip', () {
      final bucket = HrBucket(
        windowStart: DateTime(2026, 5, 10, 14, 30),
        minBpm: 60,
        maxBpm: 120,
        avgBpm: 85.5,
      );

      final json = bucket.toJson();
      final restored = HrBucket.fromJson(json);

      expect(restored.windowStart, equals(bucket.windowStart));
      expect(restored.minBpm, equals(bucket.minBpm));
      expect(restored.maxBpm, equals(bucket.maxBpm));
      expect(restored.avgBpm, equals(bucket.avgBpm));
    });

    test('HrDaySnapshot JSON roundtrip', () {
      final bucket = HrBucket(
        windowStart: DateTime(2026, 5, 10, 14, 30),
        minBpm: 60,
        maxBpm: 120,
        avgBpm: 85.5,
      );

      final daySnapshot = HrDaySnapshot(
        day: DateTime(2026, 5, 10),
        restingBpm: 58,
        minBpm: 55,
        maxBpm: 145,
        avgBpm: 78.2,
        buckets: [bucket],
      );

      final json = daySnapshot.toJson();
      final restored = HrDaySnapshot.fromJson(json);

      expect(restored.day, equals(daySnapshot.day));
      expect(restored.restingBpm, equals(58));
      expect(restored.minBpm, equals(55));
      expect(restored.maxBpm, equals(145));
      expect(restored.avgBpm, equals(78.2));
      expect(restored.buckets.length, equals(1));
      expect(restored.buckets.first.minBpm, equals(60));
    });

    test('SleepDayBar & HrRangeBar construction', () {
      final bar = SleepDayBar(
        date: DateTime(2026, 6, 1),
        totalMinutes: 480,
        deepMin: 90,
        remMin: 110,
        lightMin: 250,
        awakeMin: 30,
      );

      expect(bar.totalMinutes, equals(480));
      expect(bar.deepMin, equals(90));

      final hrRange = HrRangeBar(
        date: DateTime(2026, 6, 1),
        label: 'Mon',
        minBpm: 50,
        maxBpm: 130,
        avgBpm: 72.0,
        restingBpm: 54,
      );

      expect(hrRange.label, equals('Mon'));
      expect(hrRange.restingBpm, equals(54));
    });
  });
}
