// Workout HR analysis builder.
//
// Pure function over IHealthConnectService: pulls HR samples for a recorded
// workout window, builds a downsampled curve, and measures HR recovery across
// each rest gap (reconstructed from set timestamps + timeTaken).

import '../../models/models.dart';
import '../../models/workout_hr_models.dart';
import '../interfaces/health_connect_service_interface.dart';

/// Minimum HR drop (bpm) for a rest to count as "recovered".
const int kRestRecoveryThreshold = 5;

/// Minimum HR samples in-window before an analysis is worthwhile.
const int _minSamples = 5;

/// Builds the per-workout HR analysis, or null when HR permission is missing
/// or too few samples cover the workout window.
Future<WorkoutHrAnalysis?> buildWorkoutHrAnalysis(
  IHealthConnectService hc,
  WorkoutSession session,
  Set<HealthReadType> granted,
) async {
  if (!granted.contains(HealthReadType.heartRate)) return null;

  final start = session.date;
  final end = start.add(Duration(minutes: session.duration));

  // Read with a small buffer so set-end peaks near the edges are covered.
  final raw = await hc.readHeartRateSamples(
    start.subtract(const Duration(minutes: 1)),
    end.add(const Duration(minutes: 1)),
  );
  final samples = raw.where((s) => !s.time.isBefore(start) && !s.time.isAfter(end)).toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  if (samples.length < _minSamples) return null;

  final bpms = samples.map((s) => s.value).toList();
  final avg = (bpms.reduce((a, b) => a + b) / bpms.length).round();
  final peak = bpms.reduce((a, b) => a > b ? a : b).round();
  final lo = bpms.reduce((a, b) => a < b ? a : b).round();

  // Curve: 30-second bucket averages.
  final curve = _buildCurve(samples, start);

  // Rest + exercise-section analysis from set timestamps (shared validity gate).
  final valid = _timestampsValid(session, start, end);
  final rests = valid ? _buildRests(session, samples) : const <RestRecovery>[];
  final exercises = valid ? _buildExerciseSpans(session) : const <ExerciseHrSpan>[];

  return WorkoutHrAnalysis(
    start: start,
    end: end,
    avgBpm: avg,
    peakBpm: peak,
    minBpm: lo,
    curve: curve,
    rests: rests,
    exercises: exercises,
    hasRestAnalysis: valid,
  );
}

/// Set timestamps must actually span the session, otherwise they're
/// placeholders (old/imported sessions) and gaps/sections are meaningless.
bool _timestampsValid(WorkoutSession session, DateTime start, DateTime end) {
  final sets = session.exercises.expand((e) => e.sets).toList();
  if (sets.length < 2) return false;
  final ts = sets.map((s) => s.timestamp).toList()..sort();
  if (ts.last.difference(ts.first).inMinutes < 5) return false;
  if (ts.first.isBefore(start.subtract(const Duration(minutes: 5))) ||
      ts.last.isAfter(end.add(const Duration(minutes: 5)))) {
    return false;
  }
  return true;
}

/// One section per exercise, spanning its first set's start to its last set.
List<ExerciseHrSpan> _buildExerciseSpans(WorkoutSession session) {
  final spans = <ExerciseHrSpan>[];
  for (final log in session.exercises) {
    if (log.sets.isEmpty) continue;
    final times = log.sets.map((s) => s.timestamp).toList()..sort();
    final firstSet = log.sets.reduce((a, b) => a.timestamp.isBefore(b.timestamp) ? a : b);
    final start = firstSet.timestamp.subtract(Duration(seconds: firstSet.timeTaken ?? 0));
    spans.add(ExerciseHrSpan(
      exerciseId: log.exerciseId,
      start: start,
      end: times.last,
      setCount: log.sets.length,
    ));
  }
  spans.sort((a, b) => a.start.compareTo(b.start));
  return spans;
}

List<HrCurvePoint> _buildCurve(List<HealthSample> samples, DateTime start) {
  const bucketSec = 30;
  final byBucket = <int, List<double>>{};
  for (final s in samples) {
    final off = s.time.difference(start).inSeconds;
    if (off < 0) continue;
    byBucket.putIfAbsent((off ~/ bucketSec) * bucketSec, () => []).add(s.value);
  }
  final points = <HrCurvePoint>[];
  for (final key in byBucket.keys.toList()..sort()) {
    final vals = byBucket[key]!;
    points.add(HrCurvePoint(
      time: start.add(Duration(seconds: key)),
      bpm: vals.reduce((a, b) => a + b) / vals.length,
    ));
  }
  return points;
}

List<RestRecovery> _buildRests(
  WorkoutSession session,
  List<HealthSample> samples,
) {
  // Flatten all sets across exercises, ordered by timestamp.
  final sets = session.exercises.expand((e) => e.sets).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (sets.length < 2) return const [];

  double? maxIn(DateTime a, DateTime b) {
    final vs = samples
        .where((s) => !s.time.isBefore(a) && !s.time.isAfter(b))
        .map((s) => s.value);
    return vs.isEmpty ? null : vs.reduce((x, y) => x > y ? x : y);
  }

  double? minIn(DateTime a, DateTime b) {
    final vs = samples
        .where((s) => !s.time.isBefore(a) && !s.time.isAfter(b))
        .map((s) => s.value);
    return vs.isEmpty ? null : vs.reduce((x, y) => x < y ? x : y);
  }

  final rests = <RestRecovery>[];
  for (var i = 0; i < sets.length - 1; i++) {
    final a = sets[i];
    final b = sets[i + 1];
    final restStart = a.timestamp;
    // Next set begins after subtracting how long it took to perform.
    final nextStart = b.timestamp.subtract(Duration(seconds: b.timeTaken ?? 0));
    final restEnd = nextStart.isAfter(restStart) ? nextStart : b.timestamp;
    final durSec = restEnd.difference(restStart).inSeconds;
    if (durSec < 5) continue;

    // Peak HR around the set's end; trough during the rest.
    final peak = maxIn(restStart.subtract(const Duration(seconds: 20)),
            restStart.add(const Duration(seconds: 20))) ??
        minIn(restStart, restEnd);
    final trough = minIn(restStart, restEnd);
    if (peak == null || trough == null) continue;

    final recovery = (peak - trough).round();
    rests.add(RestRecovery(
      afterSet: i + 1,
      restStart: restStart,
      durationSec: durSec,
      peakBpm: peak.round(),
      troughBpm: trough.round(),
      recoveryBpm: recovery,
      recovered: recovery >= kRestRecoveryThreshold,
    ));
  }
  return rests;
}
