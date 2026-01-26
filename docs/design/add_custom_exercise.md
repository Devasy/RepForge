# Design Document: Personalized Exercise Library Feature

## 1. Overview
This document outlines the design and implementation plan for adding a "Personalized Exercise" feature to the Workout Logger application. This feature allows users to create and add their own custom exercises to the library, expanding beyond the built-in database.

## 2. Feature Requirements

### 2.1 User Stories
- **As a user**, I want to add a new exercise that is not in the default list, so I can track my specific workout routines.
- **As a user**, I want to specify the name, category (Compound/Isolation), and primary muscle group for my custom exercise.
- **As a user**, I want to see my custom exercises integrated seamlessly with the built-in exercises in the library.
- **As a user**, I want to be able to delete custom exercises I no longer need (Optional for v1, but good to consider).

### 2.2 Functional Requirements
- **Add Exercise Form**: A dedicated screen for inputting exercise details.
- **Validation**: Ensure exercise name is not empty and muscle group/category are selected.
- **Persistence**: Save custom exercises locally using the existing Hive-based storage.
- **Integration**: Display custom exercises in the `ExerciseLibraryScreen` alongside built-in ones.

## 3. Technical Architecture

### 3.1 Data Layer (`lib/data`, `lib/models`)
- **Model**: The existing `Exercise` model is sufficient. It already has an `isCustom` flag.
  ```dart
  class Exercise {
    final String id;
    final String name;
    final List<MuscleActivation> muscleActivations; // Derived from selected muscles
    final String category; // 'compound' or 'isolation'
    final bool isCustom; // Set to true for new exercises
    // ...
  }
  ```
- **Storage**: `StorageService` (`lib/services/storage_service.dart`) already implements methods for custom exercises (`saveCustomExercise`, `getCustomExercises`, `deleteCustomExercise`). No changes required here.

### 3.2 State Management (`lib/services/workout_provider.dart`)
The `WorkoutProvider` manages the app state. We need to expose a method to add a custom exercise.

**Proposed Changes:**
- Add `addCustomExercise(String name, String category, String muscleGroupId)` method.
  - Generate a unique ID (using `Uuid`).
  - Create `Exercise` object with `isCustom: true`.
  - Create `MuscleActivation` list (Simplified for v1: 100% activation for the selected primary muscle).
  - Call `_storage.saveCustomExercise()`.
  - Add to `_allExercises` list.
  - `notifyListeners()` to update UI.

### 3.3 UI Layer (`lib/screens`)

#### A. `ExerciseLibraryScreen` Update
- **Data Source**: Change `ExerciseDatabase.getAll()` to `context.watch<WorkoutProvider>().allExercises`. This ensures the list updates when a new exercise is added.
- **Action**: Add a `FloatingActionButton` (or an action button in AppBar) to navigate to the new `AddCustomExerciseScreen`.

#### B. New Screen: `AddCustomExerciseScreen`
- **Widgets**:
  - `TextFormField` for Exercise Name.
  - `DropdownButtonFormField` or `SegmentedButton` for Category (Compound/Isolation).
  - `DropdownButtonFormField` for Primary Muscle Group (using `MuscleGroups.names`).
  - `ElevatedButton` for "Save Exercise".
- **Validation**: Use `GlobalKey<FormState>` to validate inputs before submission.
- **Feedback**: Show a `SnackBar` (Toast) upon successful creation or error.

## 4. Implementation Steps

1.  **Update `WorkoutProvider`**:
    - Implement `addCustomExercise` method.
    - Ensure `_allExercises` is correctly populated on `init()` by merging built-in and custom exercises (already partially implemented in `loadAllData` calling `_storage.getAllExercises`).

2.  **Create `AddCustomExerciseScreen`**:
    - Create `lib/screens/add_custom_exercise_screen.dart`.
    - Implement the form with validation.
    - Connect to `WorkoutProvider`.

3.  **Update `ExerciseLibraryScreen`**:
    - Replace static data fetch with Provider listener.
    - Add navigation to `AddCustomExerciseScreen`.

## 5. Flutter Best Practices Adherence

- **State Management**: Use `Provider` for business logic and state. UI components should only react to state changes.
- **Immutability**: Ensure `Exercise` objects are immutable. Use `List.from()` when modifying lists to avoid reference issues.
- **Asynchronous Operations**: Handle storage operations asynchronously. Show loading indicators if necessary (though strictly local storage is fast).
- **Form Validation**: Use standard Flutter `Form` and `TextFormField` validation logic.
- **Theming**: Use `AppTheme` constants (colors, spacing, typography) to maintain consistency with the "Samsung Health-style" minimal interface.
- **User Feedback**: Provide immediate feedback (SnackBar) for user actions.

## 6. Testing Strategy

- **Unit Tests**:
  - Test `WorkoutProvider.addCustomExercise`:
    - Verify exercise is added to the list.
    - Verify `saveCustomExercise` is called on storage.
    - Verify `isCustom` flag is set.
- **Widget Tests**:
  - Test `AddCustomExerciseScreen`:
    - Verify validation errors show up for empty name.
    - Verify submitting form calls the provider method.
  - Test `ExerciseLibraryScreen`:
    - Verify custom exercises appear in the list.

## 7. Future Considerations (v2)
- **Advanced Muscle Activation**: Allow users to select multiple muscle groups and specify activation percentages (e.g., Chest 70%, Triceps 30%).
- **Icon Selection**: Allow users to pick an icon for their custom exercise.
- **Edit/Delete**: Implement functionality to edit or remove custom exercises.
