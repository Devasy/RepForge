# Rest Timer Customization Feature

## Overview

Allow users to set custom rest times per exercise that persist across workouts. Different exercises require different recovery times based on muscle group, intensity, and user preference.

## User Stories

1. **As a user**, I want to set a default rest time for each exercise so I don't have to adjust it every workout.
2. **As a user**, I want quick preset buttons (30s, 60s, 90s, 120s) for common rest durations.
3. **As a user**, I want to set a global default rest time that applies to new exercises.
4. **As a user**, I want visual and audio notifications when rest is complete.
5. **As a user**, I want to see recommended rest times based on exercise type.

## Rest Time Guidelines

| Exercise Type | Recommended Rest | Reasoning |
|--------------|------------------|-----------|
| Heavy Compounds (1-5 reps) | 3-5 minutes | Full ATP recovery |
| Moderate Compounds (6-10 reps) | 2-3 minutes | Partial recovery |
| Isolation (8-12 reps) | 60-90 seconds | Metabolic stress |
| High Rep/Endurance (15+ reps) | 30-60 seconds | Maintain fatigue |
| Supersets | 60-120 seconds | Between rounds |

## Data Model Changes

### User Settings Model

```dart
class UserSettings {
  final int globalDefaultRestSeconds;      // Default: 90
  final bool restTimerAutoStart;           // Default: true
  final bool restTimerVibration;           // Default: true
  final bool restTimerSound;               // Default: true
  final String restTimerSoundAsset;        // Default: 'beep.mp3'
  
  UserSettings({
    this.globalDefaultRestSeconds = 90,
    this.restTimerAutoStart = true,
    this.restTimerVibration = true,
    this.restTimerSound = true,
    this.restTimerSoundAsset = 'beep.mp3',
  });
}
```

### Exercise Rest Preferences

```dart
class ExerciseRestPreference {
  final String exerciseId;
  final int restSeconds;
  final DateTime updatedAt;
  
  ExerciseRestPreference({
    required this.exerciseId,
    required this.restSeconds,
    required this.updatedAt,
  });
}
```

### Extended Exercise Model

```dart
class Exercise {
  // ... existing fields ...
  
  // New field (computed from preferences or defaults)
  int get defaultRestSeconds => _preferences?.restSeconds ?? 90;
  
  // Suggested rest based on category
  int get suggestedRestSeconds {
    switch (category) {
      case 'compound':
        return 120; // 2 minutes
      case 'isolation':
        return 60;  // 1 minute
      default:
        return 90;
    }
  }
}
```

## UI/UX Design

### 1. Rest Timer During Workout

```
┌─────────────────────────────────────┐
│           REST TIME                 │
├─────────────────────────────────────┤
│                                     │
│              1:23                   │
│         ━━━━━━━━━━━━━━━━           │
│              / 2:00                 │
│                                     │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌─────┐  │
│  │30s│ │60s│ │90s│ │2m │ │ +15 │  │
│  └───┘ └───┘ └───┘ └───┘ └─────┘  │
│                                     │
│  ☐ Remember for Bench Press         │
│                                     │
│  ┌─────────────────────────────┐    │
│  │        SKIP REST            │    │
│  └─────────────────────────────┘    │
│                                     │
│  Next: Set 3 of 4                   │
└─────────────────────────────────────┘
```

### 2. Exercise Settings (Long Press or Details)

```
┌─────────────────────────────────────┐
│  Bench Press Settings               │
├─────────────────────────────────────┤
│                                     │
│  Default Rest Time                  │
│  ┌─────────────────────────────┐    │
│  │ ◀  │       2:00        │  ▶ │    │
│  └─────────────────────────────┘    │
│                                     │
│  Quick Presets:                     │
│  [30s] [60s] [90s] [2m] [3m] [5m]   │
│                                     │
│  💡 Suggested: 2-3 min (compound)   │
│                                     │
│  [Reset to Default]    [Save]       │
└─────────────────────────────────────┘
```

### 3. Global Settings Page

```
┌─────────────────────────────────────┐
│  ⚙️ Rest Timer Settings             │
├─────────────────────────────────────┤
│                                     │
│  Default Rest Time                  │
│  ────────────────────────────────   │
│  New exercises start with: [90s] ▼  │
│                                     │
│  Timer Behavior                     │
│  ────────────────────────────────   │
│  Auto-start after set      [●]      │
│  Vibrate when complete     [●]      │
│  Sound when complete       [●]      │
│  Sound: [Beep ▼]                    │
│                                     │
│  Per-Exercise Settings              │
│  ────────────────────────────────   │
│  Bench Press            2:00    [>] │
│  Squats                 3:00    [>] │
│  Bicep Curls            0:45    [>] │
│  (12 more...)                   [>] │
│                                     │
│  [Reset All to Default]             │
└─────────────────────────────────────┘
```

### 4. Timer Completion Notification

```
┌─────────────────────────────────────┐
│  🔔 Rest Complete!                  │
├─────────────────────────────────────┤
│                                     │
│        ✓ TIME'S UP!                 │
│                                     │
│     Bench Press - Set 3             │
│                                     │
│  ┌─────────────────────────────┐    │
│  │      START NEXT SET         │    │
│  └─────────────────────────────┘    │
│                                     │
│  [+30 more seconds]                 │
└─────────────────────────────────────┘
```

## Implementation Details

### Timer Service

```dart
class RestTimerService extends ChangeNotifier {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  bool _isRunning = false;
  
  // Getters
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  double get progress => _totalSeconds > 0 
      ? (_totalSeconds - _remainingSeconds) / _totalSeconds 
      : 0;
  
  void start(int seconds) {
    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    notifyListeners();
  }
  
  void _tick(Timer timer) {
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
      notifyListeners();
    } else {
      _complete();
    }
  }
  
  void _complete() {
    _timer?.cancel();
    _isRunning = false;
    _triggerNotifications();
    notifyListeners();
  }
  
  void _triggerNotifications() {
    // Haptic feedback
    HapticFeedback.heavyImpact();
    // Play sound
    _audioService.playRestComplete();
  }
  
  void addTime(int seconds) {
    _remainingSeconds += seconds;
    _totalSeconds += seconds;
    notifyListeners();
  }
  
  void skip() {
    _timer?.cancel();
    _remainingSeconds = 0;
    _isRunning = false;
    notifyListeners();
  }
  
  void pause() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }
  
  void resume() {
    if (_remainingSeconds > 0) {
      _isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      notifyListeners();
    }
  }
}
```

### Storage Methods

```dart
abstract class StorageService {
  // ... existing methods ...
  
  // Rest preferences
  Future<void> saveExerciseRestPreference(ExerciseRestPreference pref);
  Future<ExerciseRestPreference?> getExerciseRestPreference(String exerciseId);
  Future<List<ExerciseRestPreference>> getAllExerciseRestPreferences();
  Future<void> deleteExerciseRestPreference(String exerciseId);
  
  // User settings
  Future<void> saveUserSettings(UserSettings settings);
  Future<UserSettings> getUserSettings();
}
```

## Workflow

### Setting Rest Time During Workout

```
User completes set
       │
       ▼
┌──────────────────┐
│ Rest timer starts│
│ with saved pref  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ User can adjust  │──► Tap preset button
│ or add time      │    or +15s
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     ┌──────────────────┐
│ "Remember" check │────►│ Save preference  │
│ box ticked?      │ Yes │ for exercise     │
└────────┬─────────┘     └──────────────────┘
         │ No
         ▼
Timer completes → Next set
```

## Implementation Phases

### Phase 1: Core Timer Enhancement (2 days)
- [ ] Create `RestTimerService`
- [ ] Add pause/resume functionality
- [ ] Implement "+15 seconds" and preset buttons
- [ ] Add skip functionality

### Phase 2: Per-Exercise Preferences (2-3 days)
- [ ] Create `ExerciseRestPreference` model
- [ ] Add storage methods
- [ ] "Remember for this exercise" checkbox
- [ ] Load saved preference when starting rest

### Phase 3: Settings UI (2 days)
- [ ] Global settings page for rest timer
- [ ] Per-exercise rest time list
- [ ] Sound/vibration toggles
- [ ] Default rest time selector

### Phase 4: Notifications & Polish (1-2 days)
- [ ] Haptic feedback on completion
- [ ] Sound notification
- [ ] Background notification (if app backgrounded)
- [ ] Visual countdown animation

## Testing Considerations

### Unit Tests
- Timer countdown accuracy
- Preference save/load
- Settings persistence

### Widget Tests
- Preset button functionality
- Timer display updates
- Settings page interactions

### Integration Tests
- Full workout with custom rest times
- Preference persistence across sessions

## Edge Cases

1. **App backgrounded** - Timer continues, show notification
2. **Rest time = 0** - Skip timer entirely
3. **Very long rest (10+ min)** - Show "still resting?" prompt
4. **Exercise deleted** - Clean up rest preferences
5. **Reset to default** - Clear individual preference, use global

## Future Enhancements

- **Smart Rest Suggestions** - ML-based rest time based on performance
- **Heart Rate Integration** - Rest until heart rate recovers
- **Rest Time Analytics** - Track average rest times over time
- **Workout Mode Presets** - Strength mode (long rest) vs Hypertrophy (short rest)
