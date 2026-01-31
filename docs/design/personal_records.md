# Personal Records (PRs) Feature

## Overview

Track and celebrate when users achieve new personal records for weight, reps, or volume. PRs are key motivators in strength training and provide tangible evidence of progress.

## User Stories

1. **As a user**, I want to see when I've hit a new PR immediately after logging a set.
2. **As a user**, I want to view my PR history for each exercise.
3. **As a user**, I want to see different types of PRs (1RM, max reps, max volume).
4. **As a user**, I want to celebrate PRs with visual feedback and animations.
5. **As a user**, I want to see how close I am to breaking my current PR.

## Types of Personal Records

| PR Type | Definition | Example |
|---------|------------|---------|
| **1RM (One Rep Max)** | Heaviest weight lifted for 1 rep | 100kg × 1 |
| **Weight PR** | Heaviest weight at any rep count | 90kg × 5 |
| **Rep PR** | Most reps at a given weight | 80kg × 12 |
| **Volume PR** | Highest total volume in one session | 5,000kg |
| **Estimated 1RM** | Calculated from weight × reps | 95kg × 5 = ~107kg e1RM |
| **Set PR** | Best single set (weight × reps) | 85kg × 8 = 680 |

## Data Model

### Personal Record Model

```dart
class PersonalRecord {
  final String id;
  final String exerciseId;
  final PRType type;
  final double value;                    // Weight, reps, or volume
  final double? weight;                  // For context
  final int? reps;                       // For context
  final DateTime achievedAt;
  final String? workoutSessionId;        // Reference to the workout
  final PersonalRecord? previousRecord;  // What was beaten
  
  PersonalRecord({
    required this.id,
    required this.exerciseId,
    required this.type,
    required this.value,
    this.weight,
    this.reps,
    required this.achievedAt,
    this.workoutSessionId,
    this.previousRecord,
  });
  
  double get improvement {
    if (previousRecord == null) return 0;
    return value - previousRecord!.value;
  }
  
  double get improvementPercent {
    if (previousRecord == null || previousRecord!.value == 0) return 0;
    return (improvement / previousRecord!.value) * 100;
  }
}

enum PRType {
  oneRepMax,       // Heaviest single rep
  weightPR,        // Heaviest weight (any reps)
  repPR,           // Most reps at specific weight
  volumePR,        // Total session volume
  estimated1RM,    // Calculated 1RM
  setPR,           // Best single set (weight × reps)
}
```

### PR Detection Service

```dart
class PRDetectionService {
  /// Check if a set is a new PR
  List<PersonalRecord> detectPRs({
    required String exerciseId,
    required WorkoutSet set,
    required List<ExerciseLog> historicalLogs,
    required List<PersonalRecord> existingPRs,
  }) {
    final newPRs = <PersonalRecord>[];
    
    // Check Weight PR
    if (_isWeightPR(set, existingPRs)) {
      newPRs.add(_createWeightPR(set, existingPRs));
    }
    
    // Check Rep PR at this weight
    if (_isRepPR(set, historicalLogs)) {
      newPRs.add(_createRepPR(set, historicalLogs));
    }
    
    // Check Estimated 1RM
    final e1rm = _calculateE1RM(set.weight, set.reps);
    if (_isEstimated1RMPR(e1rm, existingPRs)) {
      newPRs.add(_createE1RMPR(e1rm, set, existingPRs));
    }
    
    // Check Set PR (weight × reps)
    final setScore = set.weight * set.reps;
    if (_isSetPR(setScore, existingPRs)) {
      newPRs.add(_createSetPR(setScore, set, existingPRs));
    }
    
    return newPRs;
  }
  
  /// Calculate Estimated 1RM using Epley formula
  double _calculateE1RM(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps > 12) return weight * (1 + reps / 30); // Simplified for high reps
    return weight * (1 + reps / 30); // Epley formula
  }
}
```

## UI/UX Design

### 1. PR Celebration (Immediate Feedback)

```
┌─────────────────────────────────────┐
│                                     │
│         🏆 NEW PR! 🏆               │
│                                     │
│     ━━━━━━━━━━━━━━━━━━━━━━━        │
│                                     │
│         BENCH PRESS                 │
│         100kg × 5                   │
│                                     │
│     Previous: 95kg × 5              │
│     Improvement: +5kg (+5.3%)       │
│                                     │
│     ━━━━━━━━━━━━━━━━━━━━━━━        │
│                                     │
│  🔥 Weight PR    📈 New e1RM: 116kg │
│                                     │
│         [AWESOME! 💪]               │
│                                     │
└─────────────────────────────────────┘

Animation: Confetti + Trophy bounce + Haptic
```

### 2. PR Indicator During Set Input

```
┌─────────────────────────────────────┐
│  Bench Press - Set 3                │
├─────────────────────────────────────┤
│                                     │
│  Weight: [100] kg                   │
│  ┌─────────────────────────────┐    │
│  │ 🏆 PR territory! Current:   │    │
│  │    95kg (Dec 15, 2025)      │    │
│  └─────────────────────────────┘    │
│                                     │
│  Reps: [5]                          │
│  ┌─────────────────────────────┐    │
│  │ ⭐ Rep PR at 100kg: 3 reps  │    │
│  │    Beat it with 4+ reps!    │    │
│  └─────────────────────────────┘    │
│                                     │
│  Estimated 1RM: ~116kg              │
│  (Current e1RM PR: 112kg)           │
│                                     │
│  [SET DONE]                         │
└─────────────────────────────────────┘
```

### 3. Exercise PR History

```
┌─────────────────────────────────────┐
│  📊 Bench Press PRs                 │
├─────────────────────────────────────┤
│                                     │
│  Current Records                    │
│  ────────────────────────────────   │
│  🏋️ Weight PR     100kg × 5        │
│                   Jan 28, 2026      │
│                                     │
│  💪 Estimated 1RM  116kg            │
│                   Jan 28, 2026      │
│                                     │
│  🔥 Best Set      85kg × 10         │
│                   Jan 15, 2026      │
│                                     │
│  📈 Session Volume 4,500kg          │
│                   Jan 20, 2026      │
│                                     │
│  PR History                         │
│  ────────────────────────────────   │
│  Jan 28  🏆 100kg×5  +5kg           │
│  Jan 15  🏆 95kg×5   +5kg           │
│  Dec 28  🏆 90kg×6   New e1RM       │
│  Dec 15  🏆 85kg×8   +5kg           │
│  [View All History]                 │
│                                     │
└─────────────────────────────────────┘
```

### 4. PR Dashboard (Analytics)

```
┌─────────────────────────────────────┐
│  🏆 Personal Records                │
├─────────────────────────────────────┤
│                                     │
│  This Month: 7 new PRs 🔥           │
│  ━━━━━━━━━━━━━━━━━━━━━━━           │
│                                     │
│  Recent PRs                         │
│  ┌─────────────────────────────┐    │
│  │ Today      Bench Press      │    │
│  │            100kg × 5   +5kg │    │
│  ├─────────────────────────────┤    │
│  │ Yesterday  Squats           │    │
│  │            140kg × 3   +10kg│    │
│  ├─────────────────────────────┤    │
│  │ Jan 25     Deadlift         │    │
│  │            180kg × 1   +5kg │    │
│  └─────────────────────────────┘    │
│                                     │
│  Exercises by PR Count              │
│  Bench Press      ████████ 12 PRs   │
│  Squats           ██████ 8 PRs      │
│  Deadlift         █████ 6 PRs       │
│                                     │
│  [View All PRs]                     │
└─────────────────────────────────────┘
```

### 5. PR Badge on Exercise Card

```
┌─────────────────────────────────────┐
│  Bench Press              🏆        │ ← Trophy indicates active PR
│  Compound • Chest                   │
│  Last: 95kg × 8                     │
│  PR: 100kg (Jan 28)                 │
└─────────────────────────────────────┘
```

## Celebration Animations

### Visual Effects
1. **Confetti burst** - Particles exploding from center
2. **Trophy animation** - Bouncing 🏆 emoji
3. **Glow effect** - Golden glow around the set
4. **Number animation** - Counting up the improvement

### Haptic Patterns
```dart
void celebratePR(PRType type) {
  switch (type) {
    case PRType.oneRepMax:
      // Heavy impact sequence
      HapticFeedback.heavyImpact();
      Future.delayed(Duration(ms: 100), () => HapticFeedback.heavyImpact());
      Future.delayed(Duration(ms: 200), () => HapticFeedback.heavyImpact());
      break;
    case PRType.weightPR:
      HapticFeedback.heavyImpact();
      HapticFeedback.mediumImpact();
      break;
    default:
      HapticFeedback.mediumImpact();
  }
}
```

### Sound Effects
- Different sounds for different PR types
- Optional setting to disable

## Storage

```dart
abstract class StorageService {
  // ... existing methods ...
  
  // Personal Records
  Future<void> savePersonalRecord(PersonalRecord pr);
  Future<List<PersonalRecord>> getPRsForExercise(String exerciseId);
  Future<PersonalRecord?> getCurrentPR(String exerciseId, PRType type);
  Future<List<PersonalRecord>> getAllPRs();
  Future<List<PersonalRecord>> getPRsInDateRange(DateTime start, DateTime end);
  Future<Map<String, int>> getPRCountByExercise();
}
```

## Implementation Phases

### Phase 1: Core PR Detection (3 days)
- [ ] Create `PersonalRecord` model
- [ ] Implement `PRDetectionService`
- [ ] Add 1RM calculation formulas
- [ ] Storage methods for PRs

### Phase 2: Real-time Detection (2-3 days)
- [ ] Integrate PR detection into `addSet()` flow
- [ ] PR context display during set input
- [ ] "PR territory" indicators

### Phase 3: Celebration UI (2-3 days)
- [ ] PR celebration modal/overlay
- [ ] Confetti animation package integration
- [ ] Haptic feedback patterns
- [ ] Sound effects

### Phase 4: PR Dashboard (2-3 days)
- [ ] Exercise PR history screen
- [ ] PR analytics in dashboard
- [ ] PR badges on exercise cards
- [ ] Monthly PR summary

### Phase 5: Polish (1-2 days)
- [ ] Settings for celebration intensity
- [ ] PR sharing capability
- [ ] Unit and widget tests

## Testing Considerations

### Unit Tests
- E1RM calculation accuracy
- PR detection for various scenarios
- PR comparison and improvement calculation

### Widget Tests
- Celebration modal display
- PR indicator visibility
- History screen rendering

## Edge Cases

1. **First workout ever** - Every set is technically a PR
2. **Same weight, same reps** - Not a PR (must beat)
3. **Bodyweight exercises** - Track reps only
4. **Weight loss** - Relative strength PRs?
5. **Long gap in training** - Consider "comeback" PRs?
6. **Failed reps** - Don't count incomplete sets

## Future Enhancements

- **PR Streaks** - Consecutive workouts with PRs
- **PR Predictions** - "You're on track for 110kg next month"
- **PR Leaderboards** - Compare with friends
- **PR Milestones** - Celebrate 100kg, 2x bodyweight, etc.
- **PR Notifications** - "You haven't hit a PR in 2 weeks, try..."
