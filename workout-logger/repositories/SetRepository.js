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
