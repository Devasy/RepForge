# Changelog

User-facing changes. Follow [the changelog format](docs/changelog-format.md).

## [Unreleased]

## [2.1.7]

### Features added
- View detailed front and back muscle diagrams with selectable muscles and weekly volume shading.
- Existing users are asked for gender once after upgrading; the saved choice selects diagrams throughout the app and can subsequently be changed only in Profile.
- Explore labelled Stretched and Contracted exercise phases with blue and rose-red intensity scales for supported exercises.

### Known limitations
- Muscle phase views illustrate standard technique and catalogue target involvement; they do not measure live muscle stretch or force. Custom and unsupported exercises show target involvement only.

## [2.1.6]

### Features added
- Discover available stable Gemini Flash models from Google in AI settings.
- Read upgrade notes from the repository CHANGELOG.md, including skipped releases, with collapsible releases and change categories; show an update notice in Profile.
- Choose assisted or weighted load for pull-ups, chin-ups and dips; log push-ups with added weight.

### Fixes
- Debug installs can display release history and detect upgrades using the underlying app version.
- AI failures now show plain-language guidance instead of provider diagnostics, with a safe Retry action in the coach.
- Preserve training programs, personal records, coach and optimizer chats, and attachments in backups; reject malformed backups before importing.
- Preserve workout effort in SQLite and imported data.
- Accept settings-only backups and report refresh failures separately from failed imports.
- Skip malformed model and release entries without hiding valid discovery results.
- Keep legacy raw-load history separate from bodyweight-based trend and progression calculations (#67).
- Progress assisted exercises by reducing assistance; preserve bodyweight at logging time (#68).
- Preserve separate handle records with canonical exercise IDs across migrations and backups (#69).

### Known limitations
- Historical sets without a recorded bodyweight retain their original values. They cannot be converted reliably and are excluded from comparisons with the new load convention.
- Update notices use public GitHub releases; availability may differ by installation channel.
- Model discovery requires a valid Gemini API key. Refreshing the list preserves the selected model.

## [2.1.5]

### Fixes
- Remove unused Play Store deferred-component code from release APKs to satisfy open-source distribution checks (#84).

## [2.1.4]

### Fixes
- Align Android SDK 37 and release build settings for reproducible Android packages (#83).
- Fix Android SDK command-line tool setup in the build workflows (#83).

## [2.1.3]

### Features added
- Track time-based exercises with duration inputs, a countdown timer, and duration progression recommendations (#82).
- Record Best Hold personal records and automatically start rest when a timed set finishes (#82).
- Attach images to AI Coach conversations and preserve them in conversation history (#82).

### Fixes
- Correct time-based exercise metrics, personal records, and analytics displays (#82).
- Preserve countdown timer remainders when resuming and show session volumes in the selected weight unit (#82).

## [2.1.2]

### Features added
- Export explicit rest segments and real exercise names in Health Connect workout records (#78).
- Publish the app privacy policy for Google Play and Health Connect permissions.

### Fixes
- Preserve sets whose timestamps fall on workout boundaries during Health Connect export (#78).
- Export effective load for assisted exercises and retain useful notes when Health Connect segment weights are unsupported (#78).

### Changes
- Make the release available through Google Play closed testing.

## [2.1.1]

### Features added
- Show AI-generated charts, statistic cards, gauges, and other structured responses in AI Coach (#62).
- Migrate existing workout data from Hive to SQLite, retaining Hive as a fallback if migration fails (#62).
- Let AI Coach query workout, sleep, and heart-rate data through a read-only SQL tool (#62).
- Add recovery-, readiness-, and fatigue-aware workout recommendations and deload recovery guidance (#62).
- Add assisted-bodyweight load tracking, handle-specific personal records, and sleeping heart-rate analytics (#62).
- Configure Gemini thinking levels per model in AI settings (#62).

### Changes
- Refresh bottom navigation and shared screen layouts (#62).
- Update Android support and the build toolchain for Android 17 / API 37 (#62).

### Fixes
- Improve handling of malformed AI-generated UI payloads and Health Connect connection timeouts (#62).

### Known limitations
- Legacy raw-load sets and newer bodyweight-based sets can produce incompatible trend comparisons; corrected in 2.1.6 (#67).
- Push-ups and weighted pull-up, chin-up, and dip variants use the assisted interpretation; corrected in 2.1.6 (#68).
- Handle-specific personal records can break exercise-name resolution and exercise-wide queries; corrected in 2.1.6 (#69).

## [2.0.12]

### Removed
- Remove app telemetry, the analytics privacy toggle, and the telemetry backend integration (#75).

## [2.0.11]

### Fixes
- Disable telemetry by default for all installs, including existing installations (#74).

## [2.0.10]

### Features added
- Add a Privacy setting for opting into usage analytics (#73).

### Fixes
- Disable automatic telemetry for F-Droid installs (#73).

## [2.0.9]

### Changes
- Remove release-code obfuscation and enforce locked dependencies to improve reproducible builds (#72).
- Refresh the project documentation and app screenshots (#72).

## [2.0.8]

### Fixes
- Strip nondeterministic native build IDs from release builds to support F-Droid reproducibility checks (#71).
- Improve release build caching, concurrency handling, and signing-configuration errors (#71).

## [2.0.7]

### Changes
- Refresh F-Droid store metadata and publish an updated compatibility build (#70).

## [2.0.6]

### Changes
- Update F-Droid release version-code metadata; app functionality is unchanged in this release.

## [2.0.5]

### Changes
- Refresh app colors and styling through a centralized theme system (#56).

## [2.0.4]

### Fixes
- Remove Android dependency metadata signing blocks that caused F-Droid APK verification failures (#55).

## [2.0.3]

### Fixes
- Allow F-Droid to apply its own signing configuration without breaking release builds (#54).
- Shorten the store summary to fit F-Droid metadata limits (#54).

## [2.0.2]

### Changes
- Add F-Droid and IzzyOnDroid store metadata and pin dependencies for open-source distribution (#53).

## [2.0.1]

### Features added
- Show a post-workout summary with duration, volume, sets, exercises, and muscles trained (#48).
- Track weight, repetition, and volume personal records in Analytics and workout summaries (#48).
- Add Gemini AI coaching, AI program generation, and weekly workout insights (#48).
- Optimize routines through a conversational AI flow with follow-up questions and conversation history (#48).
- Add sleep and heart-rate readiness information, muscle recovery and growth tracking, and advanced strength metrics (#48).
- Edit training-program week structures, including deload weeks and intensity factors (#48).

### Changes
- Refresh navigation, responsive layouts, charts, and workout inputs (#48).
- Bundle Geist fonts locally so app typography does not require runtime font downloads (#48).

### Fixes
- Correct weekly volume date boundaries and weight-unit displays across workout and analytics screens (#48).
- Prevent crashes when a previously selected exercise is no longer available and improve workout-editing and input-timer handling (#48).
