// Unit tests for ReadinessCalculator (pure scoring logic)

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/utils/readiness_calculator.dart';

void main() {
  const calc = ReadinessCalculator();
  final today = DateTime(2026, 6, 10, 8); // 08:00 local

  ReadinessBaseline baseline({
    double? sleep = 420, // 7h average
    int sleepNights = 14,
    double? rhr = 55,
    int rhrDays = 14,
    double? hrv = 60,
    int hrvDays = 14,
  }) =>
      ReadinessBaseline(
        dateKey: '2026-06-10',
        avgSleepMinutes: sleep,
        sleepNights: sleepNights,
        avgRestingHr: rhr,
        rhrDays: rhrDays,
        avgHrvMs: hrv,
        hrvDays: hrvDays,
      );

  group('component formulas', () {
    test('at-baseline values all score 100 and band is high', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(),
        lastNightSleepMinutes: 420,
        todayRestingHr: 55,
        todayHrvMs: 60,
      );
      expect(s.sleepScore, 100);
      expect(s.rhrScore, 100);
      expect(s.hrvScore, 100);
      expect(s.score, 100);
      expect(s.band, ReadinessBand.high);
    });

    test('better-than-baseline values are not rewarded above 100', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(),
        lastNightSleepMinutes: 540, // way over average
        todayRestingHr: 48, // lower (better) than baseline
        todayHrvMs: 90, // higher (better) than baseline
      );
      expect(s.score, 100);
    });

    test('sleep at 75% of average scores 50', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(),
        lastNightSleepMinutes: 315, // 420 * 0.75
      );
      expect(s.sleepScore, 50);
    });

    test('resting HR +10% over baseline scores 50', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(),
        todayRestingHr: 60.5, // 55 * 1.10
      );
      expect(s.rhrScore, 50);
    });

    test('HRV −20% under baseline scores 50', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(),
        todayHrvMs: 48, // 60 * 0.8
      );
      expect(s.hrvScore, 50);
    });

    test('extreme deviations clamp at 0', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(),
        lastNightSleepMinutes: 60,
        todayRestingHr: 90,
        todayHrvMs: 10,
      );
      expect(s.sleepScore, 0);
      expect(s.rhrScore, 0);
      expect(s.hrvScore, 0);
      expect(s.score, 0);
      expect(s.band, ReadinessBand.low);
    });

    test('short absolute sleep is capped even with a short baseline', () {
      // 280 min sleep vs a 290 min average would naively score ~93.
      final s = calc.compute(
        today: today,
        baseline: baseline(sleep: 290),
        lastNightSleepMinutes: 280,
      );
      expect(s.sleepScore, ReadinessCalculator.shortSleepMaxScore);
    });
  });

  group('weighting and partial data', () {
    test('weights renormalize: sleep-only score equals sleep score', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(rhr: null, rhrDays: 0, hrv: null, hrvDays: 0),
        lastNightSleepMinutes: 315, // sleep score 50
      );
      expect(s.score, 50);
      expect(s.rhrScore, isNull);
      expect(s.hrvScore, isNull);
    });

    test('sleep+RHR uses 0.5/0.3 weights renormalized', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(hrv: null, hrvDays: 0),
        lastNightSleepMinutes: 315, // 50
        todayRestingHr: 55, // 100
      );
      // (50*0.5 + 100*0.3) / 0.8 = 68.75 → 69
      expect(s.score, 69);
      expect(s.band, ReadinessBand.moderate);
    });

    test('component with fewer than 5 baseline samples is excluded', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(sleepNights: 4),
        lastNightSleepMinutes: 100, // would tank the score if included
        todayRestingHr: 55,
      );
      expect(s.sleepScore, isNull);
      expect(s.sleepMinutes, isNull);
      expect(s.score, 100); // RHR only
    });

    test('no scorable components yields null score and band', () {
      final s = calc.compute(
        today: today,
        baseline: const ReadinessBaseline(dateKey: '2026-06-10'),
        lastNightSleepMinutes: 400,
      );
      expect(s.score, isNull);
      expect(s.band, isNull);
    });
  });

  group('bands', () {
    test('75 is high and 74 is moderate', () {
      // sleep ratio 0.875 → score 75
      final high = calc.compute(
        today: today,
        baseline: baseline(rhr: null, rhrDays: 0, hrv: null, hrvDays: 0),
        lastNightSleepMinutes: (420 * 0.875).round(),
      );
      expect(high.score, 75);
      expect(high.band, ReadinessBand.high);

      final moderate = calc.compute(
        today: today,
        baseline: baseline(sleep: 400, rhr: null, rhrDays: 0, hrv: null, hrvDays: 0),
        lastNightSleepMinutes: 348, // ratio 0.87 → 74
      );
      expect(moderate.score, 74);
      expect(moderate.band, ReadinessBand.moderate);
    });

    test('49 is low', () {
      final s = calc.compute(
        today: today,
        baseline: baseline(sleep: 480, rhr: null, rhrDays: 0, hrv: null, hrvDays: 0),
        lastNightSleepMinutes: 358, // ratio ~0.746 → 49, above short-sleep cap
      );
      expect(s.score, 49);
      expect(s.band, ReadinessBand.low);
    });
  });

  group('lastNightSleep', () {
    test('sums all periods in the night window (18:00 prev day → 12:00 today)', () {
      final periods = [
        // 90-min nap yesterday afternoon — outside window (ends before 18:00)
        SleepPeriod(
          start: DateTime(2026, 6, 9, 14),
          end: DateTime(2026, 6, 9, 15, 30),
        ),
        // Main sleep 23:00–06:30 = 450 min
        SleepPeriod(
          start: DateTime(2026, 6, 9, 23),
          end: DateTime(2026, 6, 10, 6, 30),
        ),
        // Short morning doze 07:00–07:45 = 45 min (inside window)
        SleepPeriod(
          start: DateTime(2026, 6, 10, 7),
          end: DateTime(2026, 6, 10, 7, 45),
        ),
      ];
      final picked = calc.lastNightSleep(today, periods);
      expect(picked, isNotNull);
      expect(picked!.minutes, 495); // 450 + 45
    });

    test('returns null when nothing overlaps the window', () {
      final periods = [
        SleepPeriod(
          start: DateTime(2026, 6, 7, 23),
          end: DateTime(2026, 6, 8, 7),
        ),
      ];
      expect(calc.lastNightSleep(today, periods), isNull);
    });
  });
}
