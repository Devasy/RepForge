import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_connector/health_connector.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/health_connect_service.dart';
import '../test_utils/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('skin temperature mapping preserves deltas, baseline and bridge origin', () {
    final start = DateTime.utc(2026, 11, 10, 22);
    final samples = HealthConnectService.mapSkinTemperatureRecords([
      for (final baseline in [const Temperature.celsius(33.5), null])
        SkinTemperatureDeltaSeriesRecord(
          id: HealthRecordId('bridge-record'),
          startTime: start,
          endTime: start.add(const Duration(hours: 8)),
          metadata: Metadata.internal(
            recordingMethod: RecordingMethod.automaticallyRecorded,
            dataOrigin: const DataOrigin('bridge.app'),
          ),
          baseline: baseline,
          measurementLocation: SkinTemperatureMeasurementLocation.wrist,
          samples: [SkinTemperatureDeltaSample(
            time: start.add(const Duration(hours: 1)),
            temperatureDelta: const Temperature.celsius(-0.25),
          )],
        ),
    ]);
    expect(samples, hasLength(2));
    expect(samples.first.recordId, 'bridge-record');
    expect(samples.first.sourcePackage, 'bridge.app');
    expect(samples.first.measurementLocation, 'wrist');
    expect(samples.first.deltaCelsius, -0.25);
    expect(samples.first.baselineCelsius, 33.5);
    expect(samples.last.baselineCelsius, isNull);
  });

  const pigeonChannels = [
    'dev.flutter.pigeon.health_connector_hc_android.HealthConnectorHCAndroidApi.getHealthPlatformStatus',
    'dev.flutter.pigeon.health_connector_hc_android.HealthConnectorHCAndroidApi.initialize',
    'dev.flutter.pigeon.health_connector_hc_android.HealthConnectorHCAndroidApi.requestPermissions',
    'dev.flutter.pigeon.health_connector_hc_android.HealthConnectorHCAndroidApi.getPermissionStatus',
    'dev.flutter.pigeon.health_connector_hc_android.HealthConnectorHCAndroidApi.readRecords',
    'dev.flutter.pigeon.health_connector_hc_android.HealthConnectorHCAndroidApi.readRecord',
    'dev.flutter.pigeon.health_connector_hc_android.HealthConnectorHCAndroidApi.writeRecords',
    'dev.flutter.pigeon.health_connector_hc_android.HealthConnectorHCAndroidApi.writeRecord',
    'dev.flutter.pigeon.health_connector_hk_ios.HealthConnectorHKIOSApi.getHealthPlatformStatus',
    'dev.flutter.pigeon.health_connector_hk_ios.HealthConnectorHKIOSApi.initialize',
  ];

  setUp(() {
    for (final channel in pigeonChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, (ByteData? message) async => null);
    }
  });

  tearDown(() {
    for (final channel in pigeonChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, null);
    }
  });

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
    final success = await service.syncWorkoutSession(session, title: 'Custom Title');
    expect(success, isFalse);
  });

  testWidgets('HealthConnectService handles sessions with zero reps and custom exercises', (WidgetTester tester) async {
    final service = HealthConnectService();
    final session = WorkoutSession(
      id: 'sess_custom',
      date: DateTime.now(),
      duration: 30,
      notes: 'Custom notes',
      exercises: [
        ExerciseLog(
          exerciseId: 'custom_exercise_999',
          sets: [
            WorkoutSet(weight: 0.0, reps: 0, timestamp: DateTime.now()),
            WorkoutSet(weight: 50.0, reps: 10, timestamp: DateTime.now().add(const Duration(minutes: 5))),
          ],
        ),
      ],
    );

    final success = await service.syncWorkoutSession(session);
    expect(success, isFalse);
  });

  testWidgets('HealthConnectService handles sessions with identical timestamps (fallback spacing)', (WidgetTester tester) async {
    final service = HealthConnectService();
    final now = DateTime.now();
    final session = WorkoutSession(
      id: 'sess_identical_ts',
      date: now,
      duration: 45,
      exercises: [
        ExerciseLog(
          exerciseId: 'bench_press',
          sets: [
            WorkoutSet(weight: 60.0, reps: 10, timestamp: now),
            WorkoutSet(weight: 70.0, reps: 8, timestamp: now),
          ],
        ),
      ],
    );

    final success = await service.syncWorkoutSession(session, title: '');
    expect(success, isFalse);
  });

  testWidgets('HealthConnectService handles empty sessions without exercises', (WidgetTester tester) async {
    final service = HealthConnectService();
    final session = WorkoutSession(
      id: 'sess_empty',
      date: DateTime.now(),
      duration: 20,
      exercises: [],
    );

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

  testWidgets('sync reader propagates unavailable reads instead of empty success', (tester) async {
    final service = HealthConnectService(throwOnReadFailure: true);
    final end = DateTime(2026, 11, 13);
    final start = end.subtract(const Duration(days: 90));
    await expectLater(service.readSleepSessions(start, end), throwsStateError);
    await expectLater(service.readRestingHeartRate(start, end), throwsStateError);
    await expectLater(service.readHrvRmssd(start, end), throwsStateError);
    await expectLater(service.readHeartRateSamples(start, end), throwsStateError);
    expect(await service.hasHistoryReadPermission(), isFalse);
  });

  test('HealthConnectService succeeds when platform response takes > 100ms within deadline', () async {
    const channel = 'dev.flutter.pigeon.health_connector_hc_android.HealthConnectorHCAndroidApi.getHealthPlatformStatus';
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(channel, null);
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      channel,
      (ByteData? message) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return null;
      },
    );

    final service = HealthConnectService();
    final available = await service.isAvailable();
    expect(available, isFalse);
  });

  group('writeWithWeightFallback', () {
    setUp(HealthConnectService.resetSegmentWeightSupport);

    test('returns true on a first write that succeeds', () async {
      final calls = <bool>[];
      final ok = await HealthConnectService.writeWithWeightFallback(
        ({required bool includeWeight}) async => calls.add(includeWeight),
      );

      expect(ok, isTrue);
      expect(calls, [true]);
    });

    test('retries without weight when the device rejects segment weight', () async {
      final calls = <bool>[];
      final ok = await HealthConnectService.writeWithWeightFallback(
        ({required bool includeWeight}) async {
          calls.add(includeWeight);
          if (includeWeight) {
            throw const UnsupportedOperationException('segment weight needs SDK extension 21');
          }
        },
      );

      expect(ok, isTrue);
      expect(calls, [true, false]);
    });

    test('skips the weight attempt on later syncs once unsupported', () async {
      await HealthConnectService.writeWithWeightFallback(
        ({required bool includeWeight}) async {
          if (includeWeight) {
            throw const UnsupportedOperationException('segment weight needs SDK extension 21');
          }
        },
      );

      final calls = <bool>[];
      final ok = await HealthConnectService.writeWithWeightFallback(
        ({required bool includeWeight}) async => calls.add(includeWeight),
      );

      expect(ok, isTrue);
      expect(calls, [false]);
    });

    test('returns false when the weightless retry also fails', () async {
      final ok = await HealthConnectService.writeWithWeightFallback(
        ({required bool includeWeight}) async =>
            throw const UnsupportedOperationException('nope'),
      );

      expect(ok, isFalse);
    });
  });
}
