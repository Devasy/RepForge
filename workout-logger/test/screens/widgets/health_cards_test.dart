import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/models/sleep_hr_models.dart';
import 'package:repforge/screens/widgets/heart_rate_card.dart';
import 'package:repforge/screens/widgets/readiness_card.dart';
import 'package:repforge/screens/widgets/sleep_hr_card.dart';
import 'package:repforge/services/interfaces/readiness_manager_interface.dart';
import 'package:repforge/services/managers/readiness_manager.dart';
import '../../test_utils/mock_storage_service.dart';
import '../../test_utils/stub_health_connect_service.dart';
import '../../test_utils/test_harness.dart';
import 'package:repforge/services/settings_provider.dart';

class FakeReadinessManager extends ReadinessManager {
  FakeReadinessManager(SettingsProvider settings)
      : super(const StubHcService(), MockStorageService(), settings);

  ReadinessStatus _mockStatus = ReadinessStatus.ready;
  ReadinessSnapshot? _mockSnapshot;
  SleepHrSnapshot? _mockSleepHrSnapshot;
  HrDaySnapshot? _mockHrDaySnapshot;

  void setMockData({
    ReadinessStatus status = ReadinessStatus.ready,
    ReadinessSnapshot? snapshot,
    SleepHrSnapshot? sleepHrSnapshot,
    HrDaySnapshot? hrDaySnapshot,
  }) {
    _mockStatus = status;
    _mockSnapshot = snapshot;
    _mockSleepHrSnapshot = sleepHrSnapshot;
    _mockHrDaySnapshot = hrDaySnapshot;
    notifyListeners();
  }

  @override
  ReadinessStatus get status => _mockStatus;

  @override
  ReadinessSnapshot? get snapshot => _mockSnapshot;

  @override
  SleepHrSnapshot? get sleepHrSnapshot => _mockSleepHrSnapshot;

  @override
  HrDaySnapshot? get hrDaySnapshot => _mockHrDaySnapshot;
}

void main() {
  late MockStorageService storage;
  late SettingsProvider settings;
  late FakeReadinessManager readinessManager;

  setUp(() async {
    storage = MockStorageService();
    settings = SettingsProvider(storage);
    await settings.init();
    readinessManager = FakeReadinessManager(settings);
  });

  Widget wrapWithReadiness(Widget child) {
    return TestHarness.wrap(
      child,
      storage: storage,
      settingsProvider: settings,
      readinessManager: readinessManager,
    );
  }

  testWidgets('Renders ReadinessCard when snapshot score is present', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    readinessManager.setMockData(
      status: ReadinessStatus.ready,
      snapshot: ReadinessSnapshot(
        dateKey: '2026-05-10',
        score: 85,
        band: ReadinessBand.high,
      ),
    );

    await tester.pumpWidget(wrapWithReadiness(const ReadinessCard()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(ReadinessCard), findsOneWidget);
  });

  testWidgets('Renders SleepHrCard when sleepHrSnapshot is present', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final now = DateTime(2026, 5, 10);
    final snapshot = SleepHrSnapshot(
      sleepStart: now.subtract(const Duration(hours: 8)),
      sleepEnd: now,
      p5Bpm: 52,
      p95Bpm: 82,
      segments: [
        SleepHrSegment(
          windowStart: now.subtract(const Duration(hours: 4)),
          minBpm: 55,
          maxBpm: 65,
          avgBpm: 60,
          stage: 'deep',
        ),
      ],
      stageStats: [
        const SleepStageStats(
          stage: 'deep',
          minBpm: 52,
          p25Bpm: 55,
          avgBpm: 58,
          p75Bpm: 62,
          maxBpm: 70,
          sampleCount: 20,
        ),
      ],
    );

    readinessManager.setMockData(
      status: ReadinessStatus.ready,
      sleepHrSnapshot: snapshot,
    );

    await tester.pumpWidget(wrapWithReadiness(const SleepHrCard()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(SleepHrCard), findsOneWidget);

    // Tap SleepHrCard to trigger sheet opening
    await tester.tap(find.byType(SleepHrCard));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Renders HeartRateCard when hrDaySnapshot is present', (WidgetTester tester) async {
    await TestHarness.prepareTester(tester);

    final now = DateTime(2026, 5, 10);
    final snapshot = HrDaySnapshot(
      day: now,
      minBpm: 50,
      maxBpm: 155,
      avgBpm: 72,
      restingBpm: 54,
      buckets: [
        HrBucket(
          windowStart: now.subtract(const Duration(hours: 2)),
          minBpm: 60,
          maxBpm: 80,
          avgBpm: 70,
        ),
      ],
    );

    readinessManager.setMockData(
      status: ReadinessStatus.ready,
      hrDaySnapshot: snapshot,
    );

    await tester.pumpWidget(wrapWithReadiness(const HeartRateCard()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(HeartRateCard), findsOneWidget);

    // Tap HeartRateCard to test navigation
    await tester.tap(find.byType(HeartRateCard));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
