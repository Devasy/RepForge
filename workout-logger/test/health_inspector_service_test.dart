import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/health_inspector_service.dart';

void main() {
  group('SamsungHealthAppInfo Tests', () {
    test('empty factory creates uninstalled state', () {
      final info = SamsungHealthAppInfo.empty();
      expect(info.isInstalled, isFalse);
      expect(info.versionName, isEmpty);
      expect(info.versionCode, 0);
      expect(info.isEnabled, isFalse);
      expect(info.appPackageName, isEmpty);
      expect(info.appSha256Fingerprint, isEmpty);
      expect(info.services, isEmpty);
      expect(info.providers, isEmpty);
    });

    test('fromMap parses diagnostics map correctly', () {
      final map = {
        'installed': true,
        'versionName': '6.30.2.001',
        'versionCode': 6302001,
        'enabled': true,
        'appPackageName': 'com.devasy.repforge',
        'appSha256Fingerprint': 'AB:CD:EF:12:34',
        'services': ['com.sec.android.app.shealth.ServiceA'],
        'providers': ['com.sec.android.app.shealth.ProviderA'],
      };
      final info = SamsungHealthAppInfo.fromMap(map);
      expect(info.isInstalled, isTrue);
      expect(info.versionName, '6.30.2.001');
      expect(info.versionCode, 6302001);
      expect(info.isEnabled, isTrue);
      expect(info.appPackageName, 'com.devasy.repforge');
      expect(info.appSha256Fingerprint, 'AB:CD:EF:12:34');
      expect(info.services, hasLength(1));
      expect(info.providers, hasLength(1));
    });
  });

  group('HealthRecordItem Tests', () {
    test('detects Samsung Health package origin correctly', () {
      final sHealthItem = HealthRecordItem(
        category: 'Body Composition (BIA)',
        title: 'Body Fat Percentage',
        valueFormatted: '14.5 %',
        rawValue: 14.5,
        unit: '%',
        timestamp: DateTime(2026, 9, 19, 10, 0),
        sourcePackage: 'com.sec.android.app.shealth',
      );
      expect(sHealthItem.isFromSamsungHealth, isTrue);
      expect(sHealthItem.sourceDisplayName, 'Samsung Health');

      final googleFitItem = HealthRecordItem(
        category: 'Activity',
        title: 'Steps',
        valueFormatted: '8,000 steps',
        rawValue: 8000,
        timestamp: DateTime(2026, 9, 19, 10, 0),
        sourcePackage: 'com.google.android.apps.fitness',
      );
      expect(googleFitItem.isFromSamsungHealth, isFalse);
      expect(googleFitItem.sourceDisplayName, 'Google Fit');

      final unknownItem = HealthRecordItem(
        category: 'Vitals',
        title: 'Heart Rate',
        valueFormatted: '60 bpm',
        rawValue: 60,
        timestamp: DateTime(2026, 9, 19, 10, 0),
        sourcePackage: null,
      );
      expect(unknownItem.isFromSamsungHealth, isFalse);
      expect(unknownItem.sourceDisplayName, 'Local / Unknown');
    });

    test('toJson serializes all fields for inspection', () {
      final time = DateTime(2026, 9, 19, 12, 0);
      final item = HealthRecordItem(
        category: 'Body Composition (BIA)',
        title: 'Lean Body Mass',
        valueFormatted: '68.5 kg',
        rawValue: 68.5,
        unit: 'kg',
        timestamp: time,
        sourcePackage: 'com.sec.android.app.shealth',
        metadata: {'confidence': 'high'},
      );
      final json = item.toJson();
      expect(json['category'], 'Body Composition (BIA)');
      expect(json['title'], 'Lean Body Mass');
      expect(json['value'], '68.5 kg');
      expect(json['unit'], 'kg');
      expect(json['isFromSamsungHealth'], isTrue);
      expect(json['sourceDisplayName'], 'Samsung Health');
      expect(json['metadata']['confidence'], 'high');
    });
  });

  group('HealthInspectorInventory Tests', () {
    test('tallies Samsung Health records and serializes inventory', () {
      final now = DateTime(2026, 9, 19, 14, 0);
      final shealth = const SamsungHealthAppInfo(
        isInstalled: true,
        versionName: '6.30.2',
        versionCode: 6302,
        isEnabled: true,
      );
      final items = [
        HealthRecordItem(
          category: 'Body Composition (BIA)',
          title: 'Body Fat %',
          valueFormatted: '15%',
          rawValue: 15.0,
          timestamp: now,
          sourcePackage: 'com.sec.android.app.shealth',
        ),
        HealthRecordItem(
          category: 'Activity',
          title: 'Steps',
          valueFormatted: '5,000 steps',
          rawValue: 5000,
          timestamp: now,
          sourcePackage: 'com.google.android.apps.fitness',
        ),
      ];
      final inv = HealthInspectorInventory(
        samsungHealthInfo: shealth,
        isHealthConnectAvailable: true,
        items: items,
        permissionStatus: {'Steps': true, 'Body Fat %': true},
        inspectedAt: now,
      );

      expect(inv.samsungHealthCount, 1);
      final json = inv.toJson();
      expect(json['totalRecords'], 2);
      expect(json['samsungHealthRecords'], 1);
      expect(json['samsungHealth']['installed'], isTrue);
    });
  });
}
