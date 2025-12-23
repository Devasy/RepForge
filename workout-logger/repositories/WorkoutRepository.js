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
