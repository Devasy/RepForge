import '../../models/models.dart';

/// Returns the [ExerciseLog] for [exerciseId] from the most-recently-dated
/// [WorkoutSession] in [sessions], or `null` if the exercise has never been
/// logged.
///
/// Sessions are sorted by date descending before scanning so the result does
/// not depend on the storage's insertion order. Used by recommendation and
/// "last session" lookups so the two paths never disagree.
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
