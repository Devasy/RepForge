import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/workout_provider.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/storage_service.dart';

class _FakeWorkoutProvider extends WorkoutProvider {
  _FakeWorkoutProvider() : super(StorageService(), programManager: ProgramManager(StorageService()));

  @override
  List<Exercise> get exercises => [
    Exercise(id: 'ex1', name: 'Bench Press', muscleActivations: [], category: 'compound'),
    Exercise(id: 'ex2', name: 'Squat', muscleActivations: [], category: 'compound'),
  ];

  @override
  List<Routine> get routines => [
    Routine(id: 'r1', name: 'Push Day', exerciseIds: []),
  ];

  @override
  List<WorkoutSession> get workouts => [
    WorkoutSession(
      id: 'w1', 
      routineId: 'r1', 
      date: DateTime.now().subtract(const Duration(days: 1)),
      duration: 60,
      exercises: [
        ExerciseLog(
          exerciseId: 'ex1', 
          sets: [WorkoutSet(reps: 10, weight: 100)]
        )
      ]
    )
  ];
  
  @override
  List<WorkoutSession> get recentWorkouts => workouts;
  
  @override
  Exercise? getExerciseByName(String name) => exercises.firstWhere((e) => e.name == name);
  
  @override
  List<WorkoutSession> getWorkoutsForExercise(String id) => workouts;

  @override
  @override
  Future<Routine> createRoutine(String name, List<String> exerciseIds) async => Routine(id: 'r2', name: name, exerciseIds: exerciseIds);
  
  @override
  Future<Routine> updateRoutine(Routine routine) async => routine;
  @override
  Future<void> addCustomExercise({
    required String name,
    required String category,
    required String primaryMuscleGroupId,
  }) async {}
}

class _FakePRManager extends PRManager {
  _FakePRManager() : super(StorageService());
  
  @override
  List<PersonalRecord> getRecordsForExercise(String id) => [
    PersonalRecord(
      exerciseId: id,
      bestWeight: 100,
      bestReps: 10,
      bestVolume: 1000,
      achievedAt: DateTime.now(),
    )
  ];
}

void main() {
  group('CoachToolService', () {
    late _FakeWorkoutProvider wp;
    late _FakePRManager pr;
    late CoachToolService service;
    
    setUp(() {
      wp = _FakeWorkoutProvider();
      pr = _FakePRManager();
      service = CoachToolService(wp, pr);
    });

    test('exercisePerformance returns data', () {
      final res = service.exercisePerformance({'exercise_name': 'Bench Press', 'limit': 1});
      expect(res, isNotNull);
    });

    test('workoutsInRange returns data', () {
      final res = service.workoutsInRange({'days': 7});
      expect(res, isNotNull);
    });

    test('routinePerformance returns data', () {
      final res = service.routinePerformance({'routine_name': 'Push Day', 'limit': 1});
      expect(res, isNotNull);
    });

    test('personalRecords returns data', () {
      final res = service.personalRecords({'exercise_name': 'Bench Press'});
      expect(res, isNotNull);
    });

    test('goalProgress returns data', () {
      final res = service.goalProgress({});
      expect(res, isNotNull);
    });

    test('muscleRecovery returns data', () {
      final res = service.muscleRecovery();
      expect(res, isNotNull);
    });

    test('getAllRoutines returns data', () {
      final res = service.getAllRoutines();
      expect(res, isNotNull);
    });

    test('createRoutine creates routine', () async {
      final res = await service.createRoutine({
        'name': 'New Routine',
        'exercises': [{'name': 'Bench Press', 'sets': 3, 'reps': 10}],
      });
      expect(res, isNotNull);
    });

    test('updateRoutine updates routine', () async {
      final res = await service.updateRoutine({
        'routine_name': 'Push Day',
        'changes': 'add Squat',
      });
      expect(res, isNotNull);
    });

    test('addCustomExercise adds exercise', () async {
      final res = await service.addCustomExercise({
        'name': 'New Exercise',
        'primary_muscle': 'Chest',
      });
      expect(res, isNotNull);
    });
  });
}
