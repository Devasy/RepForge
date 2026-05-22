# RepForge AppFunctions (pending activation)

`RepForgeAppFunctions.kt.pending` exposes RepForge's workout data and actions to
the on-device OS AI agent (Gemini) via Android **AppFunctions**. It reads the
JSON mirror the Flutter app keeps in sync (`agent_mirror.json` in the app's
files directory) so queries work without a running Flutter engine, and routes
writes through a confirmation screen.

It is **not compiled** — the `.kt.pending` extension keeps it out of the source
set — because `androidx.appfunctions:1.0.0-alpha09` requires a toolchain upgrade
the rest of the project has not yet taken.

## Why it is not active

`androidx.appfunctions:*:1.0.0-alpha09` requires:

- **Android Gradle Plugin 9.1.0+** — the project currently uses 8.9.1.
- **compileSdk 37+** — the project currently uses 36.

Bumping AGP to 9.x is a major change that also affects the release CI, so it was
deliberately not done as part of this feature.

## How to activate

1. Upgrade the toolchain (verify Flutter compatibility first):
   - `android/settings.gradle.kts`: `com.android.application` → `9.1.0` (or newer).
   - `android/app/build.gradle.kts`: `compileSdk = 37`.
   - Bump the Gradle wrapper if AGP 9.x requires it.

2. Re-add KSP to `android/settings.gradle.kts` plugins block:
   ```kotlin
   id("com.google.devtools.ksp") version "2.1.0-1.0.29" apply false
   ```

3. Re-add to `android/app/build.gradle.kts`:
   ```kotlin
   // plugins { } — after kotlin-android, before the Flutter plugin
   id("com.google.devtools.ksp")

   // after the flutter { } block
   ksp { arg("appfunctions:aggregateAppFunctions", "true") }
   dependencies {
       implementation("androidx.appfunctions:appfunctions:1.0.0-alpha09")
       implementation("androidx.appfunctions:appfunctions-service:1.0.0-alpha09")
       ksp("androidx.appfunctions:appfunctions-compiler:1.0.0-alpha09")
   }
   ```

4. Rename `RepForgeAppFunctions.kt.pending` → `RepForgeAppFunctions.kt`.

5. `flutter build apk` and verify. The AppFunctions API is alpha — if
   `AppFunctionContext.context` or an annotation signature has changed, adjust
   against the current `androidx.appfunctions` reference.

The Flutter-side bridge (`MainActivity.kt` method channel, `agent_mirror.json`
writer, `AgentConfirmScreen`) is already wired and needs no changes.
