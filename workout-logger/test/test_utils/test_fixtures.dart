// test_fixtures.dart — Reusable mock data generators for unit and widget tests.

import 'package:repforge/models/models.dart';

class TestFixtures {
  /// Generates a sample [WorkoutSession] with customizable parameters.
  static WorkoutSession sampleSession({
    String id = 'session_fixture_1',
    DateTime? date,
    int duration = 45,
    String? notes = 'Sample session notes',
    List<ExerciseLog>? exercises,
  }) {
    final sessionDate = date ?? DateTime(2026, 5, 10, 10, 0);
    return WorkoutSession(
      id: id,
      date: sessionDate,
      duration: duration,
      notes: notes,
      exercises: exercises ??
          [
            ExerciseLog(
              exerciseId: 'bench_press',
              sets: [
                WorkoutSet(weight: 80.0, reps: 10, timestamp: sessionDate.add(const Duration(minutes: 5))),
                WorkoutSet(weight: 85.0, reps: 8, timestamp: sessionDate.add(const Duration(minutes: 10))),
              ],
              notes: 'Pushed hard on last set',
            ),
            ExerciseLog(
              exerciseId: 'squats',
              sets: [
                WorkoutSet(weight: 120.0, reps: 5, timestamp: sessionDate.add(const Duration(minutes: 20))),
              ],
            ),
          ],
    );
  }

  /// Generates a sample [Routine] with customizable parameters.
  static Routine sampleRoutine({
    String id = 'routine_fixture_1',
    String name = 'Upper Body Power',
    List<String>? exerciseIds,
  }) {
    return Routine(
      id: id,
      name: name,
      exerciseIds: exerciseIds ?? ['bench_press', 'barbell_row', 'overhead_press'],
    );
  }

  /// Generates a sample [TrainingProgram] with customizable parameters.
  static TrainingProgram sampleProgram({
    String id = 'program_fixture_1',
    String name = 'Hypertrophy 12-Week',
    int totalWeeks = 12,
  }) {
    return TrainingProgram(
      id: id,
      name: name,
      totalWeeks: totalWeeks,
      weeks: const [],
      phases: const [],
    );
  }

  /// Generates sample [SleepPeriod] records for health charts.
  static List<SleepPeriod> sampleSleepPeriods({DateTime? anchorDate}) {
    final anchor = anchorDate ?? DateTime(2026, 5, 10);
    return [
      SleepPeriod(
        start: anchor.subtract(const Duration(hours: 8)),
        end: anchor,
        deepMinutes: 120,
        remMinutes: 90,
        lightMinutes: 240,
        awakeMinutes: 30,
      ),
    ];
  }

  /// Generates sample heart rate [HealthSample] records.
  static List<HealthSample> sampleHeartRateSamples({DateTime? anchorDate}) {
    final anchor = anchorDate ?? DateTime(2026, 5, 10);
    return List.generate(
      12,
      (i) => HealthSample(
        time: anchor.subtract(Duration(hours: 12 - i)),
        value: 60.0 + (i * 3 % 25),
      ),
    );
  }
}
