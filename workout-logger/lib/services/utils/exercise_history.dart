import '../../models/models.dart';
import '../interfaces/ml_service_interface.dart';

/// Returns the [ExerciseLog] for [exerciseId] from the most-recently-dated
/// [WorkoutSession] in [sessions], or `null` if the exercise has never been
/// logged.
///
/// Sessions are sorted by date descending before scanning so the result does
/// not depend on the storage's insertion order. Used by recommendation and
/// "last session" lookups so the two paths never disagree.
///
/// Tie-break: when two sessions share the exact same [WorkoutSession.date],
/// the choice between them is unspecified. `List.sort` is not stable in Dart,
/// so callers must not rely on a deterministic winner for equal timestamps.
ExerciseLog? findMostRecentExerciseLog(
  String exerciseId,
  List<WorkoutSession> sessions,
) {
  final sorted = List<WorkoutSession>.from(sessions)
    ..sort((a, b) => b.date.compareTo(a.date));

  for (final session in sorted) {
    for (final log in session.exercises) {
      if (log.exerciseId == exerciseId) {
        return log;
      }
    }
  }
  return null;
}

/// Recovery-related inputs for [IMLService.recommendSets]: per-muscle
/// recovery scores across [sessions], and [exerciseId]'s primary muscle.
///
/// Centralizes what both `WorkoutProvider.getRecommendations` and
/// `AnalyticsManager.getRecommendations` need to assemble so the two call
/// sites can't drift out of sync with each other again (they previously did
/// — see the recommendation-engine-upgrade plan's audit item 6). Returns
/// nulls when [exerciseMap] doesn't resolve [exerciseId], so callers that
/// don't have exercise data on hand degrade to the pre-recovery-aware
/// behavior instead of erroring.
/// Pass [lastTrained] (from [IMLService.lastTrainedPerMuscle]) when the
/// caller already holds a cached one — callers on a per-frame path do, and
/// it skips re-sorting and re-walking every session here. Omitting it
/// computes the same thing from [sessions].
({Map<String, MuscleRecoveryStatus>? recoveryScores, List<String>? primaryMuscleIds})
    recoveryRecommendationInputs({
  required String exerciseId,
  required List<WorkoutSession> sessions,
  required Map<String, Exercise> exerciseMap,
  required IMLService mlService,
  Map<String, DateTime>? lastTrained,
}) {
  final exercise = exerciseMap[exerciseId];
  if (exercise == null) {
    return (recoveryScores: null, primaryMuscleIds: null);
  }
  return (
    recoveryScores: lastTrained != null
        ? mlService.recoveryScoresFrom(lastTrained)
        : mlService.computeMuscleRecoveryScores(sessions, exerciseMap),
    primaryMuscleIds: [exercise.primaryMuscle],
  );
}
