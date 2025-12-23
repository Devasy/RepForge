# Fix #2: Data Access Layer (Repository Pattern)

## Problem
Without a data access layer:
- Database queries scattered across components
- No abstraction between UI and database
- Hard to test and maintain
- Difficult to switch database implementations
- Complex queries repeated in multiple places

## Solution: Implement Repository Pattern

### Why Repository Pattern?
- **Separation of Concerns**: UI doesn't know about SQL
- **Reusability**: Common queries written once
- **Testability**: Easy to mock for testing
- **Maintainability**: Changes to queries happen in one place
- **Type Safety**: Can add TypeScript later easily

### Implementation Steps

#### 1. Create Workout Repository

Create `workout-logger/repositories/WorkoutRepository.js`:

```javascript
import DatabaseService from '../services/database';

class WorkoutRepository {
  /**
   * Create a new workout
   * @returns {Promise<number>} - The ID of the created workout
   */
  async createWorkout({ name, date, startTime }) {
    const result = await DatabaseService.db.runAsync(
      `INSERT INTO workouts (name, date, start_time) VALUES (?, ?, ?)`,
      [name, date, startTime]
    );
    return result.lastInsertRowId;
  }

  /**
   * Get a workout by ID with all exercises and sets
   */
  async getWorkoutById(workoutId) {
    const workout = await DatabaseService.db.getFirstAsync(
      `SELECT * FROM workouts WHERE id = ?`,
      [workoutId]
    );

    if (!workout) return null;

    // Get exercises for this workout
    const exercises = await DatabaseService.db.getAllAsync(`
      SELECT 
        we.id as workout_exercise_id,
        we.order_index,
        we.notes as exercise_notes,
        e.id as exercise_id,
        e.name,
        e.muscle_group,
        e.equipment_type
      FROM workout_exercises we
      JOIN exercises e ON we.exercise_id = e.id
      WHERE we.workout_id = ?
      ORDER BY we.order_index
    `, [workoutId]);

    // Get sets for each exercise
    for (const exercise of exercises) {
      exercise.sets = await DatabaseService.db.getAllAsync(`
        SELECT * FROM sets 
        WHERE workout_exercise_id = ?
        ORDER BY set_number
      `, [exercise.workout_exercise_id]);
    }

    return { ...workout, exercises };
  }

  /**
   * Get all workouts with summary data
   */
  async getAllWorkouts({ limit = 50, offset = 0 } = {}) {
    return await DatabaseService.db.getAllAsync(`
      SELECT 
        w.*,
        COUNT(DISTINCT we.id) as exercise_count,
        SUM(s.weight_lbs * s.reps) as total_volume
      FROM workouts w
      LEFT JOIN workout_exercises we ON w.id = we.workout_id
      LEFT JOIN sets s ON we.id = s.workout_exercise_id AND s.is_completed = 1
      GROUP BY w.id
      ORDER BY w.date DESC, w.created_at DESC
      LIMIT ? OFFSET ?
    `, [limit, offset]);
  }

  /**
   * Get workouts by date range
   */
  async getWorkoutsByDateRange(startDate, endDate) {
    return await DatabaseService.db.getAllAsync(`
      SELECT * FROM workouts 
      WHERE date BETWEEN ? AND ?
      ORDER BY date DESC
    `, [startDate, endDate]);
  }

  /**
   * Update workout end time and duration
   */
  async finishWorkout(workoutId, endTime, durationSeconds) {
    await DatabaseService.db.runAsync(
      `UPDATE workouts SET end_time = ?, duration_seconds = ? WHERE id = ?`,
      [endTime, durationSeconds, workoutId]
    );
  }

  /**
   * Update workout name
   */
  async updateWorkoutName(workoutId, name) {
    await DatabaseService.db.runAsync(
      `UPDATE workouts SET name = ? WHERE id = ?`,
      [name, workoutId]
    );
  }

  /**
   * Delete a workout (cascade deletes exercises and sets)
   */
  async deleteWorkout(workoutId) {
    await DatabaseService.db.runAsync(
      `DELETE FROM workouts WHERE id = ?`,
      [workoutId]
    );
  }

  /**
   * Get workout statistics
   */
  async getWorkoutStats() {
    const stats = await DatabaseService.db.getFirstAsync(`
      SELECT 
        COUNT(*) as total_workouts,
        SUM(duration_seconds) as total_duration,
        AVG(duration_seconds) as avg_duration
      FROM workouts
      WHERE end_time IS NOT NULL
    `);

    return stats;
  }

  /**
   * Calculate current workout streak
   */
  async getCurrentStreak() {
    const workouts = await DatabaseService.db.getAllAsync(`
      SELECT DISTINCT date 
      FROM workouts 
      ORDER BY date DESC
      LIMIT 365
    `);

    if (workouts.length === 0) return 0;

    let streak = 0;
    let currentDate = new Date();
    currentDate.setHours(0, 0, 0, 0);

    for (const workout of workouts) {
      const workoutDate = new Date(workout.date);
      workoutDate.setHours(0, 0, 0, 0);
      
      const diffDays = Math.floor((currentDate - workoutDate) / (1000 * 60 * 60 * 24));
      
      if (diffDays === streak || diffDays === streak + 1) {
        streak = diffDays + 1;
      } else {
        break;
      }
    }

    return streak;
  }
}

export default new WorkoutRepository();
```

#### 2. Create Exercise Repository

Create `workout-logger/repositories/ExerciseRepository.js`:

```javascript
import DatabaseService from '../services/database';

class ExerciseRepository {
  /**
   * Get all exercises from library
   */
  async getAllExercises({ muscleGroup = null, searchQuery = null } = {}) {
    let query = 'SELECT * FROM exercises WHERE 1=1';
    const params = [];

    if (muscleGroup) {
      query += ' AND muscle_group = ?';
      params.push(muscleGroup);
    }

    if (searchQuery) {
      query += ' AND name LIKE ?';
      params.push(`%${searchQuery}%`);
    }

    query += ' ORDER BY name';

    return await DatabaseService.db.getAllAsync(query, params);
  }

  /**
   * Get exercise by ID
   */
  async getExerciseById(exerciseId) {
    return await DatabaseService.db.getFirstAsync(
      'SELECT * FROM exercises WHERE id = ?',
      [exerciseId]
    );
  }

  /**
   * Create custom exercise
   */
  async createExercise({ name, muscleGroup, equipmentType, description, imageUrl }) {
    const result = await DatabaseService.db.runAsync(
      `INSERT INTO exercises (name, muscle_group, equipment_type, description, image_url, is_custom) 
       VALUES (?, ?, ?, ?, ?, 1)`,
      [name, muscleGroup, equipmentType, description, imageUrl]
    );
    return result.lastInsertRowId;
  }

  /**
   * Add exercise to workout
   */
  async addExerciseToWorkout(workoutId, exerciseId, orderIndex) {
    const result = await DatabaseService.db.runAsync(
      `INSERT INTO workout_exercises (workout_id, exercise_id, order_index) VALUES (?, ?, ?)`,
      [workoutId, exerciseId, orderIndex]
    );
    return result.lastInsertRowId;
  }

  /**
   * Remove exercise from workout
   */
  async removeExerciseFromWorkout(workoutExerciseId) {
    await DatabaseService.db.runAsync(
      `DELETE FROM workout_exercises WHERE id = ?`,
      [workoutExerciseId]
    );
  }

  /**
   * Reorder exercises in workout
   */
  async reorderExercises(workoutId, exerciseOrders) {
    // exerciseOrders is array of { workoutExerciseId, orderIndex }
    for (const { workoutExerciseId, orderIndex } of exerciseOrders) {
      await DatabaseService.db.runAsync(
        `UPDATE workout_exercises SET order_index = ? WHERE id = ? AND workout_id = ?`,
        [orderIndex, workoutExerciseId, workoutId]
      );
    }
  }

  /**
   * Get exercise history (previous performances)
   */
  async getExerciseHistory(exerciseId, limit = 10) {
    return await DatabaseService.db.getAllAsync(`
      SELECT 
        w.date,
        w.name as workout_name,
        we.id as workout_exercise_id,
        s.weight_lbs,
        s.reps,
        s.set_number
      FROM workout_exercises we
      JOIN workouts w ON we.workout_id = w.id
      JOIN sets s ON we.id = s.workout_exercise_id
      WHERE we.exercise_id = ? AND s.is_completed = 1
      ORDER BY w.date DESC, s.set_number
      LIMIT ?
    `, [exerciseId, limit]);
  }

  /**
   * Get all muscle groups
   */
  async getMuscleGroups() {
    return await DatabaseService.db.getAllAsync(`
      SELECT DISTINCT muscle_group FROM exercises ORDER BY muscle_group
    `);
  }
}

export default new ExerciseRepository();
```

#### 3. Create Set Repository

Create `workout-logger/repositories/SetRepository.js`:

```javascript
import DatabaseService from '../services/database';

class SetRepository {
  /**
   * Add a set to an exercise
   */
  async addSet(workoutExerciseId, setNumber, weightLbs = null, reps = null) {
    const result = await DatabaseService.db.runAsync(
      `INSERT INTO sets (workout_exercise_id, set_number, weight_lbs, reps) VALUES (?, ?, ?, ?)`,
      [workoutExerciseId, setNumber, weightLbs, reps]
    );
    return result.lastInsertRowId;
  }

  /**
   * Update set data
   */
  async updateSet(setId, { weightLbs, reps, isCompleted, rpe, notes }) {
    const updates = [];
    const params = [];

    if (weightLbs !== undefined) {
      updates.push('weight_lbs = ?');
      params.push(weightLbs);
    }
    if (reps !== undefined) {
      updates.push('reps = ?');
      params.push(reps);
    }
    if (isCompleted !== undefined) {
      updates.push('is_completed = ?');
      params.push(isCompleted ? 1 : 0);
    }
    if (rpe !== undefined) {
      updates.push('rpe = ?');
      params.push(rpe);
    }
    if (notes !== undefined) {
      updates.push('notes = ?');
      params.push(notes);
    }

    if (updates.length === 0) return;

    params.push(setId);
    await DatabaseService.db.runAsync(
      `UPDATE sets SET ${updates.join(', ')} WHERE id = ?`,
      params
    );
  }

  /**
   * Delete a set
   */
  async deleteSet(setId) {
    await DatabaseService.db.runAsync('DELETE FROM sets WHERE id = ?', [setId]);
  }

  /**
   * Get all sets for a workout exercise
   */
  async getSetsByWorkoutExercise(workoutExerciseId) {
    return await DatabaseService.db.getAllAsync(
      'SELECT * FROM sets WHERE workout_exercise_id = ? ORDER BY set_number',
      [workoutExerciseId]
    );
  }

  /**
   * Calculate volume for an exercise
   */
  async calculateExerciseVolume(workoutExerciseId) {
    const result = await DatabaseService.db.getFirstAsync(`
      SELECT SUM(weight_lbs * reps) as total_volume
      FROM sets
      WHERE workout_exercise_id = ? AND is_completed = 1
    `, [workoutExerciseId]);

    return result?.total_volume || 0;
  }

  /**
   * Calculate total volume for a workout
   */
  async calculateWorkoutVolume(workoutId) {
    const result = await DatabaseService.db.getFirstAsync(`
      SELECT SUM(s.weight_lbs * s.reps) as total_volume
      FROM sets s
      JOIN workout_exercises we ON s.workout_exercise_id = we.id
      WHERE we.workout_id = ? AND s.is_completed = 1
    `, [workoutId]);

    return result?.total_volume || 0;
  }
}

export default new SetRepository();
```

#### 4. Create Analytics Repository

Create `workout-logger/repositories/AnalyticsRepository.js`:

```javascript
import DatabaseService from '../services/database';

class AnalyticsRepository {
  /**
   * Get volume by muscle group over time
   */
  async getVolumeByMuscleGroup(startDate, endDate) {
    return await DatabaseService.db.getAllAsync(`
      SELECT 
        e.muscle_group,
        SUM(s.weight_lbs * s.reps) as total_volume,
        COUNT(DISTINCT w.id) as workout_count
      FROM sets s
      JOIN workout_exercises we ON s.workout_exercise_id = we.id
      JOIN workouts w ON we.workout_id = w.id
      JOIN exercises e ON we.exercise_id = e.id
      WHERE w.date BETWEEN ? AND ? AND s.is_completed = 1
      GROUP BY e.muscle_group
      ORDER BY total_volume DESC
    `, [startDate, endDate]);
  }

  /**
   * Get strength progression for an exercise
   */
  async getStrengthProgression(exerciseId, limit = 20) {
    return await DatabaseService.db.getAllAsync(`
      SELECT 
        w.date,
        MAX(s.weight_lbs) as max_weight,
        AVG(s.weight_lbs) as avg_weight,
        MAX(s.reps) as max_reps,
        SUM(s.weight_lbs * s.reps) as volume
      FROM sets s
      JOIN workout_exercises we ON s.workout_exercise_id = we.id
      JOIN workouts w ON we.workout_id = w.id
      WHERE we.exercise_id = ? AND s.is_completed = 1
      GROUP BY w.date
      ORDER BY w.date DESC
      LIMIT ?
    `, [exerciseId, limit]);
  }

  /**
   * Get workout frequency by week
   */
  async getWorkoutFrequency(weeks = 12) {
    return await DatabaseService.db.getAllAsync(`
      SELECT 
        strftime('%Y-%W', date) as week,
        COUNT(*) as workout_count
      FROM workouts
      WHERE date >= date('now', '-${weeks} weeks')
      GROUP BY week
      ORDER BY week DESC
    `);
  }

  /**
   * Get personal records for all exercises
   */
  async getPersonalRecords() {
    return await DatabaseService.db.getAllAsync(`
      SELECT 
        e.name,
        e.muscle_group,
        MAX(s.weight_lbs) as max_weight,
        s.reps as reps_at_max,
        w.date
      FROM sets s
      JOIN workout_exercises we ON s.workout_exercise_id = we.id
      JOIN exercises e ON we.exercise_id = e.id
      JOIN workouts w ON we.workout_id = w.id
      WHERE s.is_completed = 1
      GROUP BY e.id
      HAVING s.weight_lbs = MAX(s.weight_lbs)
    `);
  }

  /**
   * Calculate volume progression (for progressive overload tracking)
   */
  async getVolumeProgression(muscleGroup, weeks = 8) {
    return await DatabaseService.db.getAllAsync(`
      SELECT 
        strftime('%Y-%W', w.date) as week,
        SUM(s.weight_lbs * s.reps) as total_volume
      FROM sets s
      JOIN workout_exercises we ON s.workout_exercise_id = we.id
      JOIN workouts w ON we.workout_id = w.id
      JOIN exercises e ON we.exercise_id = e.id
      WHERE e.muscle_group = ? 
        AND s.is_completed = 1
        AND w.date >= date('now', '-${weeks} weeks')
      GROUP BY week
      ORDER BY week ASC
    `, [muscleGroup]);
  }
}

export default new AnalyticsRepository();
```

### Files to Create
- `workout-logger/repositories/WorkoutRepository.js`
- `workout-logger/repositories/ExerciseRepository.js`
- `workout-logger/repositories/SetRepository.js`
- `workout-logger/repositories/AnalyticsRepository.js`

### Testing Checklist
- [ ] Can create and retrieve workouts
- [ ] Can add exercises to workouts
- [ ] Can add and update sets
- [ ] Volume calculations work correctly
- [ ] Statistics queries return valid data
- [ ] All foreign key relationships maintained

### Next Steps
- Fix #3: Create React Context for state management
- Fix #4: Update screens to use repositories
