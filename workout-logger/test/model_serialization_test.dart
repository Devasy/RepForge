import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';

void main() {
  // ── WorkoutSet ────────────────────────────────────────────────────────────

  group('WorkoutSet', () {
    final ts = DateTime(2026, 5, 1, 10, 30);

    test('toJson / fromJson round-trip preserves all fields', () {
      final original = WorkoutSet(
        weight: 80.0,
        reps: 8,
        isDropset: false,
        timeTaken: 45,
        timestamp: ts,
      );
      final restored = WorkoutSet.fromJson(original.toJson());
      expect(restored.weight, original.weight);
      expect(restored.reps, original.reps);
      expect(restored.isDropset, original.isDropset);
      expect(restored.timeTaken, original.timeTaken);
      expect(restored.timestamp, original.timestamp);
    });

    test('volume = weight × reps for a plain set', () {
      final s = WorkoutSet(weight: 100.0, reps: 5, timestamp: ts);
      expect(s.volume, closeTo(500.0, 0.001));
    });

    test('volume includes drop entries for a dropset', () {
      final s = WorkoutSet(
        weight: 60.0,
        reps: 10,
        isDropset: true,
        drops: [DropsetEntry(weight: 40.0, reps: 8)],
        timestamp: ts,
      );
      // 60*10 + 40*8 = 600 + 320 = 920
      expect(s.volume, closeTo(920.0, 0.001));
    });

    test('copyWith changes only the specified field', () {
      final original = WorkoutSet(weight: 60.0, reps: 10, timestamp: ts);
      final copy = original.copyWith(weight: 80.0);
      expect(copy.weight, 80.0);
      expect(copy.reps, original.reps);
      expect(copy.timestamp, original.timestamp);
    });
  });

  // ── ExerciseLog ───────────────────────────────────────────────────────────

  group('ExerciseLog', () {
    final ts = DateTime(2026, 5, 1, 10, 30);

    test('toJson / fromJson round-trip preserves all fields', () {
      final original = ExerciseLog(
        exerciseId: 'bench_press',
        sets: [
          WorkoutSet(weight: 80.0, reps: 8, timestamp: ts),
          WorkoutSet(weight: 80.0, reps: 7, timestamp: ts),
        ],
        notes: 'felt strong',
      );
      final restored = ExerciseLog.fromJson(original.toJson());
      expect(restored.exerciseId, original.exerciseId);
      expect(restored.sets.length, original.sets.length);
      expect(restored.notes, original.notes);
    });

    test('totalVolume sums all sets', () {
      final log = ExerciseLog(
        exerciseId: 'squat',
        sets: [
          WorkoutSet(weight: 100.0, reps: 5, timestamp: ts),
          WorkoutSet(weight: 100.0, reps: 5, timestamp: ts),
          WorkoutSet(weight: 100.0, reps: 5, timestamp: ts),
        ],
      );
      expect(log.totalVolume, closeTo(1500.0, 0.001));
    });

    test('totalVolume is 0 when sets is empty', () {
      final log = ExerciseLog(exerciseId: 'squat', sets: []);
      expect(log.totalVolume, 0.0);
    });

    test('copyWith changes exerciseId and preserves sets', () {
      final ts2 = DateTime(2026, 5, 1, 10, 30);
      final original = ExerciseLog(
        exerciseId: 'squat',
        sets: [WorkoutSet(weight: 60.0, reps: 10, timestamp: ts2)],
      );
      final copy = original.copyWith(exerciseId: 'deadlift');
      expect(copy.exerciseId, 'deadlift');
      expect(copy.sets.length, 1);
    });
  });

  // ── WorkoutSession ────────────────────────────────────────────────────────

  group('WorkoutSession', () {
    final date = DateTime(2026, 5, 10, 8, 0);
    final ts = DateTime(2026, 5, 10, 8, 5);

    test('toJson / fromJson round-trip preserves nested structure', () {
      final original = WorkoutSession(
        id: 'session-1',
        date: date,
        routineId: 'routine-a',
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [WorkoutSet(weight: 80.0, reps: 8, timestamp: ts)],
          ),
        ],
        duration: 45,
        notes: 'good session',
      );
      final restored = WorkoutSession.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.date, original.date);
      expect(restored.routineId, original.routineId);
      expect(restored.exercises.length, 1);
      expect(restored.exercises.first.exerciseId, 'bench_press');
      expect(restored.duration, original.duration);
      expect(restored.notes, original.notes);
    });

    test('totalVolume aggregates across all exercise logs', () {
      final session = WorkoutSession(
        id: 'session-2',
        date: date,
        exercises: [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [WorkoutSet(weight: 80.0, reps: 10, timestamp: ts)], // 800
          ),
          ExerciseLog(
            exerciseId: 'squat',
            sets: [WorkoutSet(weight: 100.0, reps: 10, timestamp: ts)], // 1000
          ),
        ],
        duration: 60,
      );
      expect(session.totalVolume, closeTo(1800.0, 0.001));
    });

    test('copyWith changes date and preserves other fields', () {
      final original = WorkoutSession(
        id: 'session-3',
        date: date,
        exercises: [],
        duration: 30,
      );
      final newDate = DateTime(2026, 6, 1);
      final copy = original.copyWith(date: newDate);
      expect(copy.date, newDate);
      expect(copy.id, original.id);
      expect(copy.duration, original.duration);
    });

    test('hcSyncedAt round-trips correctly when set', () {
      final syncTime = DateTime(2026, 5, 10, 9, 0);
      final original = WorkoutSession(
        id: 'session-4',
        date: date,
        exercises: [],
        duration: 30,
        hcSyncedAt: syncTime,
      );
      final restored = WorkoutSession.fromJson(original.toJson());
      expect(restored.hcSyncedAt, syncTime);
    });
  });

  // ── Exercise ──────────────────────────────────────────────────────────────

  group('Exercise', () {
    test('toJson / fromJson round-trip preserves all fields', () {
      final original = Exercise(
        id: 'cable_fly',
        name: 'Cable Fly',
        category: 'isolation',
        isCustom: true,
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'chest', activationPercentage: 80),
          MuscleActivation(muscleGroupId: 'triceps', activationPercentage: 20),
        ],
      );
      final restored = Exercise.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.category, original.category);
      expect(restored.isCustom, original.isCustom);
      expect(restored.muscleActivations.length, 2);
    });

    test('primaryMuscle returns muscle with highest activationPercentage', () {
      final exercise = Exercise(
        id: 'ex1',
        name: 'Compound Push',
        category: 'compound',
        muscleActivations: [
          MuscleActivation(muscleGroupId: 'chest', activationPercentage: 60),
          MuscleActivation(muscleGroupId: 'shoulders', activationPercentage: 25),
          MuscleActivation(muscleGroupId: 'triceps', activationPercentage: 15),
        ],
      );
      expect(exercise.primaryMuscle, 'chest');
    });

    test('primaryMuscle returns "Unknown" when activations is empty', () {
      final exercise = Exercise(
        id: 'ex2',
        name: 'Mystery',
        category: 'compound',
        muscleActivations: [],
      );
      expect(exercise.primaryMuscle, 'Unknown');
    });
  });

  // ── MuscleGroup ───────────────────────────────────────────────────────────

  group('MuscleGroup', () {
    test('toJson / fromJson round-trip preserves all fields', () {
      final updated = DateTime(2026, 4, 1, 12, 0);
      final original = MuscleGroup(
        id: 'chest',
        name: 'Chest',
        growthRate: 0.15,
        lastUpdated: updated,
      );
      final restored = MuscleGroup.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.growthRate, original.growthRate);
      expect(restored.lastUpdated, original.lastUpdated);
    });
  });

  // ── Target ────────────────────────────────────────────────────────────────

  group('Target', () {
    final created = DateTime(2026, 3, 1);

    test('toJson / fromJson round-trip preserves all fields', () {
      final original = Target(
        id: 't1',
        exerciseId: 'squat',
        targetType: 'weight',
        targetValue: 150.0,
        currentValue: 100.0,
        createdAt: created,
        isCompleted: false,
      );
      final restored = Target.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.exerciseId, original.exerciseId);
      expect(restored.targetType, original.targetType);
      expect(restored.targetValue, original.targetValue);
      expect(restored.currentValue, original.currentValue);
      expect(restored.createdAt, original.createdAt);
      expect(restored.isCompleted, original.isCompleted);
    });

    test('progressPercentage = (current / target) × 100', () {
      final t = Target(
        id: 't2',
        exerciseId: 'squat',
        targetType: 'weight',
        targetValue: 200.0,
        currentValue: 50.0,
      );
      expect(t.progressPercentage, closeTo(25.0, 0.001));
    });

    test('progressPercentage clamps to 100 when current exceeds target', () {
      final t = Target(
        id: 't3',
        exerciseId: 'squat',
        targetType: 'weight',
        targetValue: 100.0,
        currentValue: 150.0,
      );
      expect(t.progressPercentage, closeTo(100.0, 0.001));
    });
  });

  // ── GrowthModel ───────────────────────────────────────────────────────────

  group('GrowthModel', () {
    test('predict(n) = slope * n + intercept', () {
      final model = GrowthModel(
        slope: 2.5,
        intercept: 100.0,
        r2: 0.9,
        lastTrained: DateTime(2026, 1, 1),
      );
      expect(model.predict(0), closeTo(100.0, 0.001));
      expect(model.predict(4), closeTo(110.0, 0.001));
      expect(model.predict(10), closeTo(125.0, 0.001));
    });

    test('predict returns intercept when slope is zero', () {
      final model = GrowthModel(
        slope: 0.0,
        intercept: 80.0,
        r2: 0.0,
        lastTrained: DateTime(2026, 1, 1),
      );
      expect(model.predict(100), closeTo(80.0, 0.001));
    });
  });

  // ── Routine ───────────────────────────────────────────────────────────────

  group('Routine', () {
    test('toJson / fromJson round-trip preserves all fields', () {
      final created = DateTime(2026, 2, 15, 9, 0);
      final original = Routine(
        id: 'r1',
        name: 'Push Day',
        exerciseIds: ['bench_press', 'overhead_press', 'tricep_pushdown'],
        createdAt: created,
      );
      final restored = Routine.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.exerciseIds, original.exerciseIds);
      expect(restored.createdAt, original.createdAt);
    });
  });

  // ── PersonalRecord ────────────────────────────────────────────────────────

  group('PersonalRecord', () {
    final achieved = DateTime(2026, 4, 20);

    test('toJson / fromJson round-trip preserves all fields', () {
      final original = PersonalRecord(
        exerciseId: 'deadlift',
        bestWeight: 180.0,
        bestReps: 5,
        bestVolume: 900.0,
        achievedAt: achieved,
      );
      final restored = PersonalRecord.fromJson(original.toJson());
      expect(restored.exerciseId, original.exerciseId);
      expect(restored.bestWeight, original.bestWeight);
      expect(restored.bestReps, original.bestReps);
      expect(restored.bestVolume, original.bestVolume);
      expect(restored.achievedAt, original.achievedAt);
    });

    test('copyWith changes bestWeight and preserves other fields', () {
      final original = PersonalRecord(
        exerciseId: 'deadlift',
        bestWeight: 160.0,
        bestReps: 5,
        bestVolume: 800.0,
        achievedAt: achieved,
      );
      final updated = original.copyWith(bestWeight: 180.0);
      expect(updated.bestWeight, 180.0);
      expect(updated.bestReps, original.bestReps);
      expect(updated.exerciseId, original.exerciseId);
      expect(updated.achievedAt, original.achievedAt);
    });
  });

  // ── TrainingProgram ───────────────────────────────────────────────────────

  group('TrainingProgram', () {
    ProgramDay makeDay(String id) => ProgramDay(
          id: id,
          name: 'Day $id',
          exercises: [
            ProgramExerciseSlot(
              exerciseId: 'bench_press',
              sets: 4,
              minReps: 6,
              maxReps: 10,
              restSeconds: 120,
            ),
          ],
        );

    ProgramWeek makeWeek(int n, String? phaseId) => ProgramWeek(
          weekNumber: n,
          phaseId: phaseId,
          days: [makeDay('d$n')],
        );

    TrainingPhase makePhase(String id, int start, int end) => TrainingPhase(
          id: id,
          name: 'Phase $id',
          startWeek: start,
          endWeek: end,
        );

    test('toJson / fromJson round-trip preserves nested structure', () {
      final created = DateTime(2026, 1, 1, 0, 0);
      final original = TrainingProgram(
        id: 'prog-1',
        name: '12-Week Block',
        description: 'Hypertrophy focus',
        totalWeeks: 4,
        phases: [makePhase('foundation', 1, 2), makePhase('intensify', 3, 4)],
        weeks: [makeWeek(1, 'foundation'), makeWeek(2, 'foundation'), makeWeek(3, 'intensify'), makeWeek(4, 'intensify')],
        author: 'Coach',
        isImported: false,
        createdAt: created,
      );
      final restored = TrainingProgram.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.totalWeeks, original.totalWeeks);
      expect(restored.phases.length, 2);
      expect(restored.weeks.length, 4);
      expect(restored.author, original.author);
      expect(restored.isImported, original.isImported);
      expect(restored.createdAt, original.createdAt);
    });

    test('phaseForWeek returns the matching phase', () {
      final program = TrainingProgram(
        id: 'p',
        name: 'Test',
        totalWeeks: 4,
        phases: [makePhase('foundation', 1, 2), makePhase('intensify', 3, 4)],
        weeks: [],
      );
      expect(program.phaseForWeek(1)!.id, 'foundation');
      expect(program.phaseForWeek(2)!.id, 'foundation');
      expect(program.phaseForWeek(3)!.id, 'intensify');
      expect(program.phaseForWeek(4)!.id, 'intensify');
    });

    test('phaseForWeek returns null for out-of-range week', () {
      final program = TrainingProgram(
        id: 'p',
        name: 'Test',
        totalWeeks: 4,
        phases: [makePhase('foundation', 1, 4)],
        weeks: [],
      );
      expect(program.phaseForWeek(5), isNull);
    });

    test('totalDays sums days across all weeks', () {
      final program = TrainingProgram(
        id: 'p',
        name: 'Test',
        totalWeeks: 3,
        phases: [],
        weeks: [
          ProgramWeek(weekNumber: 1, days: [makeDay('d1'), makeDay('d2'), makeDay('d3')]),
          ProgramWeek(weekNumber: 2, days: [makeDay('d4'), makeDay('d5')]),
          ProgramWeek(weekNumber: 3, days: [makeDay('d6'), makeDay('d7'), makeDay('d8'), makeDay('d9')]),
        ],
      );
      expect(program.totalDays, 9);
    });

    test('copyWith changes name and preserves other fields', () {
      final original = TrainingProgram(
        id: 'p',
        name: 'Old Name',
        totalWeeks: 4,
        phases: [],
        weeks: [],
      );
      final copy = original.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
      expect(copy.id, original.id);
      expect(copy.totalWeeks, original.totalWeeks);
    });
  });

  // ── ProgramExerciseSlot ───────────────────────────────────────────────────

  group('ProgramExerciseSlot', () {
    test('toJson / fromJson round-trip preserves all fields', () {
      final original = ProgramExerciseSlot(
        exerciseId: 'squat',
        sets: 5,
        minReps: 3,
        maxReps: 5,
        restSeconds: 180,
        tempo: '3-1-1',
        weightPercentage: 85.0,
        notes: 'Stay braced',
        supersetGroupId: 'ss-1',
      );
      final restored = ProgramExerciseSlot.fromJson(original.toJson());
      expect(restored.exerciseId, original.exerciseId);
      expect(restored.sets, original.sets);
      expect(restored.minReps, original.minReps);
      expect(restored.maxReps, original.maxReps);
      expect(restored.restSeconds, original.restSeconds);
      expect(restored.tempo, original.tempo);
      expect(restored.weightPercentage, original.weightPercentage);
      expect(restored.notes, original.notes);
      expect(restored.supersetGroupId, original.supersetGroupId);
    });

    test('copyWith changes sets and preserves other fields', () {
      final original = ProgramExerciseSlot(
        exerciseId: 'squat',
        sets: 4,
        minReps: 6,
        maxReps: 10,
        restSeconds: 120,
      );
      final copy = original.copyWith(sets: 5);
      expect(copy.sets, 5);
      expect(copy.exerciseId, original.exerciseId);
      expect(copy.minReps, original.minReps);
    });
  });
}
