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
      { name: 'Leg Curl', muscle_group: 'Legs', equipment_type: 'Machine' },
      { name: 'Lat Pulldown', muscle_group: 'Back', equipment_type: 'Cable' },
      { name: 'Cable Row', muscle_group: 'Back', equipment_type: 'Cable' },
      { name: 'Dumbbell Shoulder Press', muscle_group: 'Shoulders', equipment_type: 'Dumbbell' },
      { name: 'Lateral Raises', muscle_group: 'Shoulders', equipment_type: 'Dumbbell' },
      { name: 'Front Raises', muscle_group: 'Shoulders', equipment_type: 'Dumbbell' },
      { name: 'Incline Bench Press', muscle_group: 'Chest', equipment_type: 'Barbell' },
      { name: 'Decline Bench Press', muscle_group: 'Chest', equipment_type: 'Barbell' },
      { name: 'Dumbbell Flyes', muscle_group: 'Chest', equipment_type: 'Dumbbell' },
      { name: 'Cable Flyes', muscle_group: 'Chest', equipment_type: 'Cable' },
      { name: 'Hammer Curls', muscle_group: 'Arms', equipment_type: 'Dumbbell' },
      { name: 'Tricep Pushdown', muscle_group: 'Arms', equipment_type: 'Cable' },
      { name: 'Skull Crushers', muscle_group: 'Arms', equipment_type: 'Barbell' },
      { name: 'Plank', muscle_group: 'Core', equipment_type: 'Bodyweight' },
      { name: 'Crunches', muscle_group: 'Core', equipment_type: 'Bodyweight' },
      { name: 'Russian Twists', muscle_group: 'Core', equipment_type: 'Bodyweight' },
      { name: 'Hanging Leg Raises', muscle_group: 'Core', equipment_type: 'Bodyweight' },
      { name: 'Lunges', muscle_group: 'Legs', equipment_type: 'Bodyweight' },
      { name: 'Bulgarian Split Squat', muscle_group: 'Legs', equipment_type: 'Dumbbell' },
      { name: 'Calf Raises', muscle_group: 'Legs', equipment_type: 'Machine' },
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
