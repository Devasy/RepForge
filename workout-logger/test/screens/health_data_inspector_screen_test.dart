import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/screens/health_data_inspector_screen.dart';
import 'package:repforge/services/health_inspector_service.dart';

class _FakeHealthInspectorService extends HealthInspectorService {
  final HealthInspectorInventory inventory;

  _FakeHealthInspectorService(this.inventory);

  @override
  Future<HealthInspectorInventory> inspectHealthData({
    Duration lookback = const Duration(days: 14),
  }) async {
    return inventory;
  }

  @override
  Future<bool> requestAllDiscoveryPermissions() async => true;

  @override
  Future<bool> launchSamsungHealth() async => true;

  @override
  Future<bool> openSamsungHealthSettings() async => true;
}

void main() {
  testWidgets('HealthDataInspectorScreen renders status, stats, and records',
      (tester) async {
    final now = DateTime(2026, 9, 19, 15, 0);
    final inventory = HealthInspectorInventory(
      samsungHealthInfo: const SamsungHealthAppInfo(
        isInstalled: true,
        versionName: '6.30.2.001',
        versionCode: 6302001,
        isEnabled: true,
        appPackageName: 'com.devasy.repforge',
        appSha256Fingerprint: 'AA:BB:CC:DD',
      ),
      isHealthConnectAvailable: true,
      permissionStatus: {'Steps': true, 'Body Fat %': true},
      inspectedAt: now,
      items: [
        HealthRecordItem(
          category: 'Body Composition (BIA)',
          title: 'Body Fat Percentage',
          valueFormatted: '14.2 %',
          rawValue: 14.2,
          unit: '%',
          timestamp: now,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {'device': 'Galaxy Watch 6'},
        ),
        HealthRecordItem(
          category: 'Vitals & Cardiac',
          title: 'Resting Heart Rate',
          valueFormatted: '54 bpm',
          rawValue: 54,
          unit: 'bpm',
          timestamp: now,
          sourcePackage: 'com.sec.android.app.shealth',
        ),
      ],
    );

    final service = _FakeHealthInspectorService(inventory);

    await tester.pumpWidget(
      MaterialApp(
        home: HealthDataInspectorScreen(service: service),
      ),
    );

    // Initial pump and wait for future to resolve
    await tester.pumpAndSettle();

    // Verify title and appbar
    expect(find.text('Wearable & Health Inspector'), findsOneWidget);
    expect(find.text('Samsung Health'), findsWidgets);
    expect(find.text('INSTALLED (v6.30.2.001)'), findsOneWidget);

    // Verify stats
    expect(find.text('2'), findsNWidgets(2)); // Total Types Found & Samsung Health Source count
    expect(find.text('Total Types Found'), findsOneWidget);
    expect(find.text('Samsung Health Source'), findsOneWidget);

    // Verify record tiles
    expect(find.text('Body Fat Percentage'), findsOneWidget);
    expect(find.text('14.2 %'), findsOneWidget);
    expect(find.text('Resting Heart Rate'), findsOneWidget);
    expect(find.text('54 bpm'), findsOneWidget);

    // Verify developer mode toggle guide
    await tester.tap(find.text('Developer Mode Guide'));
    await tester.pumpAndSettle();
    expect(
      find.text('How to Enable Samsung Health Developer Mode:'),
      findsOneWidget,
    );
    expect(find.textContaining('AA:BB:CC:DD'), findsOneWidget);
  });
}
