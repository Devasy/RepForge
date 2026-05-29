plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.devasy.repforge"
    compileSdk = 36
    compileSdkExtension = 19
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.devasy.repforge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // MIGRATION NOTE: minSdk is intentionally set to 26 (Android 8.0 Oreo).
        // Health Connect requires API 26+. Devices running API <26 are no longer
        // supported. If downgrading, remove the health_connector dependency and
        // all HealthConnectService usages, then restore minSdk to flutter.minSdkVersion.
        minSdk = 26
        targetSdk = 36
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
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
