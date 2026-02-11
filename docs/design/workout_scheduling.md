# Workout Scheduling Feature

## Overview

A calendar-based system that allows users to plan their workouts in advance, set recurring schedules, and receive reminders. This helps users maintain consistency and plan their training week effectively.

## User Stories

1. **As a user**, I want to schedule a routine for a specific date and time.
2. **As a user**, I want to set up recurring workout schedules (e.g., every Monday, Wednesday, Friday).
3. **As a user**, I want to receive reminders before my scheduled workouts.
4. **As a user**, I want to see my planned workouts in a calendar view.
5. **As a user**, I want to reschedule or cancel planned workouts easily.
6. **As a user**, I want to see my adherence rate to the schedule.

## Data Model

### Scheduled Workout

```dart
class ScheduledWorkout {
  final String id;
  final String routineId;
  final DateTime scheduledAt;
  final Duration estimatedDuration;
  final bool isRecurring;
  final RecurrenceRule? recurrenceRule;
  final ReminderSettings? reminder;
  final ScheduleStatus status;
  final String? completedSessionId;       // Link to actual session
  final String? notes;
  
  ScheduledWorkout({
    required this.id,
    required this.routineId,
    required this.scheduledAt,
    this.estimatedDuration = const Duration(hours: 1),
    this.isRecurring = false,
    this.recurrenceRule,
    this.reminder,
    this.status = ScheduleStatus.scheduled,
    this.completedSessionId,
    this.notes,
  });
  
  bool get isPast => scheduledAt.isBefore(DateTime.now());
  bool get isToday => DateUtils.isSameDay(scheduledAt, DateTime.now());
  bool get isMissed => isPast && status == ScheduleStatus.scheduled;
}

enum ScheduleStatus {
  scheduled,    // Planned, not yet started
  inProgress,   // Currently doing workout
  completed,    // Finished workout
  skipped,      // User skipped
  rescheduled,  // Moved to another time
}
```

### Recurrence Rule

```dart
class RecurrenceRule {
  final RecurrenceFrequency frequency;
  final int interval;                      // Every X days/weeks/months
  final List<int>? daysOfWeek;            // 1=Mon, 7=Sun
  final DateTime? endDate;
  final int? occurrences;                  // End after X occurrences
  
  RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.daysOfWeek,
    this.endDate,
    this.occurrences,
  });
  
  /// Generate next scheduled dates
  List<DateTime> generateDates(DateTime from, int count) {
    final dates = <DateTime>[];
    var current = from;
    
    while (dates.length < count) {
      if (_matchesRule(current)) {
        if (endDate != null && current.isAfter(endDate!)) break;
        dates.add(current);
      }
      current = _nextCandidate(current);
    }
    
    return dates;
  }
}

enum RecurrenceFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  custom,
}
```

### Reminder Settings

```dart
class ReminderSettings {
  final Duration beforeWorkout;
  final bool enabled;
  final String? customMessage;
  
  const ReminderSettings({
    this.beforeWorkout = const Duration(minutes: 30),
    this.enabled = true,
    this.customMessage,
  });
  
  static const List<Duration> presets = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(days: 1),
  ];
}
```

## UI/UX Design

### 1. Calendar View (Weekly)

```
┌─────────────────────────────────────┐
│  📅 Workout Schedule                │
│  ◀  June 2024  ▶         [+ Add]   │
├─────────────────────────────────────┤
│                                     │
│  Mon  Tue  Wed  Thu  Fri  Sat  Sun  │
│  ─────────────────────────────────  │
│   3    4    5    6    7    8    9   │
│  🏋️       🏋️       🏋️            │
│                                     │
│  10   11   12   13   14   15   16   │
│  🏋️       🏋️       🏋️            │
│                                     │
│  Today - Monday, June 10            │
│  ────────────────────────────────   │
│  ┌─────────────────────────────┐    │
│  │ 🏋️ Push Day          7:00 AM │    │
│  │    Bench, Shoulders, Triceps │    │
│  │    Est. 60 min               │    │
│  │    🔔 Reminder in 30 min     │    │
│  │                              │    │
│  │   [Start Now]  [Reschedule]  │    │
│  └─────────────────────────────┘    │
│                                     │
│  Upcoming This Week                 │
│  ────────────────────────────────   │
│  Wed - Pull Day @ 7:00 AM           │
│  Fri - Leg Day @ 7:00 AM            │
│                                     │
└─────────────────────────────────────┘
```

### 2. Monthly Calendar View

```
┌─────────────────────────────────────┐
│  📅 June 2024            [Weekly]   │
├─────────────────────────────────────┤
│  Mon  Tue  Wed  Thu  Fri  Sat  Sun  │
│  ─────────────────────────────────  │
│                          1 ✓  2     │
│   3●   4    5●   6    7●   8    9   │
│  10●  11   12●  13   14●  15   16   │
│  17●  18   19●  20   21●  22   23   │
│  24●  25   26●  27   28●  29   30   │
│                                     │
│  ● = Scheduled  ✓ = Completed       │
│  ○ = Missed                         │
│                                     │
│  This Month: 12 planned, 8 completed│
│  Adherence: 67%                     │
│                                     │
└─────────────────────────────────────┘
```

### 3. Add Schedule Screen

```
┌─────────────────────────────────────┐
│  Schedule Workout                   │
├─────────────────────────────────────┤
│                                     │
│  Routine                            │
│  ┌─────────────────────────────┐    │
│  │ Push Day                   ▼│    │
│  └─────────────────────────────┘    │
│                                     │
│  Date & Time                        │
│  ┌─────────────────────────────┐    │
│  │ Mon, June 10        7:00 AM │    │
│  └─────────────────────────────┘    │
│                                     │
│  Repeat                             │
│  ┌─────────────────────────────┐    │
│  │ Every Week                 ▼│    │
│  └─────────────────────────────┘    │
│                                     │
│  On Days                            │
│  [M]  [ ]  [W]  [ ]  [F]  [ ]  [ ] │
│  Mon  Tue  Wed  Thu  Fri  Sat  Sun  │
│                                     │
│  End                                │
│  ○ Never                            │
│  ○ After [12] occurrences           │
│  ○ On date [___________]            │
│                                     │
│  Reminder                           │
│  ┌─────────────────────────────┐    │
│  │ 🔔 30 minutes before       ▼│    │
│  └─────────────────────────────┘    │
│                                     │
│  Notes (optional)                   │
│  ┌─────────────────────────────┐    │
│  │ Focus on form today...      │    │
│  └─────────────────────────────┘    │
│                                     │
│        [SAVE SCHEDULE]              │
│                                     │
└─────────────────────────────────────┘
```

### 4. Quick Schedule Templates

```
┌─────────────────────────────────────┐
│  Quick Schedule Templates           │
├─────────────────────────────────────┤
│                                     │
│  Popular Schedules                  │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🏋️ Push/Pull/Legs (3 day)   │    │
│  │    Mon - Push               │    │
│  │    Wed - Pull               │    │
│  │    Fri - Legs               │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 💪 Upper/Lower (4 day)      │    │
│  │    Mon - Upper              │    │
│  │    Tue - Lower              │    │
│  │    Thu - Upper              │    │
│  │    Fri - Lower              │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🔥 Full Body (3 day)        │    │
│  │    Mon, Wed, Fri            │    │
│  │    Full Body Routine        │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Create Custom Schedule]           │
│                                     │
└─────────────────────────────────────┘
```

### 5. Today Widget (Home Screen)

```
┌─────────────────────────────────────┐
│  📅 Today's Workout                 │
├─────────────────────────────────────┤
│                                     │
│  Push Day @ 7:00 AM                 │
│  🔔 Reminder set for 6:30 AM        │
│                                     │
│  ━━━━━━━━━░░░░░░░░░░░  In 2 hours  │
│                                     │
│  [Start Early]  [Reschedule]        │
│                                     │
└─────────────────────────────────────┘
```

### 6. Reschedule Dialog

```
┌─────────────────────────────────────┐
│  Reschedule "Push Day"              │
├─────────────────────────────────────┤
│                                     │
│  Originally: Mon, June 10 @ 7:00 AM │
│                                     │
│  New Date & Time                    │
│  ┌─────────────────────────────┐    │
│  │ Tue, June 11        6:00 PM │    │
│  └─────────────────────────────┘    │
│                                     │
│  ☐ Apply to all future occurrences  │
│                                     │
│  [Cancel]        [Reschedule]       │
│                                     │
└─────────────────────────────────────┘
```

## Scheduling Service

```dart
class SchedulingService extends ChangeNotifier {
  final StorageService _storage;
  final NotificationService _notifications;
  List<ScheduledWorkout> _schedules = [];
  
  List<ScheduledWorkout> get todaysWorkouts => _schedules
      .where((s) => s.isToday && s.status == ScheduleStatus.scheduled)
      .toList();
  
  List<ScheduledWorkout> get upcomingWorkouts => _schedules
      .where((s) => !s.isPast && s.status == ScheduleStatus.scheduled)
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  
  /// Schedule a new workout
  Future<void> scheduleWorkout(ScheduledWorkout workout) async {
    _schedules.add(workout);
    
    // Generate recurring instances
    if (workout.isRecurring && workout.recurrenceRule != null) {
      final futureDates = workout.recurrenceRule!.generateDates(
        workout.scheduledAt.add(Duration(days: 1)),
        52, // Generate next year
      );
      
      for (var date in futureDates) {
        _schedules.add(workout.copyWith(
          id: const Uuid().v4(),
          scheduledAt: date,
        ));
      }
    }
    
    // Set up reminders
    if (workout.reminder?.enabled ?? false) {
      await _scheduleReminder(workout);
    }
    
    await _save();
    notifyListeners();
  }
  
  /// Mark workout as completed
  Future<void> markCompleted(String scheduleId, String sessionId) async {
    final index = _schedules.indexWhere((s) => s.id == scheduleId);
    if (index >= 0) {
      _schedules[index] = _schedules[index].copyWith(
        status: ScheduleStatus.completed,
        completedSessionId: sessionId,
      );
      await _save();
      notifyListeners();
    }
  }
  
  /// Reschedule workout
  Future<void> reschedule(String scheduleId, DateTime newTime, {
    bool applyToAll = false,
  }) async {
    final workout = _schedules.firstWhere((s) => s.id == scheduleId);
    
    if (applyToAll && workout.isRecurring) {
      // Update all future occurrences
      final timeDiff = newTime.difference(workout.scheduledAt);
      for (var schedule in _schedules) {
        if (schedule.routineId == workout.routineId && 
            !schedule.isPast &&
            schedule.status == ScheduleStatus.scheduled) {
          schedule = schedule.copyWith(
            scheduledAt: schedule.scheduledAt.add(timeDiff),
          );
        }
      }
    } else {
      // Update single occurrence
      final index = _schedules.indexWhere((s) => s.id == scheduleId);
      _schedules[index] = _schedules[index].copyWith(
        scheduledAt: newTime,
        status: ScheduleStatus.rescheduled,
      );
    }
    
    await _save();
    await _rescheduleReminder(scheduleId);
    notifyListeners();
  }
  
  /// Get adherence statistics
  ScheduleStats getStats({DateTime? from, DateTime? to}) {
    final period = _schedules.where((s) =>
        (from == null || s.scheduledAt.isAfter(from)) &&
        (to == null || s.scheduledAt.isBefore(to)) &&
        s.isPast);
    
    final completed = period.where((s) => 
        s.status == ScheduleStatus.completed).length;
    final missed = period.where((s) => 
        s.status == ScheduleStatus.scheduled).length;
    
    return ScheduleStats(
      totalPlanned: period.length,
      completed: completed,
      missed: missed,
      adherenceRate: period.isEmpty ? 1.0 : completed / period.length,
    );
  }
  
  Future<void> _scheduleReminder(ScheduledWorkout workout) async {
    final reminderTime = workout.scheduledAt.subtract(
        workout.reminder!.beforeWorkout);
    
    await _notifications.schedule(
      id: workout.id.hashCode,
      title: 'Workout Reminder',
      body: 'Time for ${workout.routineId} in ${workout.reminder!.beforeWorkout.inMinutes} minutes!',
      scheduledTime: reminderTime,
    );
  }
}
```

## Implementation Phases

### Phase 1: Core Scheduling (3-4 days)
- [ ] Create schedule data models
- [ ] Implement `SchedulingService`
- [ ] Basic CRUD operations
- [ ] Storage integration

### Phase 2: Calendar UI (3-4 days)
- [ ] Weekly calendar view
- [ ] Monthly calendar view
- [ ] Day detail view
- [ ] Add/edit schedule screen

### Phase 3: Recurrence (2-3 days)
- [ ] Recurrence rule engine
- [ ] Generate future occurrences
- [ ] Edit single vs all occurrences
- [ ] Quick schedule templates

### Phase 4: Notifications (2-3 days)
- [ ] Local notifications setup
- [ ] Reminder scheduling
- [ ] Reminder preferences
- [ ] Notification actions (Start, Snooze)

### Phase 5: Analytics & Polish (2 days)
- [ ] Adherence statistics
- [ ] Streak tracking
- [ ] Home screen widget
- [ ] Widget and unit tests

## Dependencies

```yaml
dependencies:
  table_calendar: ^3.0.9           # Calendar widget
  flutter_local_notifications: ^16.3.0  # Reminders
  timezone: ^0.9.2                 # Time zone handling
```

## Testing Considerations

### Unit Tests
- Recurrence rule date generation
- Adherence calculation
- Schedule conflict detection

### Widget Tests
- Calendar navigation
- Schedule creation flow
- Reschedule dialogs

## Edge Cases

1. **Time zone changes** - Store in UTC, display in local
2. **Past schedules** - Mark as missed automatically
3. **Overlapping schedules** - Warn but allow
4. **Deleted routines** - Handle orphaned schedules
5. **App not opened** - Process missed schedules on launch
6. **DST changes** - Adjust recurring schedules

## Future Enhancements

- **Smart Scheduling** - AI suggests optimal workout times
- **Calendar Integration** - Sync with Google/Apple Calendar
- **Trainer Mode** - Schedule workouts for clients
- **Weather Integration** - Adjust outdoor workouts
- **Energy Prediction** - Based on sleep/HRV data
- **Conflict Detection** - Warn about overlapping events
