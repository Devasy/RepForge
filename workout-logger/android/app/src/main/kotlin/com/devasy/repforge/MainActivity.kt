package com.devasy.repforge

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.time.Instant
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

import com.samsung.android.sdk.health.data.HealthDataService
import com.samsung.android.sdk.health.data.data.Field
import com.samsung.android.sdk.health.data.data.HealthDataPoint
import com.samsung.android.sdk.health.data.permission.AccessType
import com.samsung.android.sdk.health.data.permission.Permission
import com.samsung.android.sdk.health.data.request.DataType
import com.samsung.android.sdk.health.data.request.DataTypes
import com.samsung.android.sdk.health.data.request.InstantTimeFilter
import com.samsung.android.sdk.health.data.request.LocalDateFilter
import com.samsung.android.sdk.health.data.request.Ordering

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.devasy.repforge/samsung_health_probe"
    private val SHEALTH_PACKAGE = "com.sec.android.app.shealth"

    private val directPermissions: Set<Permission> by lazy {
        setOf(
            Permission.of(DataTypes.BODY_COMPOSITION, AccessType.READ),
            Permission.of(DataTypes.ENERGY_SCORE, AccessType.READ),
            Permission.of(DataTypes.BLOOD_PRESSURE, AccessType.READ),
            Permission.of(DataTypes.BLOOD_OXYGEN, AccessType.READ),
            Permission.of(DataTypes.HEART_RATE, AccessType.READ),
            Permission.of(DataTypes.SKIN_TEMPERATURE, AccessType.READ),
            Permission.of(DataTypes.SLEEP, AccessType.READ)
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSamsungHealthDiagnostics" -> {
                    try {
                        val pm = packageManager
                        val diagnostics = mutableMapOf<String, Any?>()

                        // 1. App's own package & SHA-256 (required for Samsung Health Developer Mode / Partnership)
                        val myPackageName = applicationContext.packageName
                        diagnostics["appPackageName"] = myPackageName
                        diagnostics["appSha256Fingerprint"] = getAppSha256(myPackageName)

                        // 2. Query Samsung Health app info
                        try {
                            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                PackageManager.PackageInfoFlags.of(
                                    (PackageManager.GET_SERVICES or PackageManager.GET_PROVIDERS or PackageManager.GET_ACTIVITIES).toLong()
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                (PackageManager.GET_SERVICES or PackageManager.GET_PROVIDERS or PackageManager.GET_ACTIVITIES)
                            }

                            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                pm.getPackageInfo(SHEALTH_PACKAGE, flags as PackageManager.PackageInfoFlags)
                            } else {
                                @Suppress("DEPRECATION")
                                pm.getPackageInfo(SHEALTH_PACKAGE, flags as Int)
                            }

                            val appInfo = info.applicationInfo
                            val isEnabled = appInfo?.enabled ?: false
                            val versionName = info.versionName ?: "unknown"
                            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                info.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                info.versionCode.toLong()
                            }

                            diagnostics["installed"] = true
                            diagnostics["versionName"] = versionName
                            diagnostics["versionCode"] = versionCode
                            diagnostics["enabled"] = isEnabled

                            // Extract exported services & providers
                            val services = info.services?.map { it.name } ?: emptyList<String>()
                            val providers = info.providers?.map { "${it.name} (${it.authority})" } ?: emptyList<String>()

                            diagnostics["services"] = services
                            diagnostics["providers"] = providers
                            diagnostics["servicesCount"] = services.size
                            diagnostics["providersCount"] = providers.size

                        } catch (e: PackageManager.NameNotFoundException) {
                            diagnostics["installed"] = false
                            diagnostics["versionName"] = ""
                            diagnostics["versionCode"] = 0L
                            diagnostics["enabled"] = false
                            diagnostics["services"] = emptyList<String>()
                            diagnostics["providers"] = emptyList<String>()
                            diagnostics["servicesCount"] = 0
                            diagnostics["providersCount"] = 0
                        }

                        result.success(diagnostics)
                    } catch (e: Exception) {
                        result.error("DIAGNOSTICS_ERROR", e.localizedMessage, null)
                    }
                }
                "launchSamsungHealth" -> {
                    try {
                        val launchIntent = packageManager.getLaunchIntentForPackage(SHEALTH_PACKAGE)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_ERROR", e.localizedMessage, null)
                    }
                }
                "openSamsungHealthSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", SHEALTH_PACKAGE, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "getSamsungHealthPermissions" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val store = HealthDataService.getStore(applicationContext)
                            val granted = withContext(Dispatchers.IO) {
                                store.getGrantedPermissions(directPermissions)
                            }
                            result.success(granted.map { it.dataType.name })
                        } catch (e: Exception) {
                            // Non-fatal, return empty list
                            result.success(emptyList<String>())
                        }
                    }
                }
                "requestSamsungHealthPermissions" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val store = HealthDataService.getStore(applicationContext)
                            val granted = store.requestPermissions(directPermissions, this@MainActivity)
                            result.success(granted.map { it.dataType.name })
                        } catch (e: Exception) {
                            result.error("PERMISSION_ERROR", e.localizedMessage ?: e.toString(), null)
                        }
                    }
                }
                "readSamsungHealthData" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val store = HealthDataService.getStore(applicationContext)
                            val data = withContext(Dispatchers.IO) {
                                val results = mutableMapOf<String, Any?>()
                                val errors = mutableMapOf<String, String>()

                                // 1. BODY_COMPOSITION (BIA: body fat, muscle mass, water, BMR, etc.)
                                try {
                                    val req = DataTypes.BODY_COMPOSITION.readDataRequestBuilder
                                        .setInstantTimeFilter(InstantTimeFilter.since(Instant.now().minus(180, ChronoUnit.DAYS)))
                                        .setOrdering(Ordering.DESC)
                                        .setLimit(50)
                                        .build()
                                    val resp = store.readData(req)
                                    val compList = resp.dataList.map { point ->
                                        mapOf(
                                            "uid" to point.uid,
                                            "startTime" to point.startTime.toString(),
                                            "endTime" to point.endTime?.toString(),
                                            "weightKg" to point.safeVal(DataType.BodyCompositionType.WEIGHT),
                                            "heightM" to point.safeVal(DataType.BodyCompositionType.HEIGHT),
                                            "bodyFatPercent" to point.safeVal(DataType.BodyCompositionType.BODY_FAT),
                                            "bodyFatMassKg" to point.safeVal(DataType.BodyCompositionType.BODY_FAT_MASS),
                                            "skeletalMusclePercent" to point.safeVal(DataType.BodyCompositionType.SKELETAL_MUSCLE),
                                            "skeletalMuscleMassKg" to point.safeVal(DataType.BodyCompositionType.SKELETAL_MUSCLE_MASS),
                                            "muscleMassKg" to point.safeVal(DataType.BodyCompositionType.MUSCLE_MASS),
                                            "fatFreeMassKg" to point.safeVal(DataType.BodyCompositionType.FAT_FREE_MASS),
                                            "fatFreePercent" to point.safeVal(DataType.BodyCompositionType.FAT_FREE),
                                            "totalBodyWaterL" to point.safeVal(DataType.BodyCompositionType.TOTAL_BODY_WATER),
                                            "bmrKcal" to point.safeVal(DataType.BodyCompositionType.BASAL_METABOLIC_RATE),
                                            "bmi" to point.safeVal(DataType.BodyCompositionType.BODY_MASS_INDEX)
                                        )
                                    }
                                    results["bodyComposition"] = compList
                                } catch (e: Exception) {
                                    errors["bodyComposition"] = e.localizedMessage ?: e.toString()
                                }

                                // 2. ENERGY_SCORE (Galaxy Ring / Galaxy Watch Energy Score)
                                try {
                                    val req = DataTypes.ENERGY_SCORE.readDataRequestBuilder
                                        .setLocalDateFilter(LocalDateFilter.since(LocalDate.now().minusDays(90)))
                                        .setOrdering(Ordering.DESC)
                                        .setLimit(90)
                                        .build()
                                    val resp = store.readData(req)
                                    val energyList = resp.dataList.map { point ->
                                        mapOf(
                                            "uid" to point.uid,
                                            "date" to point.startTime.toString(),
                                            "score" to point.safeVal(DataType.EnergyScoreType.ENERGY_SCORE)
                                        )
                                    }
                                    results["energyScore"] = energyList
                                } catch (e: Exception) {
                                    errors["energyScore"] = e.localizedMessage ?: e.toString()
                                }

                                // 3. BLOOD_PRESSURE
                                try {
                                    val req = DataTypes.BLOOD_PRESSURE.readDataRequestBuilder
                                        .setInstantTimeFilter(InstantTimeFilter.since(Instant.now().minus(90, ChronoUnit.DAYS)))
                                        .setOrdering(Ordering.DESC)
                                        .setLimit(50)
                                        .build()
                                    val resp = store.readData(req)
                                    val bpList = resp.dataList.map { point ->
                                        mapOf(
                                            "uid" to point.uid,
                                            "startTime" to point.startTime.toString(),
                                            "systolic" to point.safeVal(DataType.BloodPressureType.SYSTOLIC),
                                            "diastolic" to point.safeVal(DataType.BloodPressureType.DIASTOLIC),
                                            "mean" to point.safeVal(DataType.BloodPressureType.MEAN),
                                            "pulseRate" to point.safeVal(DataType.BloodPressureType.PULSE_RATE)
                                        )
                                    }
                                    results["bloodPressure"] = bpList
                                } catch (e: Exception) {
                                    errors["bloodPressure"] = e.localizedMessage ?: e.toString()
                                }

                                // 4. BLOOD_OXYGEN (SpO2)
                                try {
                                    val req = DataTypes.BLOOD_OXYGEN.readDataRequestBuilder
                                        .setInstantTimeFilter(InstantTimeFilter.since(Instant.now().minus(30, ChronoUnit.DAYS)))
                                        .setOrdering(Ordering.DESC)
                                        .setLimit(50)
                                        .build()
                                    val resp = store.readData(req)
                                    val spo2List = resp.dataList.map { point ->
                                        mapOf(
                                            "uid" to point.uid,
                                            "startTime" to point.startTime.toString(),
                                            "oxygenSaturation" to point.safeVal(DataType.BloodOxygenType.OXYGEN_SATURATION),
                                            "minOxygenSaturation" to point.safeVal(DataType.BloodOxygenType.MIN_OXYGEN_SATURATION),
                                            "maxOxygenSaturation" to point.safeVal(DataType.BloodOxygenType.MAX_OXYGEN_SATURATION)
                                        )
                                    }
                                    results["bloodOxygen"] = spo2List
                                } catch (e: Exception) {
                                    errors["bloodOxygen"] = e.localizedMessage ?: e.toString()
                                }

                                // 5. HEART_RATE
                                try {
                                    val req = DataTypes.HEART_RATE.readDataRequestBuilder
                                        .setInstantTimeFilter(InstantTimeFilter.since(Instant.now().minus(7, ChronoUnit.DAYS)))
                                        .setOrdering(Ordering.DESC)
                                        .setLimit(100)
                                        .build()
                                    val resp = store.readData(req)
                                    val hrList = resp.dataList.map { point ->
                                        mapOf(
                                            "uid" to point.uid,
                                            "startTime" to point.startTime.toString(),
                                            "heartRate" to point.safeVal(DataType.HeartRateType.HEART_RATE),
                                            "minHeartRate" to point.safeVal(DataType.HeartRateType.MIN_HEART_RATE),
                                            "maxHeartRate" to point.safeVal(DataType.HeartRateType.MAX_HEART_RATE)
                                        )
                                    }
                                    results["heartRate"] = hrList
                                } catch (e: Exception) {
                                    errors["heartRate"] = e.localizedMessage ?: e.toString()
                                }

                                // 6. SKIN_TEMPERATURE (Galaxy Watch 5/6/7 & Galaxy Ring)
                                try {
                                    val req = DataTypes.SKIN_TEMPERATURE.readDataRequestBuilder
                                        .setInstantTimeFilter(InstantTimeFilter.since(Instant.now().minus(90, ChronoUnit.DAYS)))
                                        .setOrdering(Ordering.DESC)
                                        .setLimit(100)
                                        .build()
                                    val resp = store.readData(req)
                                    val skinList = resp.dataList.map { point ->
                                        val series = try {
                                            point.getValue(DataType.SkinTemperatureType.SERIES_DATA)?.map { s ->
                                                mapOf(
                                                    "startTime" to s.startTime.toString(),
                                                    "endTime" to s.endTime?.toString(),
                                                    "skinTemperature" to s.skinTemperature,
                                                    "min" to s.min,
                                                    "max" to s.max
                                                )
                                            }
                                        } catch (e: Exception) {
                                            null
                                        }
                                        mapOf(
                                            "uid" to point.uid,
                                            "startTime" to point.startTime.toString(),
                                            "endTime" to point.endTime?.toString(),
                                            "skinTemperature" to point.safeVal(DataType.SkinTemperatureType.SKIN_TEMPERATURE),
                                            "minSkinTemperature" to point.safeVal(DataType.SkinTemperatureType.MIN_SKIN_TEMPERATURE),
                                            "maxSkinTemperature" to point.safeVal(DataType.SkinTemperatureType.MAX_SKIN_TEMPERATURE),
                                            "series" to series
                                        )
                                    }
                                    results["skinTemperature"] = skinList
                                } catch (e: Exception) {
                                    errors["skinTemperature"] = e.localizedMessage ?: e.toString()
                                }

                                // 7. SLEEP (Samsung Sleep Score & Session)
                                try {
                                    val req = DataTypes.SLEEP.readDataRequestBuilder
                                        .setInstantTimeFilter(InstantTimeFilter.since(Instant.now().minus(90, ChronoUnit.DAYS)))
                                        .setOrdering(Ordering.DESC)
                                        .setLimit(60)
                                        .build()
                                    val resp = store.readData(req)
                                    val sleepList = resp.dataList.map { point ->
                                        val durationMins = try {
                                            point.getValue(DataType.SleepType.DURATION)?.toMinutes()
                                        } catch (e: Exception) {
                                            null
                                        }
                                        mapOf(
                                            "uid" to point.uid,
                                            "startTime" to point.startTime.toString(),
                                            "endTime" to point.endTime?.toString(),
                                            "sleepScore" to point.safeVal(DataType.SleepType.SLEEP_SCORE),
                                            "durationMinutes" to durationMins
                                        )
                                    }
                                    results["directSleep"] = sleepList
                                } catch (e: Exception) {
                                    errors["directSleep"] = e.localizedMessage ?: e.toString()
                                }

                                results["errors"] = errors
                                results
                            }
                            result.success(data)
                        } catch (e: Exception) {
                            result.error("READ_DATA_ERROR", e.localizedMessage ?: e.toString(), null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun <T> HealthDataPoint.safeVal(field: Field<T>): T? {
        return try {
            getValue(field)
        } catch (e: Exception) {
            null
        }
    }

    private fun getAppSha256(packageName: String): String {
        return try {
            val pm = packageManager
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val signingInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES).signingInfo
                if (signingInfo != null) {
                    if (signingInfo.hasMultipleSigners()) signingInfo.apkContentsSigners else signingInfo.signingCertificateHistory
                } else null
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
            }

            if (signatures != null && signatures.isNotEmpty()) {
                val md = MessageDigest.getInstance("SHA-256")
                val digest = md.digest(signatures[0].toByteArray())
                digest.joinToString(":") { String.format("%02X", it) }
            } else {
                "Unavailable"
            }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }
}
