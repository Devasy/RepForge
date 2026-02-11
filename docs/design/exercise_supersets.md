# Exercise Supersets Feature

## Overview

Allow users to group 2-3 exercises together to perform back-to-back without rest between them. This is a common training technique to increase workout intensity and efficiency.

## User Stories

1. **As a user**, I want to create a superset of multiple exercises so I can perform them back-to-back without rest.
2. **As a user**, I want to see superset exercises grouped together visually during my workout.
3. **As a user**, I want the rest timer to only start after completing all exercises in the superset.
4. **As a user**, I want to save supersets as part of my routines for future use.
5. **As a user**, I want to track my sets for each exercise within the superset independently.

## Types of Supersets

| Type | Description | Example |
|------|-------------|---------|
| **Antagonist Superset** | Opposing muscle groups | Bicep Curls + Tricep Extensions |
| **Agonist Superset** | Same muscle group | Bench Press + Chest Flyes |
| **Compound Set** | Same muscle, different angles | Incline Press + Flat Press |
| **Tri-Set** | 3 exercises back-to-back | Shoulder Press + Lateral Raise + Front Raise |
| **Giant Set** | 4+ exercises (advanced) | Full circuit |

## Data Model Changes

### New Model: `Superset`

```dart
class Superset {
  final String id;
  final String name;                    // Optional custom name
  final List<String> exerciseIds;       // 2-4 exercise IDs
  final int restAfterComplete;          // Rest time in seconds after full superset
  final DateTime createdAt;
  
  Superset({
    required this.id,
    this.name,
    required this.exerciseIds,
    this.restAfterComplete = 90,
    required this.createdAt,
  });
}
```

### Modified Model: `Routine`

```dart
class Routine {
  final String id;
  final String name;
  final List<RoutineItem> items;        // NEW: Can be exercise or superset
  final DateTime createdAt;
}

// New union type for routine items
abstract class RoutineItem {
  String get id;
}

class SingleExerciseItem implements RoutineItem {
  final String exerciseId;
  String get id => exerciseId;
}

class SupersetItem implements RoutineItem {
  final Superset superset;
  String get id => superset.id;
}
```

### Modified Model: `ExerciseLog`

```dart
class ExerciseLog {
  final String exerciseId;
  final List<WorkoutSet> sets;
  final String? supersetId;             // NEW: Links to parent superset if applicable
  final int? orderInSuperset;           // NEW: 0, 1, 2... position in superset
  final String? notes;
}
```

## UI/UX Design

### 1. Creating a Superset (Routine Builder)

```
┌─────────────────────────────────────┐
│  Create Routine                     │
├─────────────────────────────────────┤
│  Routine Name: [Push Day         ]  │
│                                     │
│  Exercises:                         │
│  ┌─────────────────────────────┐    │
│  │ 1. Bench Press         [≡]  │    │
│  │ 2. Incline DB Press    [≡]  │    │
│  │    ─── Superset ───────     │    │
│  │ 3. │ Lateral Raises    [≡]  │    │
│  │    │ Face Pulls        [≡]  │    │
│  │    ─────────────────────    │    │
│  │ 4. Tricep Pushdowns    [≡]  │    │
│  └─────────────────────────────┘    │
│                                     │
│  [+ Add Exercise] [+ Add Superset]  │
└─────────────────────────────────────┘
```

### 2. Superset Creation Dialog

```
┌─────────────────────────────────────┐
│  Create Superset                    │
├─────────────────────────────────────┤
│  Name (optional): [Shoulder combo]  │
│                                     │
│  Exercises in superset:             │
│  ┌─────────────────────────────┐    │
│  │ 1. Lateral Raises      [×]  │    │
│  │ 2. Face Pulls          [×]  │    │
│  │    [+ Add Exercise]         │    │
│  └─────────────────────────────┘    │
│                                     │
│  Rest after superset: [90] seconds  │
│                                     │
│  [Cancel]              [Create]     │
└─────────────────────────────────────┘
```

### 3. Workout Flow with Superset

```
┌─────────────────────────────────────┐
│  ← Superset 1 of 2                  │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │  🔗 SUPERSET                │    │
│  │  ├─ Lateral Raises  ✓ ✓ ○  │    │
│  │  └─ Face Pulls      ✓ ○ ○  │    │
│  └─────────────────────────────┘    │
│                                     │
│  Currently: Face Pulls              │
│  Set 2 of 3                         │
│                                     │
│  [Weight: 15kg]  [Reps: 12]         │
│                                     │
│  ┌─────────────────────────────┐    │
│  │         SET DONE            │    │
│  └─────────────────────────────┘    │
│                                     │
│  Next: Lateral Raises (Set 3)       │
└─────────────────────────────────────┘
```

### 4. Visual Indicators

- **Linked Chain Icon** 🔗 to indicate superset
- **Bracket/Border** grouping superset exercises
- **Progress dots** showing completion status per exercise
- **Color coding** - same color for exercises in a superset

## Workflow Logic

### During Workout

```
START SUPERSET
│
├── Exercise 1, Set 1 → Complete → No rest
│   └── Exercise 2, Set 1 → Complete → No rest
│       └── (if tri-set) Exercise 3, Set 1 → Complete
│
├── REST TIMER (configured rest time)
│
├── Exercise 1, Set 2 → Complete → No rest
│   └── Exercise 2, Set 2 → Complete → No rest
│       └── (if tri-set) Exercise 3, Set 2 → Complete
│
├── REST TIMER
│
└── ... repeat until all sets done

END SUPERSET → Move to next routine item
```

### State Management

```dart
class WorkoutProvider {
  // ... existing code ...
  
  // New superset state
  Superset? _currentSuperset;
  int _currentSupersetExerciseIndex = 0;
  
  bool get isInSuperset => _currentSuperset != null;
  
  Exercise? get currentSupersetExercise {
    if (_currentSuperset == null) return null;
    final id = _currentSuperset!.exerciseIds[_currentSupersetExerciseIndex];
    return getExercise(id);
  }
  
  /// Move to next exercise in superset (no rest)
  bool nextSupersetExercise() {
    if (_currentSuperset == null) return false;
    if (_currentSupersetExerciseIndex < _currentSuperset!.exerciseIds.length - 1) {
      _currentSupersetExerciseIndex++;
      notifyListeners();
      return true;
    }
    return false; // End of superset round
  }
  
  /// Complete one round of superset, start rest timer
  void completeSupersetRound() {
    _currentSupersetExerciseIndex = 0;
    // Trigger rest timer with superset's configured rest time
  }
}
```

## Storage Changes

### New Storage Methods

```dart
abstract class StorageService {
  // ... existing methods ...
  
  Future<void> saveSuperset(Superset superset);
  Future<Superset?> getSuperset(String id);
  Future<void> deleteSuperset(String id);
  Future<List<Superset>> getAllSupersets();
}
```

## Implementation Phases

### Phase 1: Core Data Model (2-3 days)
- [ ] Create `Superset` model
- [ ] Update `Routine` to support `RoutineItem` union type
- [ ] Add storage methods for supersets
- [ ] Migration for existing routines

### Phase 2: Routine Builder UI (3-4 days)
- [ ] Add "Create Superset" button in routine builder
- [ ] Superset creation dialog
- [ ] Visual grouping of superset exercises
- [ ] Drag-and-drop reordering within supersets
- [ ] Delete/edit superset functionality

### Phase 3: Workout Flow Integration (4-5 days)
- [ ] Detect when entering a superset
- [ ] Cycle through superset exercises without rest
- [ ] Show superset progress UI
- [ ] Rest timer only after full round
- [ ] Track sets per exercise within superset

### Phase 4: Analytics & Polish (2 days)
- [ ] Superset volume tracking in analytics
- [ ] History view showing superset groupings
- [ ] Performance optimizations
- [ ] Unit and widget tests

## Testing Considerations

### Unit Tests
- Superset creation with valid/invalid exercise counts
- Routine serialization with supersets
- Workout flow state transitions in superset mode

### Widget Tests
- Superset creation dialog
- Visual grouping in routine builder
- Workout flow UI during superset

### Integration Tests
- Full workflow: Create routine with superset → Start workout → Complete superset → Verify history

## Edge Cases

1. **Single exercise superset** - Prevent creation, minimum 2 exercises
2. **Duplicate exercises** - Same exercise in multiple supersets (allow with warning)
3. **Deleting exercise** - Remove from any supersets containing it
4. **Incomplete superset** - User skips exercise mid-superset
5. **Rest timer skip** - User can skip rest between superset rounds

## Future Enhancements

- **Superset Templates** - Pre-built common superset combinations
- **AI Suggestions** - Recommend superset pairings based on muscle groups
- **Superset History** - Compare superset performance over time
- **Drop Sets in Supersets** - Combine both techniques
