// Managers barrel export
//
// Following Single Responsibility Principle, the WorkoutProvider has been
// split into these focused managers:
// - ActiveWorkoutManager: Current workout session state
// - HistoryManager: Past workout sessions
// - RoutineManager: Workout routines
// - ExerciseManager: Exercise library (built-in + custom)
// - TargetManager: Goals and targets
// - AnalyticsManager: Statistics and recommendations

export 'active_workout_manager.dart';
export 'history_manager.dart';
export 'routine_manager.dart';
export 'exercise_manager.dart';
export 'target_manager.dart';
export 'analytics_manager.dart';
export 'program_manager.dart';
export 'health_sync_manager.dart';
export 'pr_manager.dart';
export 'readiness_manager.dart';
