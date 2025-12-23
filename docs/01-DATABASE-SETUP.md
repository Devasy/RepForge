# Fix #1: Database Setup

## Problem
The app has no persistent storage layer. All data is hardcoded in components as static arrays, meaning:
- No data persists between app sessions
- No ability to create, update, or delete workouts
- No ability to track historical data
- No ability to calculate metrics (volume, progressive overload)

## Solution: Implement SQLite Database

### Why SQLite?
- **Offline-first**: Works without internet connection
- **Fast**: Excellent performance for local queries
- **Relational**: Perfect for our workout → exercises → sets hierarchy
- **Expo-compatible**: `expo-sqlite` is well-maintained and stable
- **Free**: No backend costs

### Implementation Steps

#### 1. Install Dependencies
```bash
npx expo install expo-sqlite
```

#### 2. Database Schema

```sql
-- Table: workouts
CREATE TABLE workouts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  date TEXT NOT NULL,
  start_time TEXT,
  end_time TEXT,
  duration_seconds INTEGER,
  notes TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Table: exercises (library of all possible exercises)
CREATE TABLE exercises (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  muscle_group TEXT NOT NULL,
  equipment_type TEXT,
  description TEXT,
  image_url TEXT,
  is_custom INTEGER DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Table: workout_exercises (exercises performed in a specific workout)
CREATE TABLE workout_exercises (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  workout_id INTEGER NOT NULL,
  exercise_id INTEGER NOT NULL,
  order_index INTEGER NOT NULL,
  notes TEXT,
  FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE,
  FOREIGN KEY (exercise_id) REFERENCES exercises(id)
);

-- Table: sets (individual sets within an exercise)
CREATE TABLE sets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  workout_exercise_id INTEGER NOT NULL,
  set_number INTEGER NOT NULL,
  weight_lbs REAL,
  reps INTEGER,
  is_completed INTEGER DEFAULT 0,
  rpe REAL,
  notes TEXT,
  FOREIGN KEY (workout_exercise_id) REFERENCES workout_exercises(id) ON DELETE CASCADE
);

-- Table: muscle_groups (for categorization)
CREATE TABLE muscle_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  category TEXT
);

-- Indexes for performance
CREATE INDEX idx_workout_exercises_workout ON workout_exercises(workout_id);
CREATE INDEX idx_sets_workout_exercise ON sets(workout_exercise_id);
CREATE INDEX idx_workouts_date ON workouts(date);
```

#### 3. Create Database Service

Create `workout-logger/services/database.js`:

```javascript
import * as SQLite from 'expo-sqlite';

class DatabaseService {
  constructor() {
    this.db = null;
  }

  async init() {
    this.db = await SQLite.openDatabaseAsync('workout_logger.db');
    await this.createTables();
    await this.seedDefaultExercises();
  }

  async createTables() {
    await this.db.execAsync(`
      PRAGMA journal_mode = WAL;
      
      CREATE TABLE IF NOT EXISTS workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        start_time TEXT,
        end_time TEXT,
        duration_seconds INTEGER,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        muscle_group TEXT NOT NULL,
        equipment_type TEXT,
        description TEXT,
        image_url TEXT,
        is_custom INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS workout_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        order_index INTEGER NOT NULL,
        notes TEXT,
        FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises(id)
      );

      CREATE TABLE IF NOT EXISTS sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_exercise_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        weight_lbs REAL,
        reps INTEGER,
        is_completed INTEGER DEFAULT 0,
        rpe REAL,
        notes TEXT,
        FOREIGN KEY (workout_exercise_id) REFERENCES workout_exercises(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS muscle_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        category TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_workout_exercises_workout ON workout_exercises(workout_id);
      CREATE INDEX IF NOT EXISTS idx_sets_workout_exercise ON sets(workout_exercise_id);
      CREATE INDEX IF NOT EXISTS idx_workouts_date ON workouts(date);
    `);
  }

  async seedDefaultExercises() {
    const count = await this.db.getFirstAsync('SELECT COUNT(*) as count FROM exercises');
    if (count.count > 0) return; // Already seeded

    const defaultExercises = [
      { name: 'Barbell Bench Press', muscle_group: 'Chest', equipment_type: 'Barbell' },
      { name: 'Back Squat', muscle_group: 'Legs', equipment_type: 'Barbell' },
      { name: 'Deadlift', muscle_group: 'Back', equipment_type: 'Barbell' },
      { name: 'Overhead Press', muscle_group: 'Shoulders', equipment_type: 'Barbell' },
      { name: 'Barbell Row', muscle_group: 'Back', equipment_type: 'Barbell' },
      { name: 'Pull-ups', muscle_group: 'Back', equipment_type: 'Bodyweight' },
      { name: 'Dumbbell Bicep Curl', muscle_group: 'Arms', equipment_type: 'Dumbbell' },
      { name: 'Tricep Dips', muscle_group: 'Arms', equipment_type: 'Bodyweight' },
      { name: 'Leg Press', muscle_group: 'Legs', equipment_type: 'Machine' },
      { name: 'Leg Extension', muscle_group: 'Legs', equipment_type: 'Machine' },
    ];

    for (const exercise of defaultExercises) {
      await this.db.runAsync(
        'INSERT INTO exercises (name, muscle_group, equipment_type) VALUES (?, ?, ?)',
        [exercise.name, exercise.muscle_group, exercise.equipment_type]
      );
    }
  }
}

export default new DatabaseService();
```

#### 4. Initialize Database in App

Update `App.js`:

```javascript
import React, { useEffect, useState } from 'react';
import AppNavigator from './navigation/AppNavigator';
import DatabaseService from './services/database';
import { ActivityIndicator, View } from 'react-native';

export default function App() {
  const [isDbReady, setIsDbReady] = useState(false);

  useEffect(() => {
    async function initializeApp() {
      await DatabaseService.init();
      setIsDbReady(true);
    }
    initializeApp();
  }, []);

  if (!isDbReady) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#101322' }}>
        <ActivityIndicator size="large" color="#1337ec" />
      </View>
    );
  }

  return <AppNavigator />;
}
```

### Files to Create
- `workout-logger/services/database.js` - Database service with all CRUD operations

### Files to Modify
- `workout-logger/App.js` - Initialize database on app start
- `workout-logger/package.json` - Add expo-sqlite dependency

### Testing Checklist
- [ ] Database file is created on first launch
- [ ] Tables are created successfully
- [ ] Default exercises are seeded
- [ ] App loads without crashes
- [ ] Database persists after app restart

### Next Steps
After database setup, we need:
- Fix #2: Create data access layer (repositories/queries)
- Fix #3: Implement workout management context
- Fix #4: Update screens to use real data
