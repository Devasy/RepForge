# Sleep HR Chart — Design Spec

**Date:** 2026-06-11  
**Status:** Approved  
**Feature area:** Readiness → Sleep heart-rate visualization

---

## 1. Problem

The Readiness feature currently reads resting HR and sleep duration from Health Connect. HRV is unavailable (Samsung Health writer has no HRV permission on this device). Minute-level heart-rate data during sleep is already accessible via `heartRateSeries`, and sleep stage timeline data is already extracted per `SleepPeriod` (`lightMinutes`, `deepMinutes`, `remMinutes`, `awakeMinutes`). Neither is surfaced to the user.

Users want to understand how their heart behaved overnight — specifically whether deep sleep reached a true low, whether REM stayed elevated, and what a clean P95 "resting proxy" looks like — without needing to open Samsung Health.

---

## 2. Goal

Two new surfaces:
1. **Compact card** on the home screen (below the readiness ring card) showing a sparkline + three key numbers.
2. **Full detail bottom sheet** accessible by tapping the compact card, showing:
   - A 10-minute bar chart (low/high per segment, color-coded by sleep stage, moving-average trend line)
   - A "HR range by stage" horizontal distribution chart (min–max + P25–P75 + avg for each of Awake, REM, Light, Deep)

---

## 3. Data Models

### 3.1 `SleepHrSegment` (new)

Represents one 10-minute window of the sleep period.

```dart
class SleepHrSegment {
  final DateTime windowStart;  // truncated to 10-min boundary
  final int minBpm;
  final int maxBpm;
  final double avgBpm;
  final String stage;          // 'deep' | 'rem' | 'light' | 'awake'
}
```

### 3.2 `SleepStageStats` (new)

Aggregate stats for one stage, used by the distribution chart.

```dart
class SleepStageStats {
  final String stage;
  final int minBpm;
  final int p25Bpm;
  final double avgBpm;
  final int p75Bpm;
  final int maxBpm;
  final int sampleCount;
}
```

### 3.3 `SleepHrSnapshot` (new)

Container stored in `ReadinessManager` and passed to both widgets.

```dart
class SleepHrSnapshot {
  final DateTime sleepStart;
  final DateTime sleepEnd;
  final int p95Bpm;                        // P95 of all overnight HR samples
  final List<SleepHrSegment> segments;     // ordered by windowStart
  final List<SleepStageStats> stageStats;  // one entry per stage present
}
```

No persistence required — recomputed each `refresh()`. If the snapshot is null the compact card hides itself (`SizedBox.shrink()`).

---

## 4. Data Pipeline

### 4.1 New Health Connect service method

```dart
// IHealthConnectService
Future<List<HealthSample>> readHeartRateSamples(DateTime start, DateTime end);
// Already exists — no interface change needed.
```

`ReadinessManager.refresh()` calls `readHeartRateSamples(sleepStart - 30min, sleepEnd + 30min)` **only when** `HealthReadType.heartRate` is granted and at least one sleep period exists for last night.

### 4.2 Stage assignment per sample

Each `HealthSample` is tagged with the sleep stage active at its timestamp by walking the `SleepPeriod.samples` stage timeline (from `SleepSessionRecord.samples`, already loaded). Samples outside any stage window → tagged `'awake'`.

### 4.3 Segment aggregation

Samples are bucketed into 10-minute windows aligned to `sleepStart`. For each window: `minBpm`, `maxBpm`, `avgBpm` are computed. The stage for the window is the **mode** of sample stages in that window (most-frequent). Windows with zero samples are omitted.

### 4.4 P95 and stage stats

- **P95:** Sort all sample bpms → take the value at index `floor(0.95 * n)`.
- **Stage stats:** Group samples by stage → compute min, P25, avg, P75, max via sort-and-index.

### 4.5 Where it lives in `ReadinessManager`

```dart
SleepHrSnapshot? _sleepHrSnapshot;
SleepHrSnapshot? get sleepHrSnapshot => _sleepHrSnapshot;
```

Computed and stored at the end of `refresh()`, alongside the readiness score. Triggers `notifyListeners()` once (same call as the score update).

---

## 5. UI Components

### 5.1 `SleepHrCard` (compact, home screen)

**File:** `lib/screens/widgets/sleep_hr_card.dart`

Layout:
```
┌─────────────────────────────────┐
│ Sleep heart rate      1:24–8:17 │  ← header row
│ P95 67bpm  REM 64bpm  Deep 52bpm│  ← three mini-stats
│ [sparkline bar chart]           │  ← canvas, 38dp tall
└─────────────────────────────────┘
```

- Tapping the card opens `SleepHrSheet` via `showModalBottomSheet`.
- Hidden (`SizedBox.shrink()`) when `snapshot.sleepHrSnapshot == null`.
- Placed in `HomeScreen` body, directly below `ReadinessCard`.

### 5.2 `SleepHrSheet` (full detail bottom sheet)

**File:** `lib/screens/widgets/sleep_hr_sheet.dart`

Sections top → bottom:
1. **Handle + title + subtitle** ("Sleep heart rate · 1:24 AM – 8:17 AM")
2. **Three key stats** (P95 HR, Deep avg, REM avg) in pill chips
3. **Bar chart** — `CustomPainter`, 140dp tall
   - Y-axis: BPM labels (50, 60, 70, 80) with horizontal grid lines
   - X-axis: time labels every 60 min
   - Each bar: low→high range, fill color = stage color at 73% opacity
   - Moving-average line (window=5 segments): `#00D9FF`, dashed
4. **Stage timeline bar** — thin colored strip below chart, same proportions
5. **Legend** (Deep / REM / Light / Awake / Avg line)
6. **"HR range by stage" section**
   - Title label
   - Four horizontal range rows: Awake → REM → Light → Deep (top → bottom)
   - Each row: full-range bar (22% opacity) + IQR bar (72% opacity) + avg dot + avg bpm label
   - Shared BPM x-axis with vertical grid lines (45, 50 … 85)
   - Sub-legend: min–max / P25–P75 / Avg

Scrollable (`SingleChildScrollView`) so it fits all screen sizes.

---

## 6. Painting Strategy

Both the bar chart and the distribution chart use `CustomPainter` (not canvas HTML). Stage colors are sourced from a local constant map in the widget file; no dependency on `AppColors.muscleGroupColors`.

Stage color map:
```dart
const _stageColors = {
  'deep':  Color(0xFF4C8EFF),
  'rem':   Color(0xFFA78BFA),
  'light': Color(0xFF34D399),
  'awake': Color(0xFFF59E0B),
};
```

---

## 7. Error / Empty States

| Condition | Behavior |
|-----------|----------|
| `heartRate` not granted | `sleepHrSnapshot` = null → compact card hidden |
| Sleep period missing | `sleepHrSnapshot` = null → compact card hidden |
| < 5 HR samples in a segment | Segment omitted from chart |
| Stage has < 3 samples | `SleepStageStats` for that stage omitted from distribution |
| Sheet opened with null snapshot | Should not happen (card hidden); guard with early return |

---

## 8. HRV Lookback Cleanup

`_todayHrv()` in `ReadinessManager` currently uses a 30-day diagnostic window. This should be reverted to 48 hours once the Sleep HR feature ships (confirms the device never writes HRV, so the wide window has no ongoing value).

---

## 9. Files Changed / Created

| Action | File |
|--------|------|
| New | `lib/models/sleep_hr_models.dart` — `SleepHrSegment`, `SleepStageStats`, `SleepHrSnapshot` |
| Modified | `lib/services/managers/readiness_manager.dart` — add `_buildSleepHrSnapshot()`, store result |
| New | `lib/screens/widgets/sleep_hr_card.dart` |
| New | `lib/screens/widgets/sleep_hr_sheet.dart` |
| Modified | `lib/screens/home_screen.dart` (or equivalent) — insert `SleepHrCard` below `ReadinessCard` |
| Modified | `lib/services/managers/readiness_manager.dart` — revert HRV window to 48h |

---

## 10. Out of Scope

- Trend over multiple nights (tonight vs last 7 nights) — future feature
- Tap-to-see-segment detail in the bar chart — future feature
- P95 participating in the readiness score formula — deferred; it replaces HRV only if baseline data accumulates
- Exporting or sharing the chart
