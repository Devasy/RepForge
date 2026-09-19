import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // kotlin-android is injected automatically by Flutter's built-in Kotlin support.
    // (android.builtInKotlin=true in gradle.properties)
    id("dev.flutter.flutter-gradle-plugin")
    id("kotlin-parcelize")
}

android {
    namespace = "com.devasy.repforge"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
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
            val keyProperties = Properties()
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                keyProperties.load(FileInputStream(keyPropertiesFile))
            }
            val keystorePath = System.getenv("KEYSTORE_PATH")?.trim() ?: keyProperties.getProperty("storeFile")?.trim()
            val storePass    = System.getenv("KEYSTORE_PASSWORD")?.trim() ?: System.getenv("KEY_STORE_PASSWORD")?.trim() ?: keyProperties.getProperty("storePassword")?.trim()
            val alias        = System.getenv("KEY_ALIAS")?.trim() ?: keyProperties.getProperty("keyAlias")?.trim()
            val keyPass      = System.getenv("KEY_PASSWORD")?.trim() ?: keyProperties.getProperty("keyPassword")?.trim()
            if (!keystorePath.isNullOrEmpty() && !storePass.isNullOrEmpty() && !alias.isNullOrEmpty() && !keyPass.isNullOrEmpty()) {
                storeFile     = file(keystorePath)
                storePassword = storePass
                keyAlias      = alias
                keyPassword   = keyPass
            }
        }
    }

    defaultConfig {
        applicationId = "com.devasy.repforge"
        // MIGRATION NOTE: minSdk is set to 29 (Android 10) required by Samsung Health Data SDK 1.1.0.
        minSdk = 29
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

dependencies {
    implementation(files("libs/samsung-health-data-api-1.1.0.aar"))
    implementation("com.google.code.gson:gson:2.13.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}


