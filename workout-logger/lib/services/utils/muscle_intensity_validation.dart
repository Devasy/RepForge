import '../../data/exercise_database.dart';
import '../../models/models.dart';

Map<String, int>? validateMuscleIntensities(Map<String, int>? scores) {
  final validated = Exercise.decodeStretchIntensities(scores);
  if (validated != null &&
      validated.keys.any((id) => !MuscleGroups.names.containsKey(id))) {
    throw ArgumentError('Unknown muscle in intensity scores.');
  }
  return validated;
}

List<MuscleActivation> resistanceActivations(
  Map<String, int> scores,
  String? primary,
) {
  if (scores.isEmpty) return [];
  final largest = scores.entries.reduce((a, b) => b.value > a.value ? b : a);
  final primaryId = primary == null || primary.isEmpty ? largest.key : primary;
  if (scores[primaryId] != largest.value) {
    throw ArgumentError(
      'The primary muscle must have a highest resistance score.',
    );
  }
  return [
    MuscleActivation(
      muscleGroupId: primaryId,
      activationPercentage: scores[primaryId]! * 10,
    ),
    for (final entry in scores.entries)
      if (entry.key != primaryId)
        MuscleActivation(
          muscleGroupId: entry.key,
          activationPercentage: entry.value * 10,
        ),
  ];
}
