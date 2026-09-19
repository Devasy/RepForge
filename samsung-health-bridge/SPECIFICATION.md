# Samsung Health Bridge (`samsung-health-bridge`)
## Architecture & Technical Specification

See canonical document at [`docs/specs/samsung-health-bridge.md`](../docs/specs/samsung-health-bridge.md).

**Version:** 1.0.0  
**Status:** Approved Architecture Draft  
**Target:** Standalone Native Android (Kotlin) Companion Application  
**Package:** `com.repforge.healthbridge`  

---

## Quick Overview

The **Samsung Health Bridge** is a standalone, lightweight native Android companion application that:
1. Connects to Samsung Health via the native Samsung Health Data SDK (`samsung-health-data-api-1.1.0.aar`).
2. Extracts telemetry that Samsung Health does not write to Google Health Connect (BIA Body Fat, Skeletal Muscle, Water Mass, BMR, Overnight Skin Temperature, Sleep Stages, Respiratory Rate, Heart Rate).
3. Converts each metric to its corresponding standard `androidx.health.connect.client.records.*` type with deterministic deduplication IDs.
4. Writes the records into Google Health Connect using `HealthConnectClient.insertRecords()`.
5. Runs periodic automatic background synchronization via Android Jetpack `WorkManager`.

This enables **RepForge** to read all Galaxy Watch biometrics directly from standard Health Connect APIs without bundling proprietary Samsung libraries.

---

## Directory Structure
```
samsung-health-bridge/
├── SPECIFICATION.md
├── build.gradle.kts
├── settings.gradle.kts
└── app/
    ├── build.gradle.kts
    ├── libs/
    │   └── samsung-health-data-api-1.1.0.aar
    └── src/main/
        ├── AndroidManifest.xml
        └── kotlin/com/repforge/healthbridge/
            ├── MainActivity.kt
            ├── sync/
            │   ├── SamsungHealthReader.kt
            │   ├── DataMapper.kt
            │   ├── HealthConnectWriter.kt
            │   └── HealthBridgeSyncWorker.kt
            └── util/
                ├── CertificateHelper.kt
                └── SyncPreferences.kt
```
