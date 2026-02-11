# Social Features

## Overview

Enable users to connect with friends, share achievements, participate in challenges, and build a community around fitness goals. Social features increase engagement and motivation through accountability and friendly competition.

## User Stories

1. **As a user**, I want to add friends and see their workout activity.
2. **As a user**, I want to share my achievements (PRs, milestones) with friends.
3. **As a user**, I want to challenge friends to workout competitions.
4. **As a user**, I want to cheer/react to my friends' workouts.
5. **As a user**, I want to compare my progress with friends.
6. **As a user**, I want to control what I share (privacy settings).

## Data Model

### User Profile (Public)

```dart
class UserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime joinedAt;
  final ProfileStats stats;
  final PrivacySettings privacy;
  final List<String> badgeIds;
  
  UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.joinedAt,
    required this.stats,
    required this.privacy,
    this.badgeIds = const [],
  });
}

class ProfileStats {
  final int totalWorkouts;
  final int currentStreak;
  final int longestStreak;
  final int totalPRs;
  final Duration totalWorkoutTime;
  final double totalVolumeKg;
  
  ProfileStats({
    this.totalWorkouts = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPRs = 0,
    this.totalWorkoutTime = Duration.zero,
    this.totalVolumeKg = 0,
  });
}
```

### Friend Connection

```dart
class FriendConnection {
  final String id;
  final String userId;
  final String friendId;
  final FriendStatus status;
  final DateTime connectedAt;
  final DateTime? requestedAt;
  
  FriendConnection({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.connectedAt,
    this.requestedAt,
  });
}

enum FriendStatus {
  pending,      // Request sent
  accepted,     // Friends
  blocked,      // Blocked
}
```

### Activity Feed Item

```dart
class ActivityFeedItem {
  final String id;
  final String userId;
  final ActivityType type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final List<Reaction> reactions;
  final List<Comment> comments;
  
  ActivityFeedItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.timestamp,
    required this.data,
    this.reactions = const [],
    this.comments = const [],
  });
}

enum ActivityType {
  workoutCompleted,
  newPR,
  streakMilestone,
  challengeWon,
  badgeEarned,
  routineShared,
}
```

### Challenge

```dart
class Challenge {
  final String id;
  final String creatorId;
  final String name;
  final String description;
  final ChallengeType type;
  final ChallengeMetric metric;
  final DateTime startDate;
  final DateTime endDate;
  final List<ChallengeParticipant> participants;
  final ChallengeStatus status;
  final String? winnerId;
  
  Challenge({
    required this.id,
    required this.creatorId,
    required this.name,
    required this.description,
    required this.type,
    required this.metric,
    required this.startDate,
    required this.endDate,
    this.participants = const [],
    this.status = ChallengeStatus.pending,
    this.winnerId,
  });
  
  Duration get duration => endDate.difference(startDate);
  bool get isActive => status == ChallengeStatus.active;
}

enum ChallengeType {
  headToHead,      // 1v1
  group,           // Multiple participants
  personal,        // Beat your own record
}

enum ChallengeMetric {
  totalWorkouts,
  totalVolume,
  totalSets,
  workoutStreak,
  specificExercise,  // e.g., most bench press volume
}

class ChallengeParticipant {
  final String oderId;
  final DateTime joinedAt;
  final double currentValue;
  final int rank;
  
  ChallengeParticipant({
    required this.userId,
    required this.joinedAt,
    this.currentValue = 0,
    this.rank = 0,
  });
}
```

### Privacy Settings

```dart
class PrivacySettings {
  final bool showWorkouts;
  final bool showPRs;
  final bool showStats;
  final bool allowFriendRequests;
  final bool showInSearch;
  final ActivityVisibility defaultVisibility;
  
  const PrivacySettings({
    this.showWorkouts = true,
    this.showPRs = true,
    this.showStats = true,
    this.allowFriendRequests = true,
    this.showInSearch = true,
    this.defaultVisibility = ActivityVisibility.friends,
  });
}

enum ActivityVisibility {
  private,     // Only me
  friends,     // Friends only
  public,      // Everyone
}
```

## UI/UX Design

### 1. Activity Feed

```
┌─────────────────────────────────────┐
│  🏠 Feed                    👤 ⚙️   │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 👤 John completed a workout │    │
│  │    Push Day • 45 min        │    │
│  │    12 exercises, 48 sets    │    │
│  │    2 hours ago              │    │
│  │                             │    │
│  │    💪 12  🔥 3  🎉 5        │    │
│  │    💬 2 comments            │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🏆 Sarah hit a new PR!      │    │
│  │    Bench Press: 80kg × 5    │    │
│  │    Previous: 75kg × 5       │    │
│  │    3 hours ago              │    │
│  │                             │    │
│  │    💪 24  🔥 8  🎉 12       │    │
│  │    💬 5 comments            │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🔥 Mike is on a 30-day      │    │
│  │    streak!                  │    │
│  │    5 hours ago              │    │
│  │                             │    │
│  │    💪 45  🔥 22  🎉 18      │    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

### 2. Friend Profile

```
┌─────────────────────────────────────┐
│  ← John's Profile                   │
├─────────────────────────────────────┤
│                                     │
│         ┌──────────┐                │
│         │   👤     │                │
│         │  Avatar  │                │
│         └──────────┘                │
│          John Smith                 │
│          @johnsmith                 │
│          🏋️ Member since Jan 2024   │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  156      45       12       │    │
│  │Workouts  Day     Current    │    │
│  │         Streak   PRs        │    │
│  └─────────────────────────────┘    │
│                                     │
│  🏅 Badges                          │
│  [🔥100][💪PR][🏆Win][⭐Early]      │
│                                     │
│  Recent Activity                    │
│  ────────────────────────────────   │
│  • Completed Pull Day (2h ago)      │
│  • New PR: Deadlift 180kg (1d ago)  │
│  • Won "March Madness" challenge    │
│                                     │
│  [Challenge]  [Compare]  [Remove]   │
│                                     │
└─────────────────────────────────────┘
```

### 3. Challenges Screen

```
┌─────────────────────────────────────┐
│  🏆 Challenges              [+ New] │
├─────────────────────────────────────┤
│                                     │
│  Active Challenges                  │
│  ────────────────────────────────   │
│  ┌─────────────────────────────┐    │
│  │ 🏆 Weekly Volume Challenge  │    │
│  │    vs. Sarah, Mike          │    │
│  │    Ends in 3 days           │    │
│  │                             │    │
│  │    Leaderboard:             │    │
│  │    🥇 You      15,420 kg    │    │
│  │    🥈 Sarah    14,890 kg    │    │
│  │    🥉 Mike     12,340 kg    │    │
│  │                             │    │
│  │    [View Details]           │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 💪 Bench Press Battle       │    │
│  │    vs. John                 │    │
│  │    Most volume in 2 weeks   │    │
│  │                             │    │
│  │    You: 2,400 kg            │    │
│  │    John: 2,100 kg (+300)    │    │
│  │                             │    │
│  │    [View Details]           │    │
│  └─────────────────────────────┘    │
│                                     │
│  Pending Invites (2)                │
│  ────────────────────────────────   │
│  • "April Abs Challenge" from Mike  │
│    [Accept] [Decline]               │
│                                     │
└─────────────────────────────────────┘
```

### 4. Create Challenge

```
┌─────────────────────────────────────┐
│  Create Challenge                   │
├─────────────────────────────────────┤
│                                     │
│  Challenge Name                     │
│  ┌─────────────────────────────┐    │
│  │ Weekly Workout Showdown     │    │
│  └─────────────────────────────┘    │
│                                     │
│  Challenge Type                     │
│  ○ Total Volume (kg)                │
│  ● Total Workouts                   │
│  ○ Workout Streak                   │
│  ○ Specific Exercise                │
│                                     │
│  Duration                           │
│  ┌─────────────────────────────┐    │
│  │ 1 Week                     ▼│    │
│  └─────────────────────────────┘    │
│                                     │
│  Invite Friends                     │
│  ☑ Sarah (@sarahfit)                │
│  ☑ Mike (@mikegains)                │
│  ☐ John (@johnsmith)                │
│  [+ Find More Friends]              │
│                                     │
│  Stakes (Optional)                  │
│  ┌─────────────────────────────┐    │
│  │ Loser buys winner coffee ☕ │    │
│  └─────────────────────────────┘    │
│                                     │
│        [CREATE CHALLENGE]           │
│                                     │
└─────────────────────────────────────┘
```

### 5. Compare Stats

```
┌─────────────────────────────────────┐
│  Compare with Sarah                 │
├─────────────────────────────────────┤
│                                     │
│       You          Sarah            │
│      ┌───┐        ┌───┐             │
│      │👤 │   VS   │👤 │             │
│      └───┘        └───┘             │
│                                     │
│  This Month                         │
│  ────────────────────────────────   │
│  Workouts    15    │    12          │
│              ████████│██████        │
│                                     │
│  Volume     45,000  │  38,000       │
│              ████████│██████        │
│                                     │
│  Streak       8     │    22         │
│              ████    │████████████  │
│                                     │
│  PRs          3     │     5         │
│              ████    │██████        │
│                                     │
│  Best Lifts                         │
│  ────────────────────────────────   │
│  Bench      100kg   │   80kg        │
│  Squat      140kg   │  120kg        │
│  Deadlift   180kg   │  140kg        │
│                                     │
│  [Challenge Sarah]                  │
│                                     │
└─────────────────────────────────────┘
```

### 6. Reactions & Comments

```
┌─────────────────────────────────────┐
│  John's Workout                     │
├─────────────────────────────────────┤
│                                     │
│  Push Day • 45 min                  │
│  ────────────────────────────────   │
│  Bench Press      100kg × 5 (PR!)   │
│  Incline DB       35kg × 8          │
│  Shoulder Press   40kg × 6          │
│  + 3 more exercises                 │
│                                     │
│  ────────────────────────────────   │
│  💪 12  🔥 3  🎉 5  👏 2            │
│  ────────────────────────────────   │
│                                     │
│  Comments                           │
│  Sarah: Nice PR! 💪                 │
│  Mike: Beast mode! Keep it up       │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Add a comment...            │    │
│  └─────────────────────────────┘    │
│                                     │
│  React:  💪  🔥  🎉  👏  ❤️  😮    │
│                                     │
└─────────────────────────────────────┘
```

## Social Service

```dart
class SocialService extends ChangeNotifier {
  final ApiService _api;
  final AuthService _auth;
  
  List<FriendConnection> _friends = [];
  List<ActivityFeedItem> _feed = [];
  List<Challenge> _challenges = [];
  
  /// Send friend request
  Future<void> sendFriendRequest(String userId) async {
    final connection = FriendConnection(
      id: const Uuid().v4(),
      userId: _auth.currentUserId!,
      friendId: userId,
      status: FriendStatus.pending,
      connectedAt: DateTime.now(),
      requestedAt: DateTime.now(),
    );
    
    await _api.post('/friends/request', connection.toMap());
    notifyListeners();
  }
  
  /// Accept friend request
  Future<void> acceptFriendRequest(String connectionId) async {
    await _api.post('/friends/accept/$connectionId');
    await loadFriends();
  }
  
  /// Load activity feed
  Future<void> loadFeed({int page = 0}) async {
    final response = await _api.get('/feed?page=$page');
    final items = (response['items'] as List)
        .map((e) => ActivityFeedItem.fromMap(e))
        .toList();
    
    if (page == 0) {
      _feed = items;
    } else {
      _feed.addAll(items);
    }
    notifyListeners();
  }
  
  /// React to activity
  Future<void> react(String activityId, ReactionType reaction) async {
    await _api.post('/feed/$activityId/react', {
      'type': reaction.name,
    });
    await _refreshActivity(activityId);
  }
  
  /// Create challenge
  Future<Challenge> createChallenge(Challenge challenge) async {
    final response = await _api.post('/challenges', challenge.toMap());
    final created = Challenge.fromMap(response);
    _challenges.add(created);
    notifyListeners();
    return created;
  }
  
  /// Update challenge progress (called after workout)
  Future<void> updateChallengeProgress(WorkoutSession session) async {
    for (var challenge in _challenges.where((c) => c.isActive)) {
      final progress = _calculateProgress(session, challenge.metric);
      await _api.post('/challenges/${challenge.id}/progress', {
        'value': progress,
      });
    }
  }
  
  /// Post workout to feed
  Future<void> shareWorkout(WorkoutSession session, {
    ActivityVisibility visibility = ActivityVisibility.friends,
  }) async {
    final activity = ActivityFeedItem(
      id: const Uuid().v4(),
      userId: _auth.currentUserId!,
      type: ActivityType.workoutCompleted,
      timestamp: DateTime.now(),
      data: {
        'sessionId': session.id,
        'duration': session.duration.inMinutes,
        'exerciseCount': session.sets.map((s) => s.exerciseId).toSet().length,
        'setCount': session.sets.length,
      },
    );
    
    await _api.post('/feed', {
      ...activity.toMap(),
      'visibility': visibility.name,
    });
  }
}
```

## Implementation Phases

### Phase 1: Backend Setup (4-5 days)
- [ ] User authentication service
- [ ] User profile API
- [ ] Friend connection API
- [ ] Database schema

### Phase 2: Friends System (3-4 days)
- [ ] Friend search/discovery
- [ ] Friend requests UI
- [ ] Friends list screen
- [ ] Friend profile view

### Phase 3: Activity Feed (3-4 days)
- [ ] Feed API integration
- [ ] Feed UI with cards
- [ ] Reactions system
- [ ] Comments system

### Phase 4: Challenges (4-5 days)
- [ ] Challenge creation flow
- [ ] Challenge tracking
- [ ] Leaderboards
- [ ] Challenge notifications

### Phase 5: Comparison & Stats (2-3 days)
- [ ] Compare screen
- [ ] Badges system
- [ ] Privacy settings
- [ ] Share to external apps

## Dependencies

```yaml
dependencies:
  firebase_auth: ^4.16.0       # Authentication
  cloud_firestore: ^4.15.0     # Real-time database
  firebase_messaging: ^14.7.0  # Push notifications
  cached_network_image: ^3.3.1 # Avatar caching
```

## Privacy & Security

1. **Data Visibility** - Respect user privacy settings
2. **Block Users** - Hide all activity from blocked users
3. **Report System** - Flag inappropriate content
4. **Data Deletion** - Remove all social data on request
5. **Anonymous Mode** - Option to hide from all users

## Edge Cases

1. **User deletes account** - Remove from friends, challenges
2. **Private workouts** - Don't show in feed
3. **Challenge ends in tie** - Share victory
4. **Offline mode** - Queue reactions/comments
5. **Large friend lists** - Paginate efficiently

## Future Enhancements

- **Groups/Teams** - Create workout groups
- **Live Workouts** - Train together in real-time
- **Coaches** - Trainer-client relationships
- **Leaderboards** - Global/regional rankings
- **Events** - Join community challenges
- **Messaging** - Direct messages between friends
