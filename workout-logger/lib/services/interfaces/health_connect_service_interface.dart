import '../../models/models.dart';

abstract class IHealthConnectService {
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<bool> hasPermissions();
  Future<bool> syncWorkoutSession(WorkoutSession session);
}
