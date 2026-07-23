import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/health_connect_service.dart';
import '../test_utils/test_fixtures.dart';

void main() {
  testWidgets('HealthConnectService reports unavailable gracefully in unit tests', (WidgetTester tester) async {
    final service = HealthConnectService();
    final available = await service.isAvailable();
    expect(available, isFalse);
  });

  testWidgets('HealthConnectService returns false for permissions check on unsupported desktop test environment', (WidgetTester tester) async {
    final service = HealthConnectService();
    final hasPerms = await service.hasPermissions();
    expect(hasPerms, isFalse);

    final reqPerms = await service.requestPermissions();
    expect(reqPerms, isFalse);

    final reqReadPerms = await service.requestReadPermissions();
    expect(reqReadPerms, isFalse);

    final grantedTypes = await service.grantedReadTypes();
    expect(grantedTypes, isEmpty);
  });

  testWidgets('HealthConnectService syncWorkoutSession returns false gracefully on missing platform channel', (WidgetTester tester) async {
    final service = HealthConnectService();
    final session = TestFixtures.sampleSession();
    final success = await service.syncWorkoutSession(session);
    expect(success, isFalse);
  });

  testWidgets('HealthConnectService read methods return empty lists when plugin unavailable', (WidgetTester tester) async {
    final service = HealthConnectService();
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 1));

    final sleep = await service.readSleepSessions(start, now);
    expect(sleep, isEmpty);

    final rhr = await service.readRestingHeartRate(start, now);
    expect(rhr, isEmpty);

    final hrv = await service.readHrvRmssd(start, now);
    expect(hrv, isEmpty);

    final hr = await service.readHeartRateSamples(start, now);
    expect(hr, isEmpty);
  });
}
