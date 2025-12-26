import DatabaseService from '../services/database';
import ExerciseRepository from './ExerciseRepository';
import RegressionService from '../services/RegressionService';
import AnalyticsRepository from './AnalyticsRepository';

class PredictionsRepository {
  /**
   * Get progressive overload recommendations for an exercise
   */
  async getExerciseRecommendation(exerciseId) {
    // Get exercise history
    // We request more history rows to ensure we have enough workouts (since history returns sets)
    const history = await ExerciseRepository.getExerciseHistory(exerciseId, 100);

    if (history.length === 0) {
      return {
        exerciseId,
        hasHistory: false,
        recommendation: {
          recommendedWeight: 0,
          recommendedReps: 10,
          confidence: 0,
          message: 'No history available. Start with a comfortable weight.',
        },
      };
    }

    // Group by date and get best set per workout
    const workoutMap = {};
    history.forEach(entry => {
      const currentVolume = (entry.weight_lbs || 0) * (entry.reps || 0);
      const existingBest = workoutMap[entry.date];
      const existingVolume = existingBest ? (existingBest.weight_lbs || 0) * (existingBest.reps || 0) : 0;

      if (!existingBest || currentVolume > existingVolume) {
        workoutMap[entry.date] = entry;
      }
    });

    const bestSets = Object.values(workoutMap);

    // Sort bestSets by date ascending for regression
    bestSets.sort((a, b) => new Date(a.date) - new Date(b.date));

    const recommendation = RegressionService.calculateProgressiveOverload(bestSets);

    // Check if deload is needed
    const shouldDeload = RegressionService.shouldDeload(bestSets);

    return {
      exerciseId,
      hasHistory: true,
      lastWorkout: bestSets[bestSets.length - 1],
      recommendation: {
        ...recommendation,
        shouldDeload,
        deloadMessage: shouldDeload
          ? 'Your performance is declining. Consider a deload week (reduce weight by 40%).'
          : null,
      },
    };
  }

  /**
   * Get recommendations for all exercises in active workout
   */
  async getWorkoutRecommendations(workoutId) {
    const workout = await DatabaseService.db.getAllAsync(`
      SELECT
        we.id as workout_exercise_id,
        e.id as exercise_id,
        e.name
      FROM workout_exercises we
      JOIN exercises e ON we.exercise_id = e.id
      WHERE we.workout_id = ?
    `, [workoutId]);

    const recommendations = [];

    for (const exercise of workout) {
      const rec = await this.getExerciseRecommendation(exercise.exercise_id);
      recommendations.push({
        ...exercise,
        ...rec,
      });
    }

    return recommendations;
  }

  /**
   * Get muscle growth predictions
   */
  async getMuscleGrowthPredictions() {
    const muscleGroups = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'];
    const predictions = [];

    for (const muscleGroup of muscleGroups) {
      const volumeHistory = await AnalyticsRepository.getVolumeProgression(muscleGroup, 12);

      const growthRate = RegressionService.calculateMuscleGrowthRate(
        volumeHistory.map((v, i) => ({ week: i, volume: v.total_volume }))
      );

      predictions.push({
        muscleGroup,
        ...growthRate,
      });
    }

    return predictions.filter(p => p.status !== 'insufficient_data');
  }

  /**
   * Get personalized workout insights
   */
  async getWorkoutInsights() {
    const insights = [];

    // Get muscle growth predictions
    const growthPredictions = await this.getMuscleGrowthPredictions();

    // Declining muscles
    const decliningMuscles = growthPredictions.filter(p => p.status === 'declining');
    if (decliningMuscles.length > 0) {
      insights.push({
        type: 'warning',
        priority: 'high',
        title: 'Volume Declining',
        message: `Your ${decliningMuscles[0].muscleGroup} volume is decreasing. Increase training frequency or intensity.`,
      });
    }

    // Plateaued muscles
    const plateauedMuscles = growthPredictions.filter(p => p.status === 'plateaued');
    if (plateauedMuscles.length > 0) {
      insights.push({
        type: 'info',
        priority: 'medium',
        title: 'Progress Plateau',
        message: `Your ${plateauedMuscles[0].muscleGroup} has plateaued. Try changing exercises or rep ranges.`,
      });
    }

    // Strong growth
    const strongGrowth = growthPredictions.filter(p => p.status === 'strong_growth');
    if (strongGrowth.length > 0) {
      insights.push({
        type: 'success',
        priority: 'low',
        title: 'Excellent Progress!',
        message: `Your ${strongGrowth[0].muscleGroup} is growing strongly at ${strongGrowth[0].percentageGrowth}% per week!`,
      });
    }

    // Fallback if no specific insights
    if (insights.length === 0) {
        insights.push({
            type: 'info',
            priority: 'low',
            title: 'Keep Going!',
            message: 'Consistency is key. Keep logging your workouts to generate more insights.',
        });
    }

    return insights;
  }
}

export default new PredictionsRepository();
