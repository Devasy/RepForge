# Muscle Recovery Tracker Feature

## Overview

Provide a visual indicator showing which muscle groups are fatigued based on recent workouts, helping users make informed decisions about their training to optimize recovery and prevent overtraining.

## User Stories

1. **As a user**, I want to see which muscles are currently fatigued before starting a workout.
2. **As a user**, I want recovery recommendations based on my training history.
3. **As a user**, I want to know when a muscle group is fully recovered and ready to train.
4. **As a user**, I want to see my training frequency per muscle group.
5. **As a user**, I want warnings if I'm overtraining a muscle group.

## Recovery Science Background

### Recovery Timeframes by Training Intensity

| Intensity | Volume | Recovery Time |
|-----------|--------|---------------|
| Light (RPE 5-6) | Low sets | 24-48 hours |
| Moderate (RPE 7-8) | Medium sets | 48-72 hours |
| Heavy (RPE 9-10) | High sets | 72-96 hours |
| Very Heavy (PRs) | Max effort | 96-120 hours |

### Factors Affecting Recovery

- Training volume (sets × reps × weight)
- Exercise type (compound vs isolation)
- Muscle group size (legs > arms)
- Individual recovery capacity
- Sleep and nutrition (future integration)

## Data Model

### Muscle Recovery State

```dart
class MuscleRecoveryState {
  final String muscleGroupId;
  final double fatigueLevel;            // 0.0 (fresh) to 1.0 (exhausted)
  final DateTime lastTrainedAt;
  final double volumeInLastSession;
  final int setsInLast7Days;
  final DateTime estimatedFullRecovery;
  
  MuscleRecoveryState({
    required this.muscleGroupId,
    required this.fatigueLevel,
    required this.lastTrainedAt,
    required this.volumeInLastSession,
    required this.setsInLast7Days,
    required this.estimatedFullRecovery,
  });
  
  RecoveryStatus get status {
    if (fatigueLevel < 0.3) return RecoveryStatus.fresh;
    if (fatigueLevel < 0.5) return RecoveryStatus.recovered;
    if (fatigueLevel < 0.7) return RecoveryStatus.moderate;
    if (fatigueLevel < 0.9) return RecoveryStatus.fatigued;
    return RecoveryStatus.exhausted;
  }
  
  bool get isReadyToTrain => fatigueLevel < 0.5;
  
  Duration get timeUntilRecovered {
    final now = DateTime.now();
    if (estimatedFullRecovery.isBefore(now)) return Duration.zero;
    return estimatedFullRecovery.difference(now);
  }
}

enum RecoveryStatus {
  fresh,       // Green - Ready to push hard
  recovered,   // Light green - Good to train
  moderate,    // Yellow - Can train, consider volume
  fatigued,    // Orange - Rest recommended
  exhausted,   // Red - Needs recovery
}
```

### Recovery Calculation Service

```dart
class RecoveryCalculationService {
  static const Map<String, double> muscleRecoveryRates = {
    'chest': 0.015,      // ~67 hours to full recovery
    'back': 0.014,       // ~71 hours
    'shoulders': 0.016,  // ~62 hours
    'biceps': 0.018,     // ~55 hours
    'triceps': 0.018,    // ~55 hours
    'quadriceps': 0.012, // ~83 hours
    'hamstrings': 0.013, // ~77 hours
    'glutes': 0.012,     // ~83 hours
    'calves': 0.020,     // ~50 hours
    'abs': 0.022,        // ~45 hours
    'forearms': 0.020,   // ~50 hours
  };
  
  /// Calculate current fatigue level for a muscle group
  MuscleRecoveryState calculateRecoveryState(
    String muscleGroupId,
    List<WorkoutSession> recentSessions,
  ) {
    final now = DateTime.now();
    final recoveryRate = muscleRecoveryRates[muscleGroupId] ?? 0.015;
    
    double fatigue = 0.0;
    DateTime? lastTrained;
    double lastVolume = 0;
    int setsLast7Days = 0;
    
    // Process sessions from oldest to newest
    final relevantSessions = recentSessions
        .where((s) => s.endTime.isAfter(now.subtract(Duration(days: 7))))
        .toList()
      ..sort((a, b) => a.endTime.compareTo(b.endTime));
    
    for (var session in relevantSessions) {
      final muscleVolume = _calculateMuscleVolume(session, muscleGroupId);
      if (muscleVolume > 0) {
        lastTrained = session.endTime;
        lastVolume = muscleVolume;
        setsLast7Days += _countSetsForMuscle(session, muscleGroupId);
        
        // Add fatigue from this session
        final fatigueAdded = _volumeToFatigue(muscleVolume);
        fatigue = (fatigue + fatigueAdded).clamp(0.0, 1.0);
      }
      
      // Apply recovery since this session
      final hoursSinceSession = now.difference(session.endTime).inHours;
      fatigue = (fatigue - (recoveryRate * hoursSinceSession)).clamp(0.0, 1.0);
    }
    
    // Calculate estimated full recovery time
    final hoursToRecover = fatigue / recoveryRate;
    final fullRecovery = now.add(Duration(hours: hoursToRecover.ceil()));
    
    return MuscleRecoveryState(
      muscleGroupId: muscleGroupId,
      fatigueLevel: fatigue,
      lastTrainedAt: lastTrained ?? now.subtract(Duration(days: 30)),
      volumeInLastSession: lastVolume,
      setsInLast7Days: setsLast7Days,
      estimatedFullRecovery: fullRecovery,
    );
  }
  
  double _volumeToFatigue(double volume) {
    // Convert volume to fatigue (normalized)
    // Light session: ~1000kg = 0.2 fatigue
    // Heavy session: ~5000kg = 0.6 fatigue
    return (volume / 8000).clamp(0.1, 0.8);
  }
}
```

## UI/UX Design

### 1. Body Map View (Primary)

```
┌─────────────────────────────────────┐
│  💪 Muscle Recovery                 │
├─────────────────────────────────────┤
│                                     │
│         ┌─────────┐                 │
│         │   😊    │                 │
│         └────┬────┘                 │
│        ╱           ╲                │
│     🟡              🟡   ← Shoulders│
│    (mod)           (mod)            │
│       │     🟢     │                │
│       │   (chest)  │                │
│       │   fresh    │                │
│    🟠 │            │ 🟠             │
│   arms│            │arms            │
│       │     🟢     │                │
│       │    abs     │                │
│       │            │                │
│      🔴│          │🟡               │
│    quads          hams              │
│       │            │                │
│       🟢          🟢                │
│      calves      calves             │
│                                     │
│  Legend:                            │
│  🟢 Fresh  🟡 Moderate  🔴 Fatigued │
│                                     │
└─────────────────────────────────────┘
```

### 2. List View (Alternative)

```
┌─────────────────────────────────────┐
│  💪 Muscle Recovery                 │
├─────────────────────────────────────┤
│                                     │
│  Ready to Train                     │
│  ────────────────────────────────   │
│  🟢 Chest        Fresh    48h ago   │
│     ━━━━━░░░░░░░░░░░░░  15%        │
│                                     │
│  🟢 Back         Fresh    72h ago   │
│     ━━━━░░░░░░░░░░░░░░  12%        │
│                                     │
│  🟢 Abs          Fresh    24h ago   │
│     ━━━━━━░░░░░░░░░░░░  22%        │
│                                     │
│  Needs More Rest                    │
│  ────────────────────────────────   │
│  🟡 Shoulders    Moderate 18h ago   │
│     ━━━━━━━━━━░░░░░░░░  55%        │
│     Ready in ~8 hours               │
│                                     │
│  🔴 Quadriceps   Fatigued 12h ago   │
│     ━━━━━━━━━━━━━━━░░░  85%        │
│     Ready in ~24 hours              │
│                                     │
│  🟠 Biceps       Tired    8h ago    │
│     ━━━━━━━━━━━━░░░░░░  65%        │
│     Ready in ~12 hours              │
│                                     │
└─────────────────────────────────────┘
```

### 3. Workout Recommendation Card

```
┌─────────────────────────────────────┐
│  🎯 Today's Recommendation          │
├─────────────────────────────────────┤
│                                     │
│  Based on your recovery:            │
│                                     │
│  ✅ Great to train:                 │
│     Chest, Back, Abs                │
│                                     │
│  ⚠️ Light training only:            │
│     Shoulders (55% fatigued)        │
│                                     │
│  ❌ Rest recommended:               │
│     Legs (85% fatigued)             │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Start Push Workout          │    │
│  │ (Chest, Shoulders, Triceps) │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Ignore & Start Any Workout]       │
│                                     │
└─────────────────────────────────────┘
```

### 4. Overtraining Warning

```
┌─────────────────────────────────────┐
│  ⚠️ Overtraining Alert              │
├─────────────────────────────────────┤
│                                     │
│  You've trained CHEST 5 times       │
│  in the last 7 days.                │
│                                     │
│  This is above the recommended      │
│  frequency of 2-3 sessions.         │
│                                     │
│  Consider:                          │
│  • Taking a rest day                │
│  • Training other muscle groups     │
│  • Reducing volume next session     │
│                                     │
│  [Got it]  [Show Recovery Tips]     │
│                                     │
└─────────────────────────────────────┘
```

### 5. Recovery Timeline

```
┌─────────────────────────────────────┐
│  📅 Weekly Recovery Timeline        │
├─────────────────────────────────────┤
│                                     │
│  Chest                              │
│  Mon   Tue   Wed   Thu   Fri   Sat  │
│  🔴────🟠────🟡────🟢────🟢────🔴   │
│  ↑                             ↑    │
│  Trained                    Trained │
│                                     │
│  Legs                               │
│  Mon   Tue   Wed   Thu   Fri   Sat  │
│  🟢────🟢────🔴────🟠────🟡────🟢   │
│            ↑                        │
│         Trained                     │
│                                     │
└─────────────────────────────────────┘
```

## Integration Points

### Home Screen Widget

```
┌─────────────────────────────────────┐
│  Quick Recovery Check               │
│  ────────────────────────────────   │
│  🟢 6 muscle groups ready           │
│  🟡 2 need light training           │
│  🔴 1 needs rest                    │
│                                     │
│  [View Full Recovery Map]           │
└─────────────────────────────────────┘
```

### Routine Selection Filter

```
Show only routines that train:
☑ Fully recovered muscles
☐ Any recovery level
☐ Include fatigued muscles
```

## Implementation Phases

### Phase 1: Core Calculation (2-3 days)
- [ ] Create recovery state model
- [ ] Implement recovery calculation service
- [ ] Calculate muscle volume from sessions
- [ ] Recovery rate per muscle group

### Phase 2: List View UI (2-3 days)
- [ ] Recovery list screen
- [ ] Progress bars and status indicators
- [ ] Time until recovered display
- [ ] 7-day training frequency

### Phase 3: Body Map View (3-4 days)
- [ ] Body silhouette SVG/widget
- [ ] Tap-to-select muscle groups
- [ ] Color gradient based on fatigue
- [ ] Animation for state changes

### Phase 4: Recommendations (2-3 days)
- [ ] Workout recommendation algorithm
- [ ] Overtraining warnings
- [ ] Integration with home screen
- [ ] Push notifications for recovery

### Phase 5: Polish (1-2 days)
- [ ] Settings for recovery preferences
- [ ] Export recovery data
- [ ] Unit and widget tests

## Testing Considerations

### Unit Tests
- Recovery calculation accuracy
- Fatigue accumulation over sessions
- Recovery rate application

### Widget Tests
- Status indicator display
- List view rendering
- Body map interactions

## Edge Cases

1. **No workout history** - Show all muscles as fresh
2. **Very high volume** - Cap fatigue at 100%
3. **Compound exercises** - Distribute fatigue across muscles
4. **Custom exercises** - Use primary muscle group
5. **Time zone changes** - Use UTC for calculations

## Future Enhancements

- **Sleep Integration** - Factor in sleep quality (from wearables)
- **Nutrition Tracking** - Protein intake affects recovery
- **Subjective Feedback** - "How sore are you?" prompts
- **AI Predictions** - Learn individual recovery patterns
- **Deload Week Suggestions** - Recommend recovery weeks
- **HRV Integration** - Heart rate variability data
