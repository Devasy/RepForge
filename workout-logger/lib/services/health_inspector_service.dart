// health_inspector_service.dart — Wearable & Samsung Health diagnostics and data discovery
//
// Proof of Concept service that:
// 1. Probes Samsung Health app status via native MethodChannel.
// 2. Discovers and queries all available health data types from Health Connect
//    (which receives synced data from Samsung Galaxy Watches and Samsung Health).
// 3. Identifies record provenance (e.g. com.sec.android.app.shealth vs Google Fit vs others).

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health_connector/health_connector.dart';

class SamsungHealthAppInfo {
  final bool isInstalled;
  final String versionName;
  final int versionCode;
  final bool isEnabled;
  final String appPackageName;
  final String appSha256Fingerprint;
  final List<String> services;
  final List<String> providers;

  const SamsungHealthAppInfo({
    required this.isInstalled,
    required this.versionName,
    required this.versionCode,
    required this.isEnabled,
    this.appPackageName = '',
    this.appSha256Fingerprint = '',
    this.services = const [],
    this.providers = const [],
  });

  factory SamsungHealthAppInfo.empty() => const SamsungHealthAppInfo(
        isInstalled: false,
        versionName: '',
        versionCode: 0,
        isEnabled: false,
      );

  factory SamsungHealthAppInfo.fromMap(Map<dynamic, dynamic> map) {
    final rawServices = map['services'] as List<dynamic>? ?? [];
    final rawProviders = map['providers'] as List<dynamic>? ?? [];
    return SamsungHealthAppInfo(
      isInstalled: map['installed'] as bool? ?? false,
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      isEnabled: map['enabled'] as bool? ?? false,
      appPackageName: map['appPackageName'] as String? ?? '',
      appSha256Fingerprint: map['appSha256Fingerprint'] as String? ?? '',
      services: rawServices.map((s) => s.toString()).toList(),
      providers: rawProviders.map((p) => p.toString()).toList(),
    );
  }
}

class HealthRecordItem {
  final String category;
  final String title;
  final String valueFormatted;
  final dynamic rawValue;
  final String? unit;
  final DateTime timestamp;
  final String? sourcePackage;
  final Map<String, dynamic> metadata;

  const HealthRecordItem({
    required this.category,
    required this.title,
    required this.valueFormatted,
    required this.rawValue,
    this.unit,
    required this.timestamp,
    this.sourcePackage,
    this.metadata = const {},
  });

  bool get isFromSamsungHealth {
    final pkg = sourcePackage?.toLowerCase() ?? '';
    return pkg.contains('shealth') || pkg.contains('sec.android');
  }

  String get sourceDisplayName {
    if (isFromSamsungHealth) return 'Samsung Health';
    final pkg = sourcePackage ?? '';
    if (pkg.contains('fitness')) return 'Google Fit';
    if (pkg.contains('healthdata')) return 'Health Connect';
    if (pkg.contains('withings')) return 'Withings';
    if (pkg.contains('fitbit')) return 'Fitbit';
    if (pkg.contains('garmin')) return 'Garmin';
    if (pkg.contains('whoop')) return 'Whoop';
    if (pkg.isEmpty) return 'Local / Unknown';
    return pkg;
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'title': title,
        'value': valueFormatted,
        'rawValue': rawValue,
        'unit': unit,
        'timestamp': timestamp.toIso8601String(),
        'sourcePackage': sourcePackage,
        'sourceDisplayName': sourceDisplayName,
        'isFromSamsungHealth': isFromSamsungHealth,
        'metadata': metadata,
      };
}

class HealthTimeSeriesPoint {
  final DateTime timestamp;
  final double value;
  final double? minValue;
  final double? maxValue;
  final String? label;
  final Map<String, dynamic> extra;

  const HealthTimeSeriesPoint({
    required this.timestamp,
    required this.value,
    this.minValue,
    this.maxValue,
    this.label,
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'value': value,
        'minValue': minValue,
        'maxValue': maxValue,
        'label': label,
        'extra': extra,
      };
}

class HealthInspectorInventory {
  final SamsungHealthAppInfo samsungHealthInfo;
  final bool isHealthConnectAvailable;
  final List<HealthRecordItem> items;
  final Map<String, bool> permissionStatus;
  final List<String> directSamsungPermissions;
  final Map<String, String> directSamsungErrors;
  final List<HealthTimeSeriesPoint> energyScoreSeries;
  final List<HealthTimeSeriesPoint> sleepScoreSeries;
  final List<HealthTimeSeriesPoint> skinTempSeries;
  final List<HealthTimeSeriesPoint> skinTempIntradaySeries;
  final List<HealthTimeSeriesPoint> respiratoryRateSeries;
  final DateTime inspectedAt;

  const HealthInspectorInventory({
    required this.samsungHealthInfo,
    required this.isHealthConnectAvailable,
    required this.items,
    required this.permissionStatus,
    this.directSamsungPermissions = const [],
    this.directSamsungErrors = const {},
    this.energyScoreSeries = const [],
    this.sleepScoreSeries = const [],
    this.skinTempSeries = const [],
    this.skinTempIntradaySeries = const [],
    this.respiratoryRateSeries = const [],
    required this.inspectedAt,
  });

  int get samsungHealthCount =>
      items.where((i) => i.isFromSamsungHealth).length;

  Map<String, dynamic> toJson() => {
        'inspectedAt': inspectedAt.toIso8601String(),
        'isHealthConnectAvailable': isHealthConnectAvailable,
        'samsungHealth': {
          'installed': samsungHealthInfo.isInstalled,
          'versionName': samsungHealthInfo.versionName,
          'versionCode': samsungHealthInfo.versionCode,
          'enabled': samsungHealthInfo.isEnabled,
        },
        'directSamsungPermissions': directSamsungPermissions,
        'directSamsungErrors': directSamsungErrors,
        'permissionStatus': permissionStatus,
        'totalRecords': items.length,
        'samsungHealthRecords': samsungHealthCount,
        'energyScoreSeriesCount': energyScoreSeries.length,
        'sleepScoreSeriesCount': sleepScoreSeries.length,
        'skinTempSeriesCount': skinTempSeries.length,
        'skinTempIntradaySeriesCount': skinTempIntradaySeries.length,
        'respiratoryRateSeriesCount': respiratoryRateSeries.length,
        'records': items.map((i) => i.toJson()).toList(),
      };
}

class HealthInspectorService {
  static const MethodChannel _probeChannel =
      MethodChannel('com.devasy.repforge/samsung_health_probe');

  HealthConnector? _connector;

  HealthInspectorService({HealthConnector? connector})
      : _connector = connector;

  Future<HealthConnector?> _getConnector() async {
    try {
      _connector ??= await HealthConnector.create().timeout(
        const Duration(seconds: 5),
      );
      return _connector;
    } catch (e) {
      debugPrint('[HealthInspector] Failed to initialize HealthConnector: $e');
      return null;
    }
  }

  /// Probes Samsung Health package information via native MethodChannel.
  Future<SamsungHealthAppInfo> getSamsungHealthInfo() async {
    try {
      final res = await _probeChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getSamsungHealthDiagnostics',
      );
      if (res == null) return SamsungHealthAppInfo.empty();
      return SamsungHealthAppInfo.fromMap(res);
    } catch (e) {
      debugPrint('[HealthInspector] getSamsungHealthInfo error: $e');
      return SamsungHealthAppInfo.empty();
    }
  }

  /// Launches the Samsung Health app directly.
  Future<bool> launchSamsungHealth() async {
    try {
      final res = await _probeChannel.invokeMethod<bool>('launchSamsungHealth');
      return res ?? false;
    } catch (e) {
      debugPrint('[HealthInspector] launchSamsungHealth error: $e');
      return false;
    }
  }

  /// Opens the Android App Info Settings for Samsung Health.
  Future<bool> openSamsungHealthSettings() async {
    try {
      final res = await _probeChannel.invokeMethod<bool>(
        'openSamsungHealthSettings',
      );
      return res ?? false;
    } catch (e) {
      debugPrint('[HealthInspector] openSamsungHealthSettings error: $e');
      return false;
    }
  }

  /// Checks permissions granted directly by Samsung Health
  Future<List<String>> getDirectSamsungHealthPermissions() async {
    try {
      final res = await _probeChannel.invokeMethod<List<dynamic>>(
        'getSamsungHealthPermissions',
      );
      return res?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      debugPrint('[HealthInspector] getDirectSamsungHealthPermissions error: $e');
      return [];
    }
  }

  /// Requests permissions directly from Samsung Health app via SDK dialog
  Future<List<String>> requestDirectSamsungHealthPermissions() async {
    try {
      final res = await _probeChannel.invokeMethod<List<dynamic>>(
        'requestSamsungHealthPermissions',
      );
      return res?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      debugPrint('[HealthInspector] requestDirectSamsungHealthPermissions error: $e');
      return [];
    }
  }

  /// Reads data directly from Samsung Health app via Samsung Health Data SDK
  Future<Map<String, dynamic>> readDirectSamsungHealthData() async {
    try {
      final res = await _probeChannel.invokeMapMethod<dynamic, dynamic>(
        'readSamsungHealthData',
      );
      if (res == null) return {};
      return res.map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      debugPrint('[HealthInspector] readDirectSamsungHealthData error: $e');
      return {'errors': {'root': e.toString()}};
    }
  }

  /// Checks if Health Connect is available on the device.
  Future<bool> isHealthConnectAvailable() async {
    try {
      final status = await HealthConnector.getHealthPlatformStatus().timeout(
        const Duration(seconds: 5),
      );
      return status == HealthPlatformStatus.available;
    } catch (e) {
      debugPrint('[HealthInspector] isHealthConnectAvailable error: $e');
      return false;
    }
  }

  /// All permissions of interest for discovering Samsung Health & wearable data.
  static final Map<String, HealthDataPermission> discoveryPermissions = {
    'Steps': HealthDataType.steps.readPermission,
    'Active Calories': HealthDataType.activeEnergyBurned.readPermission,
    'Total Calories': HealthDataType.totalEnergyBurned.readPermission,
    'Weight': HealthDataType.weight.readPermission,
    'Height': HealthDataType.height.readPermission,
    'Body Fat %': HealthDataType.bodyFatPercentage.readPermission,
    'Lean Body Mass': HealthDataType.leanBodyMass.readPermission,
    'Bone Mass': HealthDataType.boneMass.readPermission,
    'Body Water': HealthDataType.bodyWaterMass.readPermission,
    'Basal Metabolic Rate': HealthDataType.basalMetabolicRate.readPermission,
    'Resting Heart Rate': HealthDataType.restingHeartRate.readPermission,
    'Heart Rate Series': HealthDataType.heartRateSeries.readPermission,
    'HRV (RMSSD)': HealthDataType.heartRateVariabilityRMSSD.readPermission,
    'Sleep': HealthDataType.sleepSession.readPermission,
    'Blood Oxygen (SpO2)': HealthDataType.oxygenSaturation.readPermission,
    'Blood Pressure': HealthDataType.bloodPressure.readPermission,
    'Respiratory Rate': HealthDataType.respiratoryRate.readPermission,
    'Exercise Sessions': HealthDataType.exerciseSession.readPermission,
  };

  /// Requests all discovery permissions from Health Connect.
  Future<bool> requestAllDiscoveryPermissions() async {
    final connector = await _getConnector();
    if (connector == null) return false;
    try {
      final permissions = discoveryPermissions.values.toList();
      final results = await connector.requestPermissions(permissions);
      return results.any((r) => r.status == PermissionStatus.granted);
    } catch (e) {
      debugPrint('[HealthInspector] requestAllDiscoveryPermissions error: $e');
      // Fallback: request individually if bulk fails
      var anyGranted = false;
      for (final p in discoveryPermissions.values) {
        try {
          final res = await connector.requestPermissions([p]);
          if (res.any((r) => r.status == PermissionStatus.granted)) {
            anyGranted = true;
          }
        } catch (_) {}
      }
      return anyGranted;
    }
  }

  /// Checks the grant status of each discovery permission.
  Future<Map<String, bool>> checkPermissionStatuses() async {
    final connector = await _getConnector();
    if (connector == null) {
      return {for (final k in discoveryPermissions.keys) k: false};
    }
    final statuses = <String, bool>{};
    for (final entry in discoveryPermissions.entries) {
      try {
        final status = await connector
            .getPermissionStatus(entry.value)
            .timeout(const Duration(seconds: 2));
        statuses[entry.key] = status == PermissionStatus.granted;
      } catch (_) {
        statuses[entry.key] = false;
      }
    }
    return statuses;
  }

  /// Queries all available health data types over a lookback window
  /// and builds an inventory of records with their origin/source.
  Future<HealthInspectorInventory> inspectHealthData({
    Duration lookback = const Duration(days: 14),
  }) async {
    final now = DateTime.now();
    final start = now.subtract(lookback);
    final shealthInfo = await getSamsungHealthInfo();
    final hcAvailable = await isHealthConnectAvailable();
    final perms = await checkPermissionStatuses();
    final connector = await _getConnector();

    final items = <HealthRecordItem>[];

    // Read directly from Samsung Health Data SDK
    final directData = await readDirectSamsungHealthData();
    final directPerms = await getDirectSamsungHealthPermissions();
    final directErrors = (directData['errors'] as Map<dynamic, dynamic>?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ) ??
        {};

    // Parse Body Composition (BIA) from Samsung Health
    final bodyCompList = directData['bodyComposition'] as List<dynamic>? ?? [];
    if (bodyCompList.isNotEmpty) {
      final latest = Map<String, dynamic>.from(bodyCompList.first as Map);
      final ts = DateTime.tryParse(latest['startTime']?.toString() ?? '') ?? now;

      final bodyFat = latest['bodyFatPercent'] as num?;
      if (bodyFat != null) {
        items.add(HealthRecordItem(
          category: 'Body Composition (BIA Direct)',
          title: 'Body Fat Percentage',
          valueFormatted: '${bodyFat.toStringAsFixed(1)} %',
          rawValue: bodyFat,
          unit: '%',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': bodyCompList.length,
            'fatMassKg': latest['bodyFatMassKg'],
            'directSdk': true,
          },
        ));
      }

      final skeletalMuscleMass = latest['skeletalMuscleMassKg'] as num?;
      final skeletalMusclePct = latest['skeletalMusclePercent'] as num?;
      if (skeletalMuscleMass != null || skeletalMusclePct != null) {
        final formatted = skeletalMuscleMass != null
            ? '${skeletalMuscleMass.toStringAsFixed(1)} kg${skeletalMusclePct != null ? ' (${skeletalMusclePct.toStringAsFixed(1)}%)' : ''}'
            : '${skeletalMusclePct!.toStringAsFixed(1)} %';
        items.add(HealthRecordItem(
          category: 'Body Composition (BIA Direct)',
          title: 'Skeletal Muscle Mass',
          valueFormatted: formatted,
          rawValue: skeletalMuscleMass ?? skeletalMusclePct,
          unit: skeletalMuscleMass != null ? 'kg' : '%',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': bodyCompList.length,
            'muscleMassKg': latest['muscleMassKg'],
            'directSdk': true,
          },
        ));
      }

      final water = latest['totalBodyWaterL'] as num?;
      if (water != null) {
        items.add(HealthRecordItem(
          category: 'Body Composition (BIA Direct)',
          title: 'Total Body Water',
          valueFormatted: '${water.toStringAsFixed(1)} L',
          rawValue: water,
          unit: 'L',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': bodyCompList.length,
            'directSdk': true,
          },
        ));
      }

      final bmr = latest['bmrKcal'] as num?;
      if (bmr != null) {
        items.add(HealthRecordItem(
          category: 'Body Composition (BIA Direct)',
          title: 'Basal Metabolic Rate (BMR)',
          valueFormatted: '${bmr.toInt()} kcal',
          rawValue: bmr,
          unit: 'kcal',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': bodyCompList.length,
            'directSdk': true,
          },
        ));
      }

      final bmi = latest['bmi'] as num?;
      if (bmi != null) {
        items.add(HealthRecordItem(
          category: 'Body Composition (BIA Direct)',
          title: 'Body Mass Index (BMI)',
          valueFormatted: bmi.toStringAsFixed(1),
          rawValue: bmi,
          unit: 'kg/m²',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': bodyCompList.length,
            'heightM': latest['heightM'],
            'weightKg': latest['weightKg'],
            'directSdk': true,
          },
        ));
      }
    }

    // Time Series Accumulators
    final energyScoreSeries = <HealthTimeSeriesPoint>[];
    final sleepScoreSeries = <HealthTimeSeriesPoint>[];
    final skinTempSeries = <HealthTimeSeriesPoint>[];
    final skinTempIntradaySeries = <HealthTimeSeriesPoint>[];
    final respiratoryRateSeries = <HealthTimeSeriesPoint>[];

    // Parse Energy Score from Samsung Health
    final energyList = directData['energyScore'] as List<dynamic>? ?? [];
    for (final raw in energyList) {
      if (raw is Map) {
        final score = (raw['score'] as num?)?.toDouble();
        final dt = DateTime.tryParse(raw['date']?.toString() ?? '');
        if (score != null && dt != null) {
          energyScoreSeries.add(HealthTimeSeriesPoint(
            timestamp: dt,
            value: score,
            label: '${score.round()} / 100',
            extra: {'uid': raw['uid']},
          ));
        }
      }
    }
    energyScoreSeries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (energyList.isNotEmpty) {
      final latest = Map<String, dynamic>.from(energyList.first as Map);
      final score = latest['score'] as num?;
      if (score != null) {
        final ts = DateTime.tryParse(latest['date']?.toString() ?? '') ?? now;
        items.add(HealthRecordItem(
          category: 'Vitals & Energy (Direct)',
          title: 'Samsung Energy Score (Galaxy AI)',
          valueFormatted: '${score.round()} / 100',
          rawValue: score,
          unit: 'score',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': energyList.length,
            'directSdk': true,
          },
        ));
      }
    }

    // Parse Blood Pressure from Samsung Health
    final bpList = directData['bloodPressure'] as List<dynamic>? ?? [];
    if (bpList.isNotEmpty) {
      final latest = Map<String, dynamic>.from(bpList.first as Map);
      final sys = (latest['systolic'] as num?)?.round();
      final dia = (latest['diastolic'] as num?)?.round();
      final pulse = (latest['pulseRate'] as num?)?.round();
      final ts = DateTime.tryParse(latest['startTime']?.toString() ?? '') ?? now;
      if (sys != null && dia != null) {
        items.add(HealthRecordItem(
          category: 'Vitals & Cardiac (Direct)',
          title: 'Blood Pressure',
          valueFormatted: '$sys / $dia mmHg${pulse != null ? ' ($pulse bpm pulse)' : ''}',
          rawValue: {'systolic': sys, 'diastolic': dia, 'pulse': pulse},
          unit: 'mmHg',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': bpList.length,
            'directSdk': true,
          },
        ));
      }
    }

    // Parse Blood Oxygen from Samsung Health
    final spo2List = directData['bloodOxygen'] as List<dynamic>? ?? [];
    if (spo2List.isNotEmpty) {
      final latest = Map<String, dynamic>.from(spo2List.first as Map);
      final spo2 = latest['oxygenSaturation'] as num?;
      final ts = DateTime.tryParse(latest['startTime']?.toString() ?? '') ?? now;
      if (spo2 != null) {
        items.add(HealthRecordItem(
          category: 'Vitals & Cardiac (Direct)',
          title: 'Blood Oxygen (SpO2)',
          valueFormatted: '${spo2.toStringAsFixed(1)} %',
          rawValue: spo2,
          unit: '%',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': spo2List.length,
            'min': latest['minOxygenSaturation'],
            'max': latest['maxOxygenSaturation'],
            'directSdk': true,
          },
        ));
      }
    }

    // Parse Heart Rate from Samsung Health
    final hrList = directData['heartRate'] as List<dynamic>? ?? [];
    if (hrList.isNotEmpty) {
      final latest = Map<String, dynamic>.from(hrList.first as Map);
      final hr = latest['heartRate'] as num?;
      final ts = DateTime.tryParse(latest['startTime']?.toString() ?? '') ?? now;
      if (hr != null) {
        items.add(HealthRecordItem(
          category: 'Vitals & Cardiac (Direct)',
          title: 'Heart Rate (Direct)',
          valueFormatted: '${hr.round()} bpm',
          rawValue: hr,
          unit: 'bpm',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': hrList.length,
            'min': latest['minHeartRate'],
            'max': latest['maxHeartRate'],
            'directSdk': true,
          },
        ));
      }
    }

    // Parse Skin Temperature from Samsung Health (Galaxy Watch 5/6/7 / Ring)
    final skinList = directData['skinTemperature'] as List<dynamic>? ?? [];
    for (final raw in skinList) {
      if (raw is Map) {
        final temp = (raw['skinTemperature'] as num?)?.toDouble();
        final minT = (raw['minSkinTemperature'] as num?)?.toDouble();
        final maxT = (raw['maxSkinTemperature'] as num?)?.toDouble();
        final dt = DateTime.tryParse(raw['startTime']?.toString() ?? '');
        if (temp != null && dt != null) {
          skinTempSeries.add(HealthTimeSeriesPoint(
            timestamp: dt,
            value: temp,
            minValue: minT,
            maxValue: maxT,
            label: '${temp.toStringAsFixed(1)} °C',
            extra: {'uid': raw['uid']},
          ));
        }

        final rawSeries = raw['series'] as List<dynamic>?;
        if (rawSeries != null) {
          for (final s in rawSeries) {
            if (s is Map) {
              final sTemp = (s['skinTemperature'] as num?)?.toDouble();
              final sMin = (s['min'] as num?)?.toDouble();
              final sMax = (s['max'] as num?)?.toDouble();
              final sTime = DateTime.tryParse(s['startTime']?.toString() ?? '');
              if (sTemp != null && sTime != null) {
                skinTempIntradaySeries.add(HealthTimeSeriesPoint(
                  timestamp: sTime,
                  value: sTemp,
                  minValue: sMin,
                  maxValue: sMax,
                  label: '${sTemp.toStringAsFixed(1)} °C',
                ));
              }
            }
          }
        }
      }
    }
    skinTempSeries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    skinTempIntradaySeries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (skinList.isNotEmpty) {
      final latest = Map<String, dynamic>.from(skinList.first as Map);
      final temp = latest['skinTemperature'] as num?;
      final ts = DateTime.tryParse(latest['startTime']?.toString() ?? '') ?? now;
      if (temp != null) {
        items.add(HealthRecordItem(
          category: 'Vitals & Thermal (Direct)',
          title: 'Skin Temperature',
          valueFormatted: '${temp.toStringAsFixed(1)} °C',
          rawValue: temp,
          unit: '°C',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': skinList.length,
            'minSkinTemp': latest['minSkinTemperature'],
            'maxSkinTemp': latest['maxSkinTemperature'],
            'seriesPoints': (latest['series'] as List<dynamic>?)?.length ?? 0,
            'directSdk': true,
          },
        ));
      }
    }

    // Parse Direct Sleep Score from Samsung Health
    final directSleepList = directData['directSleep'] as List<dynamic>? ?? [];
    for (final raw in directSleepList) {
      if (raw is Map) {
        final score = (raw['sleepScore'] as num?)?.toDouble();
        final dt = DateTime.tryParse(raw['startTime']?.toString() ?? '');
        final dur = (raw['durationMinutes'] as num?)?.toInt();
        if (score != null && dt != null) {
          final durLabel = dur != null ? ' (${dur ~/ 60}h ${dur % 60}m)' : '';
          sleepScoreSeries.add(HealthTimeSeriesPoint(
            timestamp: dt,
            value: score,
            label: '${score.round()} / 100$durLabel',
            extra: {
              'uid': raw['uid'],
              'durationMinutes': dur,
            },
          ));
        }
      }
    }
    sleepScoreSeries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (directSleepList.isNotEmpty) {
      final latest = Map<String, dynamic>.from(directSleepList.first as Map);
      final score = latest['sleepScore'] as num?;
      final ts = DateTime.tryParse(latest['startTime']?.toString() ?? '') ?? now;
      final dur = (latest['durationMinutes'] as num?)?.toInt();
      final durLabel = dur != null ? ' (${dur ~/ 60}h ${dur % 60}m)' : '';
      if (score != null) {
        items.add(HealthRecordItem(
          category: 'Sleep & Recovery (Direct)',
          title: 'Samsung Sleep Score',
          valueFormatted: '$score / 100$durLabel',
          rawValue: score,
          unit: 'score',
          timestamp: ts,
          sourcePackage: 'com.sec.android.app.shealth',
          metadata: {
            'recordsCount': directSleepList.length,
            'durationMinutes': dur,
            'directSdk': true,
          },
        ));
      }
    }

    String extractOrigin(dynamic metadata) =>
        metadata?.dataOrigin?.packageName as String? ?? 'unknown';

    if (connector == null || !hcAvailable) {
      return HealthInspectorInventory(
        samsungHealthInfo: shealthInfo,
        isHealthConnectAvailable: hcAvailable,
        items: items,
        permissionStatus: perms,
        directSamsungPermissions: directPerms,
        directSamsungErrors: directErrors,
        energyScoreSeries: energyScoreSeries,
        sleepScoreSeries: sleepScoreSeries,
        skinTempSeries: skinTempSeries,
        skinTempIntradaySeries: skinTempIntradaySeries,
        respiratoryRateSeries: respiratoryRateSeries,
        inspectedAt: now,
      );
    }

    // 1. Steps
    if (perms['Steps'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.steps.readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final totalSteps =
              res.records.fold<int>(0, (sum, r) => sum + r.count.value.toInt());
          final latest = res.records.last;
          items.add(HealthRecordItem(
            category: 'Activity',
            title: 'Steps (Lookback Total / Latest)',
            valueFormatted: '$totalSteps steps total (${latest.count.value.toInt()} latest)',
            rawValue: totalSteps,
            unit: 'steps',
            timestamp: latest.endTime,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {'recordsCount': res.records.length},
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Steps read error: $e');
      }
    }

    // 2. Active Calories
    if (perms['Active Calories'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.activeEnergyBurned
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final totalKcal = res.records.fold<double>(
            0.0,
            (sum, r) => sum + r.energy.inKilocalories,
          );
          final latest = res.records.last;
          items.add(HealthRecordItem(
            category: 'Activity',
            title: 'Active Energy Burned',
            valueFormatted: '${totalKcal.toStringAsFixed(1)} kcal',
            rawValue: totalKcal,
            unit: 'kcal',
            timestamp: latest.endTime,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {'recordsCount': res.records.length},
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Active energy error: $e');
      }
    }

    // 3. Body Fat Percentage (BIA)
    if (perms['Body Fat %'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.bodyFatPercentage
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          final pct = latest.percentage.asWhole;
          items.add(HealthRecordItem(
            category: 'Body Composition (BIA)',
            title: 'Body Fat Percentage',
            valueFormatted: '${pct.toStringAsFixed(1)} %',
            rawValue: pct,
            unit: '%',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {'recordsCount': res.records.length},
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Body fat read error: $e');
      }
    }

    // 4. Lean Body Mass (BIA)
    if (perms['Lean Body Mass'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.leanBodyMass
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          final kg = latest.mass.inKilograms;
          items.add(HealthRecordItem(
            category: 'Body Composition (BIA)',
            title: 'Lean Body Mass (Skeletal Muscle & Tissue)',
            valueFormatted: '${kg.toStringAsFixed(1)} kg',
            rawValue: kg,
            unit: 'kg',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {'recordsCount': res.records.length},
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Lean body mass read error: $e');
      }
    }

    // 5. Weight & Height
    if (perms['Weight'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.weight.readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          final kg = latest.weight.inKilograms;
          items.add(HealthRecordItem(
            category: 'Body Composition (BIA)',
            title: 'Weight',
            valueFormatted: '${kg.toStringAsFixed(1)} kg',
            rawValue: kg,
            unit: 'kg',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Weight read error: $e');
      }
    }

    // 6. Basal Metabolic Rate (BMR)
    if (perms['Basal Metabolic Rate'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.basalMetabolicRate
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          final bmr = latest.rate.inKilocaloriesPerDay;
          items.add(HealthRecordItem(
            category: 'Body Composition (BIA)',
            title: 'Basal Metabolic Rate (BMR)',
            valueFormatted: '${bmr.round()} kcal/day',
            rawValue: bmr,
            unit: 'kcal/day',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] BMR read error: $e');
      }
    }

    // 7. Body Water Mass
    if (perms['Body Water'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.bodyWaterMass
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          final kg = latest.mass.inKilograms;
          items.add(HealthRecordItem(
            category: 'Body Composition (BIA)',
            title: 'Body Water Mass',
            valueFormatted: '${kg.toStringAsFixed(1)} kg',
            rawValue: kg,
            unit: 'kg',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Body water read error: $e');
      }
    }

    // 8. Resting Heart Rate
    if (perms['Resting Heart Rate'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.restingHeartRate
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          final bpm = latest.rate.inPerMinute;
          items.add(HealthRecordItem(
            category: 'Vitals & Cardiac',
            title: 'Resting Heart Rate',
            valueFormatted: '$bpm bpm',
            rawValue: bpm,
            unit: 'bpm',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {'recordsCount': res.records.length},
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] RHR read error: $e');
      }
    }

    // 9. Heart Rate Series
    if (perms['Heart Rate Series'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.heartRateSeries
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 5));
        if (res.records.isNotEmpty) {
          var sampleCount = 0;
          var minBpm = 999.0;
          var maxBpm = 0.0;
          for (final r in res.records) {
            sampleCount += r.samples.length;
            for (final s in r.samples) {
              final bpm = s.rate.inPerMinute.toDouble();
              if (bpm < minBpm) minBpm = bpm;
              if (bpm > maxBpm) maxBpm = bpm;
            }
          }
          final latest = res.records.last;
          final latestBpm =
              latest.samples.isNotEmpty ? latest.samples.last.rate.inPerMinute : 0;
          items.add(HealthRecordItem(
            category: 'Vitals & Cardiac',
            title: 'Heart Rate Samples',
            valueFormatted:
                '$latestBpm bpm latest (min: ${minBpm == 999.0 ? '-' : minBpm.round()}, max: ${maxBpm.round()})',
            rawValue: latestBpm,
            unit: 'bpm',
            timestamp: latest.endTime,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {
              'seriesRecordsCount': res.records.length,
              'totalIndividualSamples': sampleCount,
            },
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] HR series read error: $e');
      }
    }

    // 10. HRV RMSSD
    if (perms['HRV (RMSSD)'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.heartRateVariabilityRMSSD
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          final ms = latest.rmssd.inMilliseconds.toDouble();
          items.add(HealthRecordItem(
            category: 'Vitals & Cardiac',
            title: 'HRV (RMSSD Recovery)',
            valueFormatted: '${ms.toStringAsFixed(1)} ms',
            rawValue: ms,
            unit: 'ms',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {'recordsCount': res.records.length},
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] HRV read error: $e');
      }
    }

    // 11. Blood Oxygen (SpO2)
    if (perms['Blood Oxygen (SpO2)'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.oxygenSaturation
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          final pct = latest.saturation.asWhole;
          items.add(HealthRecordItem(
            category: 'Vitals & Cardiac',
            title: 'Blood Oxygen (SpO2)',
            valueFormatted: '${pct.toStringAsFixed(1)} %',
            rawValue: pct,
            unit: '%',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {'recordsCount': res.records.length},
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] SpO2 read error: $e');
      }
    }

    // 12. Blood Pressure
    if (perms['Blood Pressure'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.bloodPressure
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          final sys = latest.systolic.inMillimetersOfMercury.round();
          final dia = latest.diastolic.inMillimetersOfMercury.round();
          items.add(HealthRecordItem(
            category: 'Vitals & Cardiac',
            title: 'Blood Pressure',
            valueFormatted: '$sys / $dia mmHg',
            rawValue: {'systolic': sys, 'diastolic': dia},
            unit: 'mmHg',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Blood pressure read error: $e');
      }
    }

    // 13. Sleep Sessions
    if (perms['Sleep'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.sleepSession
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          if (sleepScoreSeries.isEmpty) {
            for (final r in res.records) {
              final durMins = r.duration.inMinutes;
              final hours = durMins / 60.0;
              final approxScore = (hours >= 7.0 && hours <= 9.0)
                  ? (85.0 + (hours - 7.0) * 5.0)
                  : (hours < 7.0 ? (hours / 7.0 * 80.0) : (85.0 - (hours - 9.0) * 8.0)).clamp(35.0, 95.0);
              sleepScoreSeries.add(HealthTimeSeriesPoint(
                timestamp: r.startTime,
                value: approxScore,
                label: '${approxScore.round()} / 100 (${durMins ~/ 60}h ${durMins % 60}m)',
                extra: {
                  'durationMinutes': durMins,
                  'isApproximateFromSession': true,
                  'origin': extractOrigin(r.metadata),
                },
              ));
            }
            sleepScoreSeries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }

          final latest = res.records.last;
          final durationMins = latest.duration.inMinutes;
          final hours = durationMins ~/ 60;
          final mins = durationMins % 60;
          var deep = 0, rem = 0, light = 0, awake = 0;
          for (final s in latest.samples) {
            final m = s.duration.inMinutes;
            switch (s.stageType) {
              case SleepStage.deep:
                deep += m;
              case SleepStage.rem:
                rem += m;
              case SleepStage.light:
              case SleepStage.sleeping:
                light += m;
              case SleepStage.awake:
              case SleepStage.inBed:
              case SleepStage.outOfBed:
                awake += m;
              case SleepStage.unknown:
                break;
            }
          }
          items.add(HealthRecordItem(
            category: 'Sleep & Recovery',
            title: 'Sleep Session & Stages',
            valueFormatted:
                '${hours}h ${mins}m (Deep: ${deep}m, REM: ${rem}m, Light: ${light}m)',
            rawValue: durationMins,
            unit: 'minutes',
            timestamp: latest.endTime,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {
              'durationMinutes': durationMins,
              'deepMinutes': deep,
              'remMinutes': rem,
              'lightMinutes': light,
              'awakeMinutes': awake,
              'samplesCount': latest.samples.length,
            },
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Sleep read error: $e');
      }
    }

    // 14. Exercise Sessions
    if (perms['Exercise Sessions'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.exerciseSession
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          final latest = res.records.last;
          items.add(HealthRecordItem(
            category: 'Activity',
            title: 'Exercise Sessions Recorded',
            valueFormatted:
                '${res.records.length} workouts (Latest: ${latest.title ?? latest.exerciseType.name})',
            rawValue: res.records.length,
            unit: 'sessions',
            timestamp: latest.endTime,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {
              'latestTitle': latest.title,
              'latestType': latest.exerciseType.name,
              'durationMinutes': latest.duration.inMinutes,
            },
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Exercise sessions read error: $e');
      }
    }

    // 15. Respiratory Rate
    if (perms['Respiratory Rate'] == true) {
      try {
        final res = await connector.readRecords(
          HealthDataType.respiratoryRate
              .readInTimeRange(startTime: start, endTime: now),
        ).timeout(const Duration(seconds: 4));
        if (res.records.isNotEmpty) {
          for (final r in res.records) {
            final bpm = r.rate.inPerMinute;
            respiratoryRateSeries.add(HealthTimeSeriesPoint(
              timestamp: r.time,
              value: bpm,
              label: '${bpm.toStringAsFixed(1)} bpm',
              extra: {'origin': extractOrigin(r.metadata)},
            ));
          }
          respiratoryRateSeries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          final latest = res.records.last;
          final avgBpm = res.records.fold<double>(0.0, (s, r) => s + r.rate.inPerMinute) / res.records.length;
          items.add(HealthRecordItem(
            category: 'Vitals & Cardiac',
            title: 'Respiratory Rate',
            valueFormatted:
                '${latest.rate.inPerMinute.toStringAsFixed(1)} breaths/min (avg: ${avgBpm.toStringAsFixed(1)})',
            rawValue: latest.rate.inPerMinute,
            unit: 'bpm',
            timestamp: latest.time,
            sourcePackage: extractOrigin(latest.metadata),
            metadata: {
              'recordsCount': res.records.length,
              'avgBpm': avgBpm.toStringAsFixed(1),
              'latestBpm': latest.rate.inPerMinute.toStringAsFixed(1),
            },
          ));
        }
      } catch (e) {
        debugPrint('[HealthInspector] Respiratory rate read error: $e');
      }
    }

    return HealthInspectorInventory(
      samsungHealthInfo: shealthInfo,
      isHealthConnectAvailable: hcAvailable,
      items: items,
      permissionStatus: perms,
      directSamsungPermissions: directPerms,
      directSamsungErrors: directErrors,
      energyScoreSeries: energyScoreSeries,
      sleepScoreSeries: sleepScoreSeries,
      skinTempSeries: skinTempSeries,
      skinTempIntradaySeries: skinTempIntradaySeries,
      respiratoryRateSeries: respiratoryRateSeries,
      inspectedAt: now,
    );
  }
}
