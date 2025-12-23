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
