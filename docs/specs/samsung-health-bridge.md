# Samsung Health Bridge (`samsung-health-bridge`)
## Architecture & Technical Specification

**Version:** 1.0.0  
**Status:** Approved Architecture Draft  
**Target:** Standalone Native Android (Kotlin) Companion Application  
**Location:** `/samsung-health-bridge/`  

---

## 1. Executive Summary

### 1.1 The Challenge
Samsung Health collects advanced biometric and wearable telemetry from the Galaxy Watch (such as BIA Body Composition, overnight Skin Temperature, and Sleep Stages), but deliberately restricts or omits many of these proprietary metrics from syncing into Google Health Connect. Consequently, third-party fitness and health applications cannot access these metrics through standard Android APIs.

Bundling the proprietary Samsung Health Data SDK directly into RepForge introduces significant drawbacks:
- Violates F-Droid and pure open-source distribution requirements due to proprietary `.aar` binaries.
- Couples the core workout logger with Samsung-specific Developer Mode registration, partner approval gates, and developer certificate management.
- Forces all users—including those on Pixel Watch, Garmin, or Apple Watch—to carry Samsung SDK bloat.

### 1.2 The Solution: Standalone Companion Bridge
The **Samsung Health Bridge** (`samsung-health-bridge`) is a decoupled, ultra-lightweight native Kotlin Android utility. It acts as an open protocol bridge:
1. **Reads** proprietary telemetry from the **Samsung Health Data SDK** on the device.
2. **Translates** each metric into standard Android Health Connect records (`androidx.health.connect.client.records.*`).
3. **Writes** the records into **Google Health Connect** via `HealthConnectClient`.
4. **RepForge** (and any other open-source or commercial fitness app) simply reads all metrics from Health Connect using standard, unprivileged Android APIs.

```
┌─────────────────────────────────┐
│          Galaxy Watch           │
│ (PPG, BIA, Infrared Temp, Accel)│
└────────────────┬────────────────┘
                 │ Bluetooth / S-Health Sync
                 ▼
┌─────────────────────────────────┐
│       Samsung Health App        │
│  (Holds proprietary raw store)  │
└────────────────┬────────────────┘
                 │ Samsung Health Data SDK (v1.1.0)
                 ▼
┌────────────────────────────────────────────────────────┐
│         Samsung Health Bridge (Companion App)          │
│                                                        │
│  ┌──────────────────┐        ┌──────────────────────┐  │
│  │ SamsungReader    │───────►│ DataMapper           │  │
│  └──────────────────┘        └──────────┬───────────┘  │
│                                         │              │
│  ┌──────────────────┐                   ▼              │
│  │ WorkManager Sync │◄───────┌──────────────────────┐  │
│  └──────────────────┘        │ HealthConnectWriter  │  │
│                              └──────────┬───────────┘  │
└─────────────────────────────────────────┼──────────────┘
                                          │ HealthConnectClient.insertRecords()
                                          ▼
┌────────────────────────────────────────────────────────┐
│                 Google Health Connect                  │
│       (Unified Android Health & Fitness Database)      │
└──────────────────────────┬─────────────────────────────┘
                           │ Standard Health Connect Read APIs
                           ▼
┌────────────────────────────────────────────────────────┐
│                   RepForge Main App                    │
│      (Workout Logging · AI Coach · Recovery Radar)     │
└────────────────────────────────────────────────────────┘
```

---

## 2. Technical Stack & Dependencies

| Layer | Technology | Specification / Version |
|---|---|---|
| **Language** | Kotlin | 2.0.0+ |
| **Android SDK** | Android 10+ (API 29+) | `minSdk = 29`, `targetSdk = 35`, `compileSdk = 35` |
| **Samsung SDK** | Samsung Health Data SDK | `samsung-health-data-api-1.1.0.aar` |
| **Health Connect** | AndroidX Health Connect Client | `androidx.health.connect:connect-client:1.1.0-alpha11` |
| **Background Scheduling** | AndroidX WorkManager | `androidx.work:work-runtime-ktx:2.10.0` |
| **Concurrency** | Kotlin Coroutines | `kotlinx-coroutines-android:1.8.1` |
| **UI Framework** | Jetpack Compose / Material 3 | Modern, dark-mode first, ultra-low APK footprint (< 3 MB) |

---

## 3. Data Mapping & Schema Transformation

Every metric extracted from Samsung Health is mapped deterministically to its canonical Google Health Connect counterpart, applying proper unit conversions, timestamps, and deduplication IDs:

### 3.1 Body Composition (BIA)
Samsung Health computes full Bioelectrical Impedance Analysis. The bridge breaks these down into distinct Health Connect records:

| S-Health Field | Health Connect Record | Target Unit | Notes |
|---|---|---|---|
| `BODY_FAT` | `BodyFatRecord` | `Percentage` (0.0 – 100.0) | Direct percentage conversion |
| `SKELETAL_MUSCLE_MASS` | `LeanBodyMassRecord` | `Mass.kilograms(kg)` | Extracted from BIA calculation |
| `FAT_FREE_MASS` | `LeanBodyMassRecord` | `Mass.kilograms(kg)` | Fallback if skeletal muscle is absent |
| `WEIGHT` | `WeightRecord` | `Mass.kilograms(kg)` | Scale/impedance body weight |
| `BASAL_METABOLIC_RATE` | `BasalMetabolicRateRecord` | `Power.kilocaloriesPerDay(kcal)` | Standard BMR energy baseline |
| `TOTAL_BODY_WATER` | `BodyWaterMassRecord` | `Mass.kilograms(kg)` | Intracellular + extracellular fluid |

### 3.2 Overnight Skin Temperature
Samsung Galaxy Watch 5/6/7 records overnight continuous surface temperature:
- **Health Connect Target**: `SkinTemperatureRecord` / `BasalBodyTemperatureRecord`
- **Data Extracted**:
  - `BASELINE_TEMPERATURE`: Written as nocturnal baseline point.
  - `SERIES_DATA`: Intraday temperature delta curve sampled during sleep.
- **Unit**: `Temperature.celsius(degC)`.

### 3.3 Sleep Sessions & Sleep Stages
- **Health Connect Target**: `SleepSessionRecord`
- **Session Duration**: `startTime` and `endTime` mapped directly.
- **Stage Breakdown**:
  - `STAGE_DEEP` ➔ `SleepSessionRecord.STAGE_TYPE_DEEP`
  - `STAGE_REM` ➔ `SleepSessionRecord.STAGE_TYPE_REM`
  - `STAGE_LIGHT` ➔ `SleepSessionRecord.STAGE_TYPE_LIGHT`
  - `STAGE_AWAKE` ➔ `SleepSessionRecord.STAGE_TYPE_AWAKE`

### 3.4 Respiratory Rate (Nocturnal & Epochs)
- **Health Connect Target**: `RespiratoryRateRecord`
- **Rate**: Breaths per minute (e.g., `14.8`).
- **Granularity**:
  - **Overnight Average**: 1 summary record per sleep window.
  - **Intraday Sleep Epochs**: Multi-point samples across the sleep duration when available in the raw series.

### 3.5 Vitals & Cardiac
- **Resting Heart Rate**: `RestingHeartRateRecord` (bpm at rest/waking).
- **Continuous Heart Rate**: `HeartRateRecord` with timestamped `HeartRateRecord.Sample` entries.
- **Heart Rate Variability**: `HeartRateVariabilityRmssdRecord` (RMSSD in milliseconds).
- **Blood Oxygen**: `OxygenSaturationRecord` (percentage, e.g. `98.0%`).
- **Blood Pressure**: `BloodPressureRecord` (`Pressure.millimetersOfMercury(mmHg)` for systolic & diastolic).

---

## 4. Deduplication & Idempotency Strategy

To prevent duplicate records in Health Connect across multiple sync runs:
1. Every record generated by `DataMapper` assigns a deterministic `clientRecordId` in its `Metadata`:
   ```kotlin
   val clientRecordId = "shealth_${dataType}_${recordTimestampEpochMs}"
   val metadata = Metadata.manualEntry(
       clientRecordId = clientRecordId,
       clientRecordVersion = 1L
   )
   ```
2. When calling `healthConnectClient.insertRecords(chunk)`:
   - If a record with the same `clientRecordId` already exists in Health Connect, Health Connect updates it in place rather than creating a duplicate entry.
3. The sync engine maintains a persistent `SharedPreferences` cursor storing `last_successful_sync_timestamp` to optimize incremental queries.

---

## 5. Synchronization Engine

### 5.1 Modes of Operation
1. **Manual Sync ("Sync Now")**:
   - Triggered by user button tap in the app.
   - Lookback window: Configurable (7 days, 30 days, or 90 days initial backfill).
   - Displays real-time progress bar and record tally per metric.
2. **Automated Background Sync (`WorkManager`)**:
   - Implemented via `HealthBridgeSyncWorker : CoroutineWorker`.
   - Scheduled via `PeriodicWorkRequestBuilder` with interval of 4 to 6 hours.
   - Constraints:
     - `NetworkType.NOT_REQUIRED` (entirely on-device IPC).
     - `setRequiresBatteryNotLow(true)`.

### 5.2 Chunking & IPC Safety
Google Health Connect imposes transaction payload limits on Android Binder calls. The sync engine chunks inserts:
```kotlin
records.chunked(500).forEach { chunk ->
    healthConnectClient.insertRecords(chunk)
}
```

---

## 6. Permissions & Security Protocol

### 6.1 Samsung Health Developer Mode
- **Package Name**: `com.repforge.healthbridge`
- **Signing Keystore**: Dedicated debug & release keystore with stable SHA-256 fingerprint.
- **UI Guide**: The bridge app home screen displays:
  - App Package Name (`com.repforge.healthbridge`).
  - SHA-256 Fingerprint with a one-tap **Copy Fingerprint** button.
  - Step-by-step instructions to register under Samsung Health Developer Mode.

### 6.2 Health Connect Permissions
Declared in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.health.WRITE_BODY_FAT" />
<uses-permission android:name="android.permission.health.WRITE_LEAN_BODY_MASS" />
<uses-permission android:name="android.permission.health.WRITE_WEIGHT" />
<uses-permission android:name="android.permission.health.WRITE_BASAL_METABOLIC_RATE" />
<uses-permission android:name="android.permission.health.WRITE_BODY_WATER_MASS" />
<uses-permission android:name="android.permission.health.WRITE_SKIN_TEMPERATURE" />
<uses-permission android:name="android.permission.health.WRITE_SLEEP" />
<uses-permission android:name="android.permission.health.WRITE_RESPIRATORY_RATE" />
<uses-permission android:name="android.permission.health.WRITE_HEART_RATE" />
<uses-permission android:name="android.permission.health.WRITE_RESTING_HEART_RATE" />
<uses-permission android:name="android.permission.health.WRITE_HEART_RATE_VARIABILITY" />
<uses-permission android:name="android.permission.health.WRITE_OXYGEN_SATURATION" />
<uses-permission android:name="android.permission.health.WRITE_BLOOD_PRESSURE" />
```

---

## 7. Directory Structure (`samsung-health-bridge/`)

```
samsung-health-bridge/
├── SPECIFICATION.md
├── build.gradle.kts
├── settings.gradle.kts
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
└── app/
    ├── build.gradle.kts
    ├── proguard-rules.pro
    ├── libs/
    │   └── samsung-health-data-api-1.1.0.aar
    └── src/
        └── main/
            ├── AndroidManifest.xml
            ├── res/
            │   ├── values/
            │   │   ├── strings.xml
            │   │   ├── colors.xml
            │   │   └── themes.xml
            │   └── mipmap-*/
            └── kotlin/com/repforge/healthbridge/
                ├── MainActivity.kt                 # Single-screen dashboard UI
                ├── HealthBridgeApp.kt              # Application class & WorkManager init
                ├── ui/
                │   ├── DashboardScreen.kt          # Status cards, sync button, log stream
                │   └── DeveloperModeCard.kt        # Fingerprint & instructions card
                ├── sync/
                │   ├── SamsungHealthReader.kt      # Queries S-Health Data SDK
                │   ├── DataMapper.kt               # Translates S-Health -> Health Connect
                │   ├── HealthConnectWriter.kt      # Chunked batch insert into HC
                │   └── HealthBridgeSyncWorker.kt   # Periodic background CoroutineWorker
                └── util/
                    ├── CertificateHelper.kt        # Extracts SHA-256 fingerprint
                    └── SyncPreferences.kt          # Sync timestamps & history
```

---

## 8. Rollout & Integration Plan

1. **Phase 1: Project Scaffolding & Build**
   - Initialize Gradle wrapper, dependencies, manifest permissions, and Samsung SDK `.aar`.
   - Verify clean `./gradlew assembleDebug` build.
2. **Phase 2: Data Extraction & Transformation Engine**
   - Implement `SamsungHealthReader` and unit tests for `DataMapper`.
   - Implement `HealthConnectWriter` with transaction batching.
3. **Phase 3: UI & Permissions Flow**
   - Build Material 3 dashboard showing live connection status, Developer Mode fingerprint copy, and manual sync CTA.
4. **Phase 4: WorkManager Background Sync**
   - Wire `HealthBridgeSyncWorker` for automated background sync every 6 hours.
5. **Phase 5: Live Device Validation**
   - Install onto physical Galaxy Watch / Pixel device via ADB.
   - Run full 90-day sync.
   - Confirm records appear in Android Health Connect settings and are readable by RepForge.
