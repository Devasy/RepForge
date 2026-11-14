# Flutter 3.50 upgrade (RepForge 2.2.5)

Release branch: `r2.2.5`, based on freshly fetched `origin/main` at `ab6ea06`.
App version: `2.2.5+76`.

## Toolchain

- Flutter 3.50.0 stable, bundled Dart 3.14.0.
- All five packages require Dart 3.14; the app pins Flutter exactly for CI and F-Droid extraction.
- Android Gradle Plugin 9.3.3, Gradle 9.5.0 (official distribution checksum), Kotlin plugin 2.4.20. CI uses Temurin JDK 21; Android Java/Kotlin bytecode remains targeted at 17.
- Retain Android API 37, minimum API 26, built-in Kotlin, and legacy Android DSL compatibility. Split-APK version codes use the public Android variant API.
- App/release CI reads the Flutter pin from pubspec; orchestration CI now uses the same Flutter/Dart versions.

## Compatibility changes

- Migrate app, widget tests and the Flutter orchestration package to `material_ui` 1.11.0.
- Keep a documented `MaterialUiCompatibilityBridge` around routes because `fl_chart` still reads the legacy Material theme. Remove the bridge once remaining dependencies migrate.
- Move split-APK version-code overrides to `androidComponents.onVariants` so they run after Flutter 3.50's default ABI offset callback. Preserve `buildNumber * 10 + ABI` as required by release checks and F-Droid.
- Existing nullable dropdown callbacks retain their disabled behavior; the new optional `enabled` argument is not required to preserve it.
- No removed `ignoringSemantics` arguments or legacy Material/Cupertino imports remain in app/shared Flutter source and tests.
- Migrate image attachment, program import and backup import to file_picker 13 single-file selection and nullable length APIs. Preserve cancellation, supported-image validation and the attachment size limit.
- Update backup-import test doubles to the new picker platform interface; cover image selection, cancellation, oversized files and unsupported image types.

## Dependencies

Compatible stable upgrades changed 60 resolved packages. Runtime updates include:

| Package | Resolved version |
| --- | --- |
| cupertino_icons | 2.0.0 |
| file_picker | 13.3.3 (replaces the previous beta) |
| fl_chart | 1.3.1 |
| health_connector | 3.14.1 |
| gpt_markdown | 1.4.1 |
| package_info_plus | 10.2.2 |
| share_plus | 13.3.1 |
| sqflite | 2.4.6 |
| jni (transitive) | 1.1.2 |

The app lockfile is retained. Newer analyzer-dependent development packages remain constrained by `custom_lint` 0.8.1's analyzer 8 requirement; no dependency overrides were introduced. `dart_code_linter`, `mockito` and `build_runner` use the latest mutually resolvable versions. Internal package formatter updates are required by Dart 3.14's format checks.

## Verification

- Initial SDK-upgrade app tests: 1,505 passed, one opt-in live Coach evaluation skipped.
- Four orchestration packages: 92 tests passed; strict analysis and formatting checks passed.
- Release readiness for `r2.2.5` and all 15 release-script tests passed.
- App analysis passes the existing CI policy with zero errors; 397 warning/info diagnostics remain, including legacy analyzer-plugin warnings. Deprecated framework design imports were migrated.
- Complexity metrics and custom lint pass their existing nonfatal-warning policy; custom lint reports 36 warnings.
- `flutter pub get --enforce-lockfile` passes; Dart migration previews report the five packages already at the target SDK.
- Use AGP 9.3.3 rather than Flutter's 9.3.1 template default: it includes the bundled Android Lint JavaDocParser fix for JDK 17 (Android issue 522845800) and R8 reproducibility/Windows fixes, preserving the existing Java 17 local/CI/F-Droid setup. See the [official AGP release notes](https://developer.android.com/build/releases/agp-9-3-0-release-notes).
- `flutter build apk --release --split-per-abi --no-pub` passes on Java 17 with AGP 9.3.3 and all lint checks enabled. ARMv7, ARM64 and x86_64 APKs identify as `com.devasy.repforge`, version `2.2.5`, with version codes `761`, `762` and `763`. Local output: `workout-logger/build/app/outputs/flutter-apk/`.

The upgraded JNI CMake file still contains the `-Wl,` pattern used by the existing CI/F-Droid build-ID patch, including its 16 KiB page-size linker flag. The release workflow retains `LDFLAGS=-Wl,--build-id=none`. This source audit does not establish byte-for-byte Linux/F-Droid reproducibility.

Device behavior, iOS/macOS builds, and optional scrolling/clipping redesigns were not part of this validation.

## CI follow-up

- Add program-file selection, cancellation, read-failure and required-field type-validation/recovery widget tests covering the changed lines, without lowering Codecov thresholds.
- Pin maintained Node 24 Actions (or composite Actions) by verified commit SHA; preserve ZIP artifacts and skip recompression of APK/AAB archives.
- Use JDK 21 LTS for CI and keep Android bytecode at 17.
- Keep sequential release AAB/APK compilation reuse, enable Gradle task caching, and separate manual validation concurrency from publication. Configuration caching remains disabled.
- Avoid redundant release-branch push checks and dispatch preparation checks only after a bot version commit; retain PR, main and manual checks.
- Cache pure-Dart package dependencies, pin Linux runners to Ubuntu 24.04, enforce the app lockfile, and verify release APK identity/version/code in PR CI.
- The last successful pre-change publication job took 10m05s. Eleven minutes is a performance target to measure on GitHub-hosted runners, not a timeout or guaranteed SLA. Manual release-branch runs never publish or deploy. Branch-scoped caches from manual runs do not seed main's publication cache.
