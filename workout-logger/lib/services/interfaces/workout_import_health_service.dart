import '../../models/health_connect_workout.dart';

class WorkoutImportAccess {
  const WorkoutImportAccess({
    required this.exerciseGranted,
    required this.historyGranted,
  });
  final bool exerciseGranted;
  final bool historyGranted;
}

abstract interface class IWorkoutImportHealthService {
  Future<WorkoutImportAccess> requestWorkoutImportAccess({
    bool includeHistory = false,
  });
  Future<List<HealthConnectWorkout>> readFitifyWorkouts(
    DateTime start,
    DateTime end,
  );
}
