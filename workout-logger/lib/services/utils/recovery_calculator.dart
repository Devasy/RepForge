// Muscle Recovery Calculator (Single Responsibility Principle)
//
// Pure, stateless per-muscle recovery scoring extracted from MLService.
// Model: recovery(t) = 1 − exp(−t / τ), where t is hours since the last
// session that trained the muscle and τ is a muscle-specific time constant.
// Full recovery (~95%) occurs at ≈ 3τ. Same "pure, no I/O" shape as
// ReadinessCalculator — this is why it lives in utils/, not managers/
// (managers in this codebase are ChangeNotifier state owners).

import 'dart:math';

import '../../models/models.dart';
import '../interfaces/ml_service_interface.dart';

class RecoveryCalculator {
  const RecoveryCalculator();

  // Recovery time constants τ (hours) per muscle group.
  // Full recovery (~95 %) occurs at ≈ 3τ.
  static const _tauHours = <String, double>{
    'chest': 48.0,
    'back': 60.0,
    'lats': 60.0,
    'quads': 60.0,
    'hamstrings': 60.0,
    'glutes': 60.0,
    'legs': 60.0,
    'shoulders': 40.0,
    'traps': 40.0,
    'biceps': 36.0,
    'triceps': 36.0,
    'abs': 24.0,
    'core': 24.0,
    'calves': 24.0,
    'forearms': 24.0,
  };
  static const _defaultTauHours = 48.0;

  /// Compute recovery scores for every muscle group trained in [sessions].
  ///
  /// Model: recovery(t) = 1 − exp(−t / τ)
  ///   t   = hours since last session that trained this muscle
  ///   τ   = muscle-specific time constant (see [_tauHours])
  ///
  /// Full recovery (≥ 95 %) occurs around t = 3τ.
  Map<String, MuscleRecoveryStatus> computeMuscleRecoveryScores(
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap, {
    DateTime? asOf,
  }) =>
      recoveryScoresFrom(
        lastTrainedPerMuscle(sessions, exerciseMap),
        asOf: asOf,
      );

  /// When each muscle group was last trained across [sessions].
  ///
  /// Split out from [computeMuscleRecoveryScores] because this half is the
  /// expensive one — it copies and sorts the whole session list and walks
  /// every session's exercises — and it depends only on the history, not on
  /// the clock. Callers on a hot path (see `WorkoutProvider`) cache this and
  /// re-run only the cheap [recoveryScoresFrom] decay per call.
  Map<String, DateTime> lastTrainedPerMuscle(
    List<WorkoutSession> sessions,
    Map<String, Exercise> exerciseMap,
  ) {
    final sorted = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Walk sessions forward — each one updates the "last trained" record.
    final lastTrained = <String, DateTime>{};
    for (final session in sorted) {
      for (final muscleId in muscleVolumes(session, exerciseMap).keys) {
        lastTrained[muscleId] = session.date;
      }
    }
    return lastTrained;
  }

  /// Applies the recovery decay to a [lastTrainedPerMuscle] result.
  ///
  /// O(muscle groups) and clock-dependent — cheap enough to re-run on every
  /// call even when the [lastTrained] map behind it is cached.
  Map<String, MuscleRecoveryStatus> recoveryScoresFrom(
    Map<String, DateTime> lastTrained, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final result = <String, MuscleRecoveryStatus>{};
    for (final entry in lastTrained.entries) {
      final muscleId = entry.key;
      final tau = _tauHours[muscleId] ?? _defaultTauHours;
      final hours = now.difference(entry.value).inMinutes / 60.0;
      final fraction = (1.0 - exp(-hours / tau)).clamp(0.0, 1.0);
      // 95 % recovery ≈ 3τ; remaining = 3τ − elapsed.
      final hoursRemaining = tau * 3 - hours;

      result[muscleId] = MuscleRecoveryStatus(
        muscleGroupId: muscleId,
        recoveryFraction: fraction,
        timeSinceLastTrained: Duration(minutes: (hours * 60).round()),
        estimatedTimeToFullRecovery: hoursRemaining > 0
            ? Duration(minutes: (hoursRemaining * 60).round())
            : null,
      );
    }
    return result;
  }

  /// Effective volume per muscle group for one session:
  /// sum(exerciseVolume × activationPercentage / 100).
  ///
  /// Public (not `_`-prefixed) so other collaborators — e.g. a same-session
  /// fatigue accumulator — can reuse the same activation-weighting instead
  /// of duplicating this loop.
  Map<String, double> muscleVolumes(
    WorkoutSession session,
    Map<String, Exercise> exerciseMap,
  ) {
    final volumes = <String, double>{};
    for (final log in session.exercises) {
      final exercise = exerciseMap[log.exerciseId];
      if (exercise == null) continue;
      final total = log.totalVolume;
      for (final activation in exercise.muscleActivations) {
        volumes[activation.muscleGroupId] =
            (volumes[activation.muscleGroupId] ?? 0.0) +
                total * activation.activationPercentage / 100.0;
      }
    }
    return volumes;
  }
}
