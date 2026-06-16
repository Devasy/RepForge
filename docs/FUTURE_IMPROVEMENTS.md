# Future Improvements — Open Source Store Launch

This file tracks the remaining work for Options B and C of the open-source store launch plan.
Option A (production signing + IzzyOnDroid/Obtainium) is complete.

---

## Option B — F-Droid Readiness

### 1. Bundle Geist fonts locally (google_fonts)

Currently `google_fonts` may fetch font files from Google's CDN at first launch. F-Droid requires
all network access to be under user control — a silent font download at startup fails that bar.

**Fix:** Download the Geist Sans and Geist Mono `.ttf` files, add them to `assets/fonts/`, declare
them in `pubspec.yaml` under `flutter.fonts`, and replace `GoogleFonts.geist(...)` calls with
`TextStyle(fontFamily: 'Geist')`. Then remove the `google_fonts` package.

### 2. F-Droid metadata file

Create `fdroid/metadata/com.devasy.repforge.yml` following the F-Droid metadata spec:

```yaml
Categories:
  - Sports & Health
License: Apache-2.0
SourceCode: https://github.com/<your-org>/repforge
IssueTracker: https://github.com/<your-org>/repforge/issues

AutoName: RepForge
Summary: Workout logger with AI-powered coaching
Description: |-
  RepForge is an open-source workout logging app with set/rep/weight tracking,
  progress analytics, AI coaching (optional, requires user-supplied Gemini API key),
  and Health Connect integration.

AntiFeatures:
  NonFreeNet:
    - description: >
        Optional AI Coach and Routine Optimizer features send data to Google's Gemini API.
        These features are disabled unless the user provides their own API key in Settings.

Builds:
  - versionName: 2.x.x
    versionCode: xx
    commit: vX.X.X
    subdir: workout-logger
    gradle:
      - release
```

### 3. Fastlane store metadata

Create `fastlane/metadata/android/en-US/` with:
- `title.txt` — "RepForge"
- `short_description.txt` — one-line summary (≤80 chars)
- `full_description.txt` — full store description
- `changelogs/<versionCode>.txt` — per-release changelog

IzzyOnDroid also reads fastlane metadata for its store listing.

---

## Option C — Strict F-Droid Compliance

### 4. Health Connect graceful degradation

Health Connect is an OS API (not Google Play Services) so F-Droid accepts it. However, for
maximum compatibility on AOSP/custom ROMs without Health Connect:

- Add an `isHealthConnectAvailable()` check at startup
- Show a "Health Connect not available" state in the Readiness screen instead of crashing
- Make daily readiness score optional in the Home screen when Health Connect is absent

### 5. Replace google_fonts package entirely

After completing item B.1, the `google_fonts` package can be removed from `pubspec.yaml` entirely.
This eliminates any risk of runtime Google CDN fetches and removes a transitive dependency.

---

## IzzyOnDroid Submission Checklist

- [ ] Merge this branch to main and confirm a production-signed release appears on GitHub Releases
- [ ] Submit via: https://gitlab.com/IzzyOnDroid/repo/-/issues (open a new issue, "App submission" template)
- [ ] Provide: repo URL, anti-features (NonFreeNet), brief description
- [ ] Wait for review (typically 1–7 days)

## Obtainium

No submission needed. Users add the GitHub repo URL directly in Obtainium and install the latest
release APK automatically. Share the repo URL in your README.
