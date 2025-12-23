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
