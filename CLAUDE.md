# CLAUDE.md — RepForge Workout Logger

This file provides guidance for AI assistants working on the RepForge codebase.

---

## Project Overview

**RepForge** is a Flutter-based cross-platform workout logging mobile application targeting Android. It provides:
- Workout session tracking with sets, reps, weights, supersets, and dropsets
- Analytics and progress visualization (FL Chart)
- AI-powered set recommendations (linear regression)
- Goal/target tracking with ML-estimated completion dates
- Customizable exercise library
- Reusable workout routines
- Structured training programs with JSON import/export
- Rest timer support during active workouts

**Package:** `com.devasy.repforge`
**Version:** `1.0.12+13`
**Flutter SDK:** `3.41.5` (pinned in pubspec.yaml `environment`)
**Dart SDK:** `^3.9.2`

---

## Repository Structure

```
Workout-logger/
├── workout-logger/              # Main Flutter application (work here)
│   ├── lib/
│   │   ├── main.dart            # App entry point, DI composition root
│   │   ├── theme/
│   │   │   └── app_theme.dart   # Dark theme, spacing, colors, muscle group colors
│   │   ├── models/
│   │   │   └── models.dart      # ALL data models (~600 lines)
│   │   ├── services/
│   │   │   ├── interfaces/      # IStorageService, IMLService abstractions
│   │   │   ├── managers/        # SRP-focused feature managers (7 total)
│   │   │   ├── strategies/      # OCP target calculation strategies
│   │   │   ├── storage_service.dart   # Hive persistence
│   │   │   ├── ml_service.dart        # Linear regression ML
│   │   │   ├── workout_provider.dart  # Main ChangeNotifier state
│   │   │   ├── api_service.dart       # HTTP API client
│   │   │   ├── platform_io.dart       # Platform-specific file I/O
│   │   │   └── platform_stub.dart     # Web platform stub
│   │   ├── screens/             # 13 UI screens
│   │   │   ├── programs/        # 4 program-related screens
│   │   │   └── ...              # 9 main screens
│   │   └── data/
│   │       └── exercise_database.dart  # 50+ built-in exercises
│   ├── test/                    # flutter_test + Mockito tests
│   │   └── test_utils/          # MockStorageService, MockMLService
│   ├── pubspec.yaml
│   └── analysis_options.yaml
├── backend/                     # Python/Flask API server
│   ├── main.py
│   ├── models.py
│   ├── database.py
│   └── __init__.py
├── dashboard/                   # Python/Dash analytics dashboard
│   ├── app.py
│   └── requirements.txt
├── docs/
│   ├── RELEASE_WORKFLOW.md
│   └── design/                  # Feature design proposals (9 docs)
├── scripts/
│   └── bump_version.dart        # Patch version bump script
├── .github/
│   ├── workflows/
│   │   ├── test.yml             # CI test pipeline (runs on PRs)
│   │   └── release.yml          # Auto-release CI/CD pipeline
│   └── skills/flutter-expert/
│       └── SKILL.md             # Flutter expert agent definition
├── SOLID_ANALYSIS_REPORT.md     # Architecture refactoring rationale
└── API_CALLS_ANALYSIS.md        # Backend API call analysis
```

---

## Development Commands

All commands run from inside `workout-logger/`:

```bash
# Install dependencies
flutter pub get

# Run the app (requires connected device/emulator)
flutter run

# Run all tests
flutter test

# Run a specific test file
flutter test test/workout_provider_test.dart

# Check lint / static analysis
flutter analyze

# Build release APK
flutter build apk --release

# Generate Mockito mocks (after modifying interfaces)
dart run build_runner build --delete-conflicting-outputs

# Bump patch version (used by CI)
dart ../scripts/bump_version.dart patch
```

---

## Architecture & Key Patterns

### Dependency Injection (Composition Root)
All services are wired in `main.dart` via `AppInitializer`. The constructor injection pattern means:
- `WorkoutProvider` receives `IStorageService` and `IMLService`
- Managers receive only the dependencies they need
- Tests swap real implementations for mocks

### SOLID Principles
This codebase was explicitly refactored around SOLID — see `SOLID_ANALYSIS_REPORT.md`.

| Principle | Implementation |
|-----------|---------------|
| **SRP** | 7 managers (`ActiveWorkoutManager`, `HistoryManager`, `RoutineManager`, `ExerciseManager`, `TargetManager`, `AnalyticsManager`, `ProgramManager`) each own one concern |
| **OCP** | `TargetCalculatorStrategy` + `TargetCalculatorFactory` for extensible target types |
| **LSP** | `MockStorageService`/`MockMLService` are fully substitutable for real impls |
| **ISP** | Screens depend only on their needed manager, not a monolithic interface |
| **DIP** | All dependencies flow through `IStorageService` and `IMLService` interfaces |

### State Management
- **Provider** (`ChangeNotifier`) pattern throughout
- `WorkoutProvider` is the top-level orchestrator
- Individual managers call `notifyListeners()` when their slice of state changes
- Prefer watching the smallest scoped manager/provider needed by a widget.
- Avoid broad `context.watch<WorkoutProvider>()` in leaf widgets; use selector/manager-specific access to reduce coupling and rebuilds.

### Data Persistence
- **Hive** (key-value, NoSQL) — no SQL, no cloud required
- 6 boxes: `workout_sessions`, `routines`, `targets`, `muscle_groups`, `custom_exercises`, `settings`
- All models serialize to/from JSON for Hive storage
- Export/import available for user data portability

### ML Service
- Linear regression (least-squares) on session number vs. volume
- R² coefficient tracks model quality
- Set recommendations use two strategies:
  1. Add reps (up to 12 max)
  2. Increase weight by 2.5–5kg
- Reps clamped to 6–15 range

---

## Data Models (lib/models/models.dart)

Key models and their most-used getters:

| Model | Key Fields | Useful Getters |
|-------|-----------|----------------|
| `Exercise` | `id`, `name`, `muscleActivations`, `category`, `isCustom` | `primaryMuscle` |
| `WorkoutSet` | `weight`, `reps`, `isDropset`, `drops` | `volume` (weight × reps) |
| `ExerciseLog` | `exerciseId`, `sets`, `notes` | `totalVolume` |
| `WorkoutSession` | `id`, `date`, `routineId`, `exercises`, `duration` | `totalVolume` |
| `Target` | `exerciseId`, `targetType`, `targetValue`, `currentValue` | `progressPercentage` |
| `GrowthModel` | `slope`, `intercept`, `r²`, `lastTrained` | `predict(n)` |
| `SetRecommendation` | `weight`, `reps`, `confidence`, `reasoning` | — |
| `MuscleGroup` | `id`, `name`, `growthRate` | — |

All models implement `copyWith()` for immutable updates.

---

## Theme & Design System (lib/theme/app_theme.dart)

**Color tokens:**
- `AppColors.primary` — `#6C5CE7` (purple)
- `AppColors.secondary` — `#00D9FF` (cyan)
- `AppColors.accent` — `#FF6B6B` (red/salmon)
- `AppColors.background` — `#0D1117`
- `AppColors.surface` — `#161B22`
- `AppColors.card` — `#21262D`

**Muscle group colors:** 18 distinct colors accessible via `AppColors.muscleGroupColors[muscleId]`.

**Spacing scale:** `AppSpacing.xs` (4) → `AppSpacing.xxl` (48)
**Border radius:** `AppRadius.sm` (8) → `AppRadius.full` (999)

Always use the design system tokens rather than hardcoded values.

---

## Screens (lib/screens/)

| Screen | File | Key Dependencies |
|--------|------|-----------------|
| `HomeScreen` | `home_screen.dart` | All managers |
| `WorkoutFlowScreen` | `workout_flow_screen.dart` | `ActiveWorkoutManager` |
| `HistoryScreen` | `history_screen.dart` | `HistoryManager` |
| `AnalyticsScreen` | `analytics_screen.dart` | `AnalyticsManager`, `TargetManager` |
| `RoutinesScreen` | `routines_screen.dart` | `RoutineManager`, `ExerciseManager` |
| `ExerciseLibraryScreen` | `exercise_library_screen.dart` | `ExerciseManager` |
| `AddCustomExerciseScreen` | `add_custom_exercise_screen.dart` | `ExerciseManager` |
| `EditWorkoutSessionScreen` | `edit_workout_session_screen.dart` | `HistoryManager` |
| `SettingsScreen` | `settings_screen.dart` | `WorkoutProvider` |
| `ProgramsScreen` | `programs/programs_screen.dart` | `ProgramManager` |
| `ProgramDesignerScreen` | `programs/program_designer_screen.dart` | `ProgramManager`, `ExerciseManager` |
| `ProgramDetailScreen` | `programs/program_detail_screen.dart` | `ProgramManager` |
| `ImportProgramScreen` | `programs/import_program_screen.dart` | `ProgramManager` |

Navigation uses `IndexedStack` — switching tabs preserves scroll position.

### WorkoutFlowScreen Features
The active workout screen (`workout_flow_screen.dart`, ~49KB) supports:
- **Rest timers** with visual countdown
- **Supersets** with automatic exercise cycling
- **Dropsets** with weight/rep reduction tracking
- **Set modification** UI (add, remove, edit sets)
- **Program-aware flow** — follows scheduled program if one is active

---

## Services (lib/services/)

### Managers (lib/services/managers/)

| Manager | File | Responsibility |
|---------|------|---------------|
| `ActiveWorkoutManager` | `active_workout_manager.dart` | In-progress workout state |
| `HistoryManager` | `history_manager.dart` | Past session persistence and retrieval |
| `RoutineManager` | `routine_manager.dart` | Routine CRUD |
| `ExerciseManager` | `exercise_manager.dart` | Exercise library (built-in + custom merged) |
| `TargetManager` | `target_manager.dart` | Goal/target tracking and progress |
| `AnalyticsManager` | `analytics_manager.dart` | Stats, volume, intensity, frequency |
| `ProgramManager` | `program_manager.dart` | Structured program CRUD |

### Additional Services

- **`api_service.dart`** — HTTP client for external API calls (`http` package)
- **`platform_io.dart`** — Platform-specific file I/O (uses `dart:io` on mobile)
- **`platform_stub.dart`** — Web-safe stub for `platform_io.dart`

---

## Testing Conventions

**Location:** `workout-logger/test/`

**Pattern:** Arrange–Act–Assert (AAA) with Mockito mocks.

```dart
// Always use mock services from test_utils/
final mockStorage = MockStorageService();
final mockML = MockMLService();

// Wire via WorkoutProvider constructor
final provider = WorkoutProvider(mockStorage, mockML);
```

**Test files:**
| File | Coverage |
|------|----------|
| `workout_provider_test.dart` | WorkoutProvider unit tests |
| `program_manager_test.dart` | ProgramManager unit tests |
| `add_custom_exercise_screen_test.dart` | Widget tests |
| `exercise_library_screen_test.dart` | Widget tests |
| `widget_test.dart` | Basic smoke test |

**Mock setup:**
- `MockStorageService` — in-memory, fulfills `IStorageService`
- `MockMLService` — stub responses, fulfills `IMLService`

After modifying service interfaces, regenerate mocks:
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Run tests before committing** — CI runs `flutter test` on all PRs and pushes.

---

## CI/CD Pipeline

### Test Workflow (`.github/workflows/test.yml`)
Triggers on: `push` to main, all `pull_request` events, published releases.
1. Sets up Flutter `3.41.5` on ubuntu-latest
2. Runs `flutter analyze --no-fatal-infos --no-fatal-warnings`
3. Runs `flutter test`

### Release Workflow (`.github/workflows/release.yml`)
Triggers on: `push` to main, or manual `workflow_dispatch`.
1. Runs `dart scripts/bump_version.dart patch` (increments patch + build number)
2. Commits version bump and creates a git tag (`v{version}`)
3. Builds release APK with Flutter `3.41.5`
4. Generates release notes from merged PRs since last release
5. Creates a GitHub Release with the APK attached

**Do not** manually edit `pubspec.yaml` version before merging to `main` — the CI handles it. For a minor/major bump, edit `pubspec.yaml` manually before the merge.

---

## Key Conventions

### Dart / Flutter Style
- Follow `flutter_lints` rules (enforced by `analysis_options.yaml`)
- Use `const` constructors wherever possible
- Prefer `final` for local variables
- Use named parameters for clarity on functions with 3+ args
- All model mutations go through `copyWith()` — never mutate state directly

### Adding a New Feature
1. **Model:** Add or extend in `lib/models/models.dart`
2. **Interface:** If new persistence/ML methods needed, add to `lib/services/interfaces/`
3. **Storage:** Implement in `lib/services/storage_service.dart`
4. **Manager:** Add a new manager in `lib/services/managers/` or extend an existing one; export it from `managers.dart`
5. **Provider:** Wire the manager into `WorkoutProvider` (or inject directly)
6. **Screen:** Create or update a screen in `lib/screens/`
7. **Tests:** Add tests in `test/` using mock services

### Adding a New Exercise
Add to `lib/data/exercise_database.dart` following the existing pattern:
```dart
Exercise(
  id: 'unique_id',
  name: 'Exercise Name',
  category: 'compound', // or 'isolation'
  muscleActivations: [
    MuscleActivation(muscleGroupId: 'chest', activationPercentage: 70),
    MuscleActivation(muscleGroupId: 'triceps', activationPercentage: 30),
  ],
),
```

### Adding a New Target Type
Implement `TargetCalculatorStrategy` and register in `TargetCalculatorFactory`:
```dart
class MyTargetCalculator implements TargetCalculatorStrategy { ... }
TargetCalculatorFactory.registerCalculator('my_type', MyTargetCalculator());
```

### Adding a New Program
Programs can be imported from JSON. See `docs/example_12_week_program.json` for the expected JSON schema. Use `ImportProgramScreen` + `ProgramManager` for the import flow.

---

## Known Constraints & Gotchas

- **Hive boxes must be opened** before use — `StorageService.init()` opens all boxes at startup in `main.dart`. Do not open boxes elsewhere.
- **Exercise IDs are UUIDs** — always use `const Uuid().v4()` for new exercises, never sequential integers.
- **Muscle activation percentages** do not need to sum to 100 — they are relative activation levels, not strict splits.
- **ML model needs ≥ 2 data points** — `GrowthModel` returns null/defaults with fewer than 2 workout sessions for an exercise.
- **Custom exercises** are stored separately from built-in exercises; `ExerciseManager.getAllExercises()` merges both lists.
- **Bottom nav uses IndexedStack** — all tab screens are always mounted; avoid expensive init work in `build()`.
- **Flutter SDK is pinned** to `3.41.5` in `pubspec.yaml` (not a range constraint) — keep CI and local env in sync.
- **CI analysis flags** — `flutter analyze` runs with `--no-fatal-infos --no-fatal-warnings`; only errors fail the build.

---

## Design Documents

Feature proposals live in `docs/design/`. Before implementing a major feature, check if a design doc exists:

- `add_custom_exercise.md` ✅ (implemented)
- `exercise_supersets.md`
- `muscle_recovery_tracker.md`
- `personal_records.md`
- `rest_timer_customization.md`
- `social_features.md`
- `wearables_integration.md`
- `workout_scheduling.md`
- `workout_sharing.md`

See also `docs/example_12_week_program.json` for the structured program JSON format.
