import '../../models/models.dart';
import '../../models/skin_temperature_sample.dart';

/// Read-side Health Connect data categories used for readiness scoring.
enum HealthReadType { sleep, heartRate, restingHeartRate, hrv, skinTemperature }

/// Optional capability for platforms that support access beyond 30 days.
abstract interface class IHealthHistoryReadAccess {
  /// Checks existing access without opening a permission prompt.
  Future<bool> hasHistoryReadPermission();
}

abstract class IHealthConnectService {
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<bool> hasPermissions();

  /// Writes [session] to Health Connect.
  ///
  /// [exerciseNames] maps exercise IDs to display names for the session notes,
  /// which is the only place Health Connect can carry per-exercise labels.
  Future<bool> syncWorkoutSession(
    WorkoutSession session, {
    String? title,
    Map<String, String>? exerciseNames,
  });

  /// Requests recovery/analysis read permissions (sleep, HR, resting HR, HRV,
  /// skin temperature). Returns true if at least one was granted — partial
  /// grants are usable because readiness components are independent.
  Future<bool> requestReadPermissions();

  /// The subset of readiness read permissions currently granted.
  Future<Set<HealthReadType>> grantedReadTypes();

  Future<List<SleepPeriod>> readSleepSessions(DateTime start, DateTime end);
  Future<List<HealthSample>> readRestingHeartRate(DateTime start, DateTime end);
  Future<List<HealthSample>> readHrvRmssd(DateTime start, DateTime end);

  /// Raw deltas and optional baseline, as written by the source/bridge app.
  /// Throws on failed reads so sync can retry without advancing its watermark.
  Future<List<SkinTemperatureSample>> readSkinTemperature(
    DateTime start,
    DateTime end,
  );

  /// Raw heart-rate samples. Only used as a morning-RHR fallback over a
  /// narrow window when no [readRestingHeartRate] records exist.
  Future<List<HealthSample>> readHeartRateSamples(DateTime start, DateTime end);
}
