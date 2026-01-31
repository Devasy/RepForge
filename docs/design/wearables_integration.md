# Wearables Integration Feature

## Overview

Integrate with smartwatches and fitness wearables to capture real-time biometric data during workouts, including heart rate, calories burned, and activity metrics. This enhances workout tracking accuracy and provides deeper health insights.

## User Stories

1. **As a user**, I want to see my heart rate during workouts from my smartwatch.
2. **As a user**, I want accurate calorie burn calculations based on heart rate data.
3. **As a user**, I want to sync my workout data with my wearable's fitness app.
4. **As a user**, I want to use my smartwatch to control rest timers.
5. **As a user**, I want to see my recovery metrics (HRV, resting HR) to guide training.
6. **As a user**, I want workouts logged automatically when detected by my wearable.

## Supported Platforms

| Platform | Data Available | API |
|----------|----------------|-----|
| **Apple Watch** | HR, HRV, calories, steps, workouts | HealthKit |
| **Wear OS** | HR, calories, steps, workouts | Health Connect |
| **Fitbit** | HR, HRV, sleep, calories, workouts | Fitbit Web API |
| **Garmin** | HR, HRV, stress, workouts | Garmin Connect API |
| **Samsung Galaxy Watch** | HR, stress, workouts | Health Connect |
| **WHOOP** | Strain, recovery, sleep, HRV | WHOOP API |

## Data Model

### Wearable Connection

```dart
class WearableConnection {
  final String id;
  final WearableProvider provider;
  final String? deviceName;
  final DateTime connectedAt;
  final DateTime? lastSyncAt;
  final ConnectionStatus status;
  final List<DataType> enabledDataTypes;
  final Map<String, dynamic>? authTokens;
  
  WearableConnection({
    required this.id,
    required this.provider,
    this.deviceName,
    required this.connectedAt,
    this.lastSyncAt,
    this.status = ConnectionStatus.connected,
    this.enabledDataTypes = const [],
    this.authTokens,
  });
}

enum WearableProvider {
  appleHealth,
  healthConnect,
  fitbit,
  garmin,
  whoop,
}

enum DataType {
  heartRate,
  heartRateVariability,
  restingHeartRate,
  calories,
  steps,
  activeMinutes,
  sleep,
  workouts,
  stress,
  bloodOxygen,
}

enum ConnectionStatus {
  connected,
  disconnected,
  syncing,
  error,
}
```

### Heart Rate Data

```dart
class HeartRateReading {
  final DateTime timestamp;
  final int bpm;
  final HeartRateSource source;
  
  HeartRateReading({
    required this.timestamp,
    required this.bpm,
    required this.source,
  });
}

class HeartRateZone {
  final String name;
  final int minBpm;
  final int maxBpm;
  final Color color;
  
  const HeartRateZone({
    required this.name,
    required this.minBpm,
    required this.maxBpm,
    required this.color,
  });
  
  static List<HeartRateZone> calculateZones(int maxHR) {
    return [
      HeartRateZone(name: 'Rest', minBpm: 0, maxBpm: (maxHR * 0.5).round(), color: Colors.grey),
      HeartRateZone(name: 'Fat Burn', minBpm: (maxHR * 0.5).round(), maxBpm: (maxHR * 0.6).round(), color: Colors.blue),
      HeartRateZone(name: 'Cardio', minBpm: (maxHR * 0.6).round(), maxBpm: (maxHR * 0.7).round(), color: Colors.green),
      HeartRateZone(name: 'Aerobic', minBpm: (maxHR * 0.7).round(), maxBpm: (maxHR * 0.8).round(), color: Colors.yellow),
      HeartRateZone(name: 'Anaerobic', minBpm: (maxHR * 0.8).round(), maxBpm: (maxHR * 0.9).round(), color: Colors.orange),
      HeartRateZone(name: 'Max', minBpm: (maxHR * 0.9).round(), maxBpm: maxHR, color: Colors.red),
    ];
  }
}
```

### Workout Biometrics

```dart
class WorkoutBiometrics {
  final String sessionId;
  final List<HeartRateReading> heartRateData;
  final int? averageHeartRate;
  final int? maxHeartRate;
  final int? minHeartRate;
  final double? caloriesBurned;
  final Map<String, Duration> timeInZones;  // Zone name -> duration
  final double? trainingLoad;               // TRIMP or similar
  
  WorkoutBiometrics({
    required this.sessionId,
    this.heartRateData = const [],
    this.averageHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.caloriesBurned,
    this.timeInZones = const {},
    this.trainingLoad,
  });
  
  /// Calculate calories using heart rate (Keytel formula)
  static double calculateCalories({
    required int avgHR,
    required int durationMinutes,
    required int age,
    required double weightKg,
    required bool isMale,
  }) {
    if (isMale) {
      return ((-55.0969 + 0.6309 * avgHR + 0.1988 * weightKg + 0.2017 * age) / 4.184) * durationMinutes;
    } else {
      return ((-20.4022 + 0.4472 * avgHR - 0.1263 * weightKg + 0.074 * age) / 4.184) * durationMinutes;
    }
  }
}
```

### Recovery Metrics

```dart
class RecoveryMetrics {
  final DateTime date;
  final int? hrvMs;                    // Heart rate variability in ms
  final int? restingHeartRate;
  final double? sleepScore;            // 0-100
  final Duration? sleepDuration;
  final double? recoveryScore;         // 0-100 computed score
  final String? recommendation;
  
  RecoveryMetrics({
    required this.date,
    this.hrvMs,
    this.restingHeartRate,
    this.sleepScore,
    this.sleepDuration,
    this.recoveryScore,
    this.recommendation,
  });
  
  RecoveryLevel get level {
    if (recoveryScore == null) return RecoveryLevel.unknown;
    if (recoveryScore! >= 80) return RecoveryLevel.excellent;
    if (recoveryScore! >= 60) return RecoveryLevel.good;
    if (recoveryScore! >= 40) return RecoveryLevel.moderate;
    return RecoveryLevel.poor;
  }
}

enum RecoveryLevel {
  excellent,  // Go hard
  good,       // Normal training
  moderate,   // Light training recommended
  poor,       // Rest day recommended
  unknown,
}
```

## UI/UX Design

### 1. Wearables Setup Screen

```
┌─────────────────────────────────────┐
│  ⌚ Connect Wearables               │
├─────────────────────────────────────┤
│                                     │
│  Connected Devices                  │
│  ────────────────────────────────   │
│  ┌─────────────────────────────┐    │
│  │ ⌚ Apple Watch Series 8     │    │
│  │    Connected via HealthKit  │    │
│  │    Last sync: 5 min ago     │    │
│  │    [Sync Now]  [Disconnect] │    │
│  └─────────────────────────────┘    │
│                                     │
│  Add New Connection                 │
│  ────────────────────────────────   │
│  ┌─────────────────────────────┐    │
│  │  Apple Health           │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 🤖 Google Fit / Health     │    │
│  │    Connect                  │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ 📊 Fitbit                   │    │
│  │    Connect                  │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ ⌚ Garmin                   │    │
│  │    Connect                  │    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

### 2. Data Permissions

```
┌─────────────────────────────────────┐
│  Health Data Permissions            │
├─────────────────────────────────────┤
│                                     │
│  Select what data RepForge can      │
│  read from Apple Health:            │
│                                     │
│  ☑ Heart Rate                       │
│     Real-time HR during workouts    │
│                                     │
│  ☑ Heart Rate Variability           │
│     Recovery and readiness metrics  │
│                                     │
│  ☑ Resting Heart Rate               │
│     Track fitness improvements      │
│                                     │
│  ☑ Active Energy Burned             │
│     Accurate calorie tracking       │
│                                     │
│  ☐ Sleep Analysis                   │
│     Factor sleep into recovery      │
│                                     │
│  ☑ Workouts                         │
│     Sync workouts both ways         │
│                                     │
│  Your data is stored locally and    │
│  never shared without permission.   │
│                                     │
│        [SAVE PERMISSIONS]           │
│                                     │
└─────────────────────────────────────┘
```

### 3. Live Heart Rate During Workout

```
┌─────────────────────────────────────┐
│  Push Day - In Progress             │
├─────────────────────────────────────┤
│                                     │
│  Current Exercise: Bench Press      │
│  Set 3 of 4                         │
│                                     │
│  ┌─────────────────────────────┐    │
│  │        ❤️ 142 BPM           │    │
│  │        ▄▅▆▇█▇▆▅▄▃▂▃▄▅▆▇█   │    │
│  │        ━━━━━━━━━━━━━━━━━━   │    │
│  │        CARDIO ZONE          │    │
│  └─────────────────────────────┘    │
│                                     │
│  This Workout                       │
│  ────────────────────────────────   │
│  Avg HR: 128 bpm                    │
│  Max HR: 156 bpm                    │
│  Calories: 245 kcal                 │
│                                     │
│  Time in Zones:                     │
│  🔵 Fat Burn    8 min  ████░░░░    │
│  🟢 Cardio     12 min  ██████░░    │
│  🟡 Aerobic     5 min  ██░░░░░░    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │     LOG SET: 100kg × 8      │    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

### 4. Workout Summary with Biometrics

```
┌─────────────────────────────────────┐
│  Workout Complete! 🎉              │
├─────────────────────────────────────┤
│                                     │
│  Push Day                           │
│  Duration: 58 min                   │
│                                     │
│  ❤️ Heart Rate                      │
│  ────────────────────────────────   │
│  ┌─────────────────────────────┐    │
│  │    156 ←── Max              │    │
│  │    █                        │    │
│  │   ██ █  █                   │    │
│  │  ███ ██ ██    █ █           │    │
│  │ ████ ██████  ████ █         │    │
│  │█████████████████████        │    │
│  │    92 ←── Rest periods      │    │
│  │  ────────────────────────   │    │
│  │  0    15    30    45   58m  │    │
│  └─────────────────────────────┘    │
│                                     │
│  📊 Summary                         │
│  Avg HR: 128 bpm                    │
│  Max HR: 156 bpm                    │
│  Calories: 485 kcal                 │
│  Training Load: 87 (High)           │
│                                     │
│  ⏱️ Time in Zones                   │
│  🔵 Fat Burn    12 min (21%)        │
│  🟢 Cardio      25 min (43%)        │
│  🟡 Aerobic     15 min (26%)        │
│  🟠 Anaerobic    6 min (10%)        │
│                                     │
│        [SAVE WORKOUT]               │
│                                     │
└─────────────────────────────────────┘
```

### 5. Recovery Dashboard

```
┌─────────────────────────────────────┐
│  💤 Recovery Status                 │
├─────────────────────────────────────┤
│                                     │
│  Today's Recovery Score             │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │         🟢 78%              │    │
│  │         GOOD                │    │
│  │                             │    │
│  │   Ready for normal training │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  Recovery Factors                   │
│  ────────────────────────────────   │
│                                     │
│  ❤️ HRV                             │
│     52 ms (above baseline)          │
│     ████████████████░░  85%         │
│                                     │
│  💓 Resting HR                      │
│     58 bpm (normal)                 │
│     ██████████████░░░░  72%         │
│                                     │
│  😴 Sleep                           │
│     7h 23m (good)                   │
│     █████████████████░  78%         │
│                                     │
│  7-Day Trend                        │
│  ────────────────────────────────   │
│  M   T   W   T   F   S   S          │
│  🟡  🟢  🟢  🔴  🟡  🟢  🟢          │
│  65  82  78  45  62  75  78         │
│                                     │
└─────────────────────────────────────┘
```

### 6. Smartwatch Companion (Concept)

```
┌───────────────────┐
│     RepForge      │
├───────────────────┤
│                   │
│   BENCH PRESS     │
│   Set 3 of 4      │
│                   │
│    ❤️ 142         │
│                   │
│   ┌───────────┐   │
│   │  LOG SET  │   │
│   └───────────┘   │
│                   │
│   REST: 1:45      │
│                   │
└───────────────────┘
```

## Wearable Service Implementation

```dart
abstract class WearableService {
  Stream<HeartRateReading> get heartRateStream;
  Future<List<HeartRateReading>> getHeartRateHistory(DateTimeRange range);
  Future<RecoveryMetrics?> getRecoveryMetrics(DateTime date);
  Future<void> syncWorkout(WorkoutSession session);
}

class HealthKitService implements WearableService {
  final HealthFactory _health = HealthFactory();
  
  static const List<HealthDataType> _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];
  
  Future<bool> requestPermissions() async {
    return await _health.requestAuthorization(_types);
  }
  
  @override
  Stream<HeartRateReading> get heartRateStream {
    return Stream.periodic(Duration(seconds: 5), (_) async {
      final now = DateTime.now();
      final data = await _health.getHealthDataFromTypes(
        now.subtract(Duration(seconds: 10)),
        now,
        [HealthDataType.HEART_RATE],
      );
      
      if (data.isNotEmpty) {
        final latest = data.last;
        return HeartRateReading(
          timestamp: latest.dateFrom,
          bpm: (latest.value as num).round(),
          source: HeartRateSource.appleWatch,
        );
      }
      return null;
    }).where((r) => r != null).cast<HeartRateReading>();
  }
  
  @override
  Future<RecoveryMetrics?> getRecoveryMetrics(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(Duration(days: 1));
    
    // Get HRV
    final hrvData = await _health.getHealthDataFromTypes(
      start, end, [HealthDataType.HEART_RATE_VARIABILITY_SDNN]);
    
    // Get resting HR
    final restingHRData = await _health.getHealthDataFromTypes(
      start, end, [HealthDataType.RESTING_HEART_RATE]);
    
    // Get sleep (if available)
    final sleepData = await _health.getHealthDataFromTypes(
      start, end, [HealthDataType.SLEEP_ASLEEP]);
    
    return RecoveryMetrics(
      date: date,
      hrvMs: hrvData.isNotEmpty ? (hrvData.first.value as num).round() : null,
      restingHeartRate: restingHRData.isNotEmpty 
          ? (restingHRData.first.value as num).round() : null,
      sleepDuration: _calculateSleepDuration(sleepData),
      recoveryScore: _calculateRecoveryScore(hrvData, restingHRData, sleepData),
    );
  }
  
  @override
  Future<void> syncWorkout(WorkoutSession session) async {
    await _health.writeWorkoutData(
      HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
      session.startTime,
      session.endTime,
      totalEnergyBurned: session.biometrics?.caloriesBurned?.round(),
    );
  }
  
  double _calculateRecoveryScore(
    List<HealthDataPoint> hrv,
    List<HealthDataPoint> restingHR,
    List<HealthDataPoint> sleep,
  ) {
    double score = 50.0; // Base score
    
    // HRV contribution (higher is better)
    if (hrv.isNotEmpty) {
      final hrvValue = (hrv.first.value as num).toDouble();
      score += (hrvValue - 30) * 0.5; // Adjust based on baseline
    }
    
    // Resting HR contribution (lower is better)
    if (restingHR.isNotEmpty) {
      final hr = (restingHR.first.value as num).toDouble();
      score += (70 - hr) * 0.3;
    }
    
    // Sleep contribution
    if (sleep.isNotEmpty) {
      final sleepHours = _calculateSleepDuration(sleep).inMinutes / 60;
      if (sleepHours >= 7) score += 15;
      else if (sleepHours >= 6) score += 10;
      else score -= 10;
    }
    
    return score.clamp(0, 100);
  }
}
```

## Implementation Phases

### Phase 1: Health Platform Integration (4-5 days)
- [ ] HealthKit integration (iOS)
- [ ] Health Connect integration (Android)
- [ ] Permission handling
- [ ] Basic data reading

### Phase 2: Live Heart Rate (3-4 days)
- [ ] Real-time HR streaming
- [ ] HR display during workout
- [ ] Heart rate zones calculation
- [ ] Zone time tracking

### Phase 3: Recovery Metrics (3-4 days)
- [ ] HRV reading and display
- [ ] Recovery score algorithm
- [ ] Recovery dashboard UI
- [ ] Training recommendations

### Phase 4: Workout Sync (2-3 days)
- [ ] Write workouts to health apps
- [ ] Bi-directional sync
- [ ] Conflict resolution
- [ ] Sync status indicators

### Phase 5: Third-Party APIs (3-4 days)
- [ ] Fitbit OAuth integration
- [ ] Garmin Connect integration
- [ ] WHOOP API integration
- [ ] Data normalization layer

### Phase 6: Polish (2 days)
- [ ] Background sync
- [ ] Battery optimization
- [ ] Error handling
- [ ] Unit tests

## Dependencies

```yaml
dependencies:
  health: ^4.6.0                    # HealthKit & Health Connect
  permission_handler: ^11.1.0       # Handle permissions
  flutter_blue_plus: ^1.28.0        # Bluetooth for direct device
  oauth2: ^2.0.2                    # OAuth for third-party APIs
  http: ^1.1.0                      # API calls
```

## Privacy & Security

1. **Minimal Data Access** - Only request necessary permissions
2. **Local Processing** - Process health data on device
3. **Secure Storage** - Encrypt sensitive health data
4. **User Control** - Easy disconnect and data deletion
5. **Transparency** - Clear explanation of data usage
6. **Compliance** - HIPAA/GDPR considerations for health data

## Testing Considerations

### Unit Tests
- Heart rate zone calculations
- Recovery score algorithm
- Calorie calculations

### Integration Tests
- Health platform connectivity
- Data sync accuracy
- Permission flows

### Manual Testing
- Various wearable devices
- Low battery scenarios
- Bluetooth connectivity issues

## Edge Cases

1. **No wearable connected** - App works without biometric data
2. **Wearable disconnects mid-workout** - Cache last readings
3. **Missing permissions** - Graceful degradation
4. **Conflicting data sources** - Priority system
5. **Extremely high/low HR** - Validate readings
6. **Time zone differences** - Standardize to UTC

## Future Enhancements

- **Live Metrics on Watch** - Full workout logging on watch
- **Auto-Detect Workouts** - Start tracking from watch activity
- **Voice Commands** - Log sets via watch voice input
- **Real-time Coaching** - HR-based intensity suggestions
- **Advanced Analytics** - Long-term HRV trends, fitness age
- **Sleep-Based Scheduling** - Adjust workout timing based on sleep
