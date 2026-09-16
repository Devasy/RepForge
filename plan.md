# Plan: Provider Architecture & Code Quality Remediation

Branch: `fix/provider-architecture-and-code-quality`

## Objective
Systematically resolve all 31 Provider architectural lint warnings (`custom_lint`) and 10 code quality violations (`dart_code_linter`) to enforce clean, reactive state management and robust type safety across the application.

---

## 1. Provider State Management Architecture (`custom_lint` — 31 issues)

### 1.1 Correct Reactive Listening in `build()` (`avoid_read_inside_build`)
In Flutter with Provider, widgets that read state during `build()` must use `context.watch<T>()` so they rebuild when state changes. Using `context.read<T>()` causes stale UI when values update.

Files to update:
- **`workout-logger/lib/screens/analytics_screen.dart`** (line 170):
  - Change `final provider = context.read<WorkoutProvider>();` to `context.watch<WorkoutProvider>()` (used for `provider.getExerciseName(newest.exerciseId)`).
- **`workout-logger/lib/screens/history_screen.dart`** (lines 82, 621):
  - Replace `context.read<...>()` with `context.watch<...>()` in widget build methods.
- **`workout-logger/lib/screens/edit_workout_session_screen.dart`** (line 229):
  - Replace `context.read<...>()` with `context.watch<...>()`.
- **`workout-logger/lib/screens/programs/program_detail_screen.dart`** (line 33):
  - Replace `context.read<...>()` with `context.watch<...>()`.
- **`workout-logger/lib/screens/programs/programs_screen.dart`** (lines 21, 24):
  - Replace `context.read<...>()` with `context.watch<...>()`.
- **`workout-logger/lib/screens/routine_optimizer_screen.dart`** (lines 36, 42, 43, 45):
  - Replace reactive reads in build with `context.watch<...>()`.
- **`workout-logger/lib/screens/widgets/exercise_progress_view.dart`** (lines 36, 557, 733, 1166):
  - Replace `context.read<...>()` with `context.watch<...>()`.
- **`workout-logger/lib/screens/widgets/profile_sections.dart`** (lines 1001, 1066, 1136):
  - Replace `context.read<...>()` with `context.watch<...>()`.
- **`workout-logger/lib/screens/widgets/routine_creator.dart`** (line 448):
  - Replace `context.read<...>()` with `context.watch<...>()`.
- **`workout-logger/lib/screens/workout_summary_screen.dart`** (lines 28, 29):
  - Replace `context.read<...>()` with `context.watch<...>()`.

### 1.2 Prevent Imperative State Listening outside `build()` (`avoid_watch_outside_build`)
Calling `context.watch<T>()` inside button callbacks, dialog dismissals, or lifecycle methods outside `build()` registers transient listeners on deactivated contexts, causing memory leaks and uncontrolled rebuilds.

Files to update:
- **`workout-logger/lib/screens/home_screen.dart`** (line 281):
  - Replace `context.watch<...>()` in helper/callback with `context.read<...>()`.
- **`workout-logger/lib/screens/workout_flow_screen.dart`** (lines 270, 281):
  - Replace `context.watch<...>()` in callback methods with `context.read<...>()`.

### 1.3 Provider Instantiation Factories
In `ChangeNotifierProvider` and `Provider` widget constructors where `create: (ctx) => ViewModel(...)` performs one-time initialization:
- **`workout-logger/lib/main.dart`** (lines 209-211):
  - Annotate intentional factory instantiation reads with `// ignore: avoid_read_inside_build` or structure via `ProxyProvider`.
- **`workout-logger/lib/screens/ai_coach_screen.dart`** (lines 38-41):
  - Annotate `create: (ctx) => AiCoachViewModel(...)` with `// ignore: avoid_read_inside_build` as it is called once per screen lifecycle.

---

## 2. Code Quality & Lint Violations (`dart_code_linter` — 10 issues)

### 2.1 Remove Redundant `async` Modifiers (`avoid-redundant-async`)
Functions marked `async` that return synchronous values or delegates without `await` incur microtask overhead.
- **`workout-logger/lib/services/managers/analytics_manager.dart`** (line 118)
- **`workout-logger/lib/services/workout_provider.dart`** (line 178)
- **`workout-logger/lib/viewmodels/ai_coach_view_model.dart`** (line 140)
- **`workout-logger/lib/viewmodels/routine_optimizer_view_model.dart`** (line 164)

### 2.2 Empty Catch & Logic Blocks (`no-empty-block`)
Provide proper logging or rationale comments in empty catch blocks:
- **`workout-logger/lib/services/workout_provider.dart`** (lines 224, 945)

### 2.3 Strict Type Safety (`avoid-dynamic`)
Replace untyped `dynamic` variables with typed collections and models:
- **`workout-logger/lib/services/ai/gemini_ai_service.dart`** (line 514): Strong type definitions for JSON tool call maps.
- **`workout-logger/lib/services/sqlite_storage_service.dart`** (line 917): Strong typing for parsed backup maps (`Map<String, Object?>`).
- **`workout-logger/lib/services/storage_service.dart`** (lines 325, 336): Strong typing for export/import payload dictionaries.

---

## 3. Verification & Execution Steps

1. **Step 1**: Apply Category 1 fixes across the 14 files.
2. **Step 2**: Run `dart run custom_lint` via `run.ps1` to confirm `0 issues found`.
3. **Step 3**: Apply Category 2 fixes for redundant async, empty blocks, and dynamic types.
4. **Step 4**: Run `dart run dart_code_linter:metrics analyze lib` via `run.ps1` to verify clean rule conformance.
5. **Step 5**: Run full unit & widget test suite (`flutter test`) via `run.ps1` to ensure zero regressions.
6. **Step 6**: Update Graphify AST knowledge graph (`.\venv\Scripts\python.exe -m graphify update .`).
7. **Step 7**: Commit and push changes to `fix/provider-architecture-and-code-quality`.
