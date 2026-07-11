import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.devasy.repforge"
    compileSdk = 37
    // compileSdkExtension = 19
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Strip AGP's "Dependency metadata" signing block from the APK. It embeds a
    // Protobuf list of dependencies in an extra APK signing block, which F-Droid's
    // `scanner` rejects ("Found extra signing block 'Dependency metadata'"). It is
    // only consumed by Google Play, so disabling it is safe.
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_PATH")
            val storePass    = System.getenv("KEY_STORE_PASSWORD")
            val alias        = System.getenv("KEY_ALIAS")
            val keyPass      = System.getenv("KEY_PASSWORD")
            if (keystorePath != null && storePass != null && alias != null && keyPass != null) {
                storeFile     = file(keystorePath)
                storePassword = storePass
                keyAlias      = alias
                keyPassword   = keyPass
            }
        }
    }

    defaultConfig {
        applicationId = "com.devasy.repforge"
        // MIGRATION NOTE: minSdk is intentionally set to 26 (Android 8.0 Oreo).
        // Health Connect requires API 26+. Devices running API <26 are no longer
        // supported. If downgrading, remove the health_connector dependency and
        // all HealthConnectService usages, then restore minSdk to flutter.minSdkVersion.
        minSdk = 26
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // App display name; overridden per build type below so debug installs
        // alongside the real app instead of replacing it.
        manifestPlaceholders["appLabel"] = "RepForge"
    }

    buildTypes {
        debug {
            // Install debug builds as a SEPARATE app (com.devasy.repforge.debug)
            // with its own data sandbox, so testing never touches the real app's
            // data. Remove this block to go back to a single shared package.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            manifestPlaceholders["appLabel"] = "RepForge (Debug)"
        }
        release {
            // Uses the production EC P-256 keystore when KEYSTORE_PATH env var is set
            // (CI injects it via GitHub Secrets). Falls back to the debug key for a
            // local `flutter run --release` without env vars configured.
            //
            // This MUST stay on a single line beginning with `signingConfig` so the
            // F-Droid build server's signing-key stripper removes the whole statement
            // (it deletes the `signingConfigs { ... }` block too, after which any
            // surviving reference like `signingConfigs.getByName("release")` would
            // fail with "SigningConfig with name 'release' not found"). F-Droid then
            // signs the APK with its own key.
            signingConfig = signingConfigs.findByName("release")?.takeIf { it.storeFile != null } ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
        }
    }
}

