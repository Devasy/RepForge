import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';
import 'test_utils/mock_storage_service.dart';
import 'test_utils/mock_ml_service.dart';

void main() {
  late MockStorageService storage;
  late WorkoutProvider provider;
  late ProgramManager manager;
  late TrainingProgram program;
  setUp(() async {
    storage = MockStorageService();
    manager = ProgramManager(storage);
    provider = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: manager,
    );
    await provider.init();
    program = TrainingProgram(
      id: 'p',
      name: 'Plan',
      totalWeeks: 2,
      phases: [],
      weeks: [
        for (var week = 1; week <= 2; week++)
          ProgramWeek(
            weekNumber: week,
            days: [
              ProgramDay(
                id: 'same-day',
                name: 'Strength',
                exercises: [
                  ProgramExerciseSlot(
                    exerciseId: 'bench_press',
                    sets: 3,
                    minReps: 8,
                    maxReps: 10,
                    restSeconds: 90,
                  ),
                ],
              ),
            ],
          ),
      ],
    );
    await manager.saveProgram(program);
  });
  test(
    'follow survives restart; saved workout advances exact week/day only',
    () async {
      await manager.followProgram(program.id);
      final next = manager.nextWorkout(program, provider.sessions)!;
      provider.startWorkout(
        programId: program.id,
        programWeek: next.week,
        programDay: next.day,
        exerciseIds: ['bench_press'],
      );
      provider.addSet(WorkoutSet(weight: 40, reps: 8));
      final session = await provider.finishWorkout();
      expect(
        WorkoutSession.fromJson(
          session.toJson(),
        ).copyWith(notes: 'edited').programId,
        program.id,
      );
      final restored = ProgramManager(storage);
      await restored.loadPrograms();
      expect(restored.followedProgram?.id, program.id);
      expect(
        restored
            .nextWorkout(program, await storage.getAllWorkoutSessions())!
            .week
            .weekNumber,
        2,
      );
      await provider.deleteWorkoutSession(session.id);
      expect(
        manager.nextWorkout(program, provider.sessions)!.week.weekNumber,
        1,
      );
    },
  );
  test('cancelled or empty workout does not complete a day', () async {
    await manager.followProgram(program.id);
    provider.startWorkout(
      programId: program.id,
      programWeek: program.weeks.first,
      programDay: program.weeks.first.days.first,
      exerciseIds: ['bench_press'],
    );
    await provider.cancelWorkout();
    expect(manager.nextWorkout(program, provider.sessions)!.week.weekNumber, 1);
    provider.startWorkout(
      programId: program.id,
      programWeek: program.weeks.first,
      programDay: program.weeks.first.days.first,
      exerciseIds: ['bench_press'],
    );
    await provider.finishWorkout();
    expect(manager.nextWorkout(program, provider.sessions)!.week.weekNumber, 1);
  });
  test(
    'failed session save leaves next day and active workout unchanged',
    () async {
      await manager.followProgram(program.id);
      storage.saveWorkoutSessionErrorResolver = (_) =>
          StateError('save failed');
      provider.startWorkout(
        programId: program.id,
        programWeek: program.weeks.first,
        programDay: program.weeks.first.days.first,
        exerciseIds: ['bench_press'],
      );
      provider.addSet(WorkoutSet(weight: 40, reps: 8));
      await expectLater(provider.finishWorkout(), throwsStateError);
      expect(provider.hasActiveWorkout, isTrue);
      expect(
        manager.nextWorkout(program, provider.sessions)!.week.weekNumber,
        1,
      );
      await provider.cancelWorkout();
    },
  );
  test('failed following choice preserves previous selection', () async {
    await manager.followProgram(program.id);
    storage.saveSettingErrorResolver = (_, _) => StateError('save failed');
    await expectLater(manager.followProgram(null), throwsStateError);
    expect(manager.followedProgram?.id, program.id);
  });
  test(
    'draft resumes original program even after following another plan',
    () async {
      await manager.followProgram(program.id);
      provider.startWorkout(
        programId: program.id,
        programWeek: program.weeks.first,
        programDay: program.weeks.first.days.first,
        exerciseIds: ['bench_press'],
      );
      provider.addSet(WorkoutSet(weight: 40, reps: 8));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final restored = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      await restored.init();
      expect(restored.activeProgramId, program.id);
      await restored.finishWorkout();
      expect(
        manager.nextWorkout(program, restored.sessions)!.week.weekNumber,
        2,
      );
    },
  );
}
