# Fix #8: Progressive Overload Prediction with Regression

## Problem
- No predictions for next workout weights/reps
- No progressive overload tracking
- No AI-powered recommendations
- No growth rate calculations
- No regression analysis

## Solution: Implement Linear Regression for Predictions

### Why Regression for Progressive Overload?

Progressive overload requires gradual increases in:
- **Weight**: Lifting heavier over time
- **Reps**: Performing more repetitions
- **Volume**: Total weight × reps × sets

Linear regression helps predict:
1. Next workout's recommended weight/reps
2. Expected strength gains over time
3. Optimal volume increase per week
4. When to deload based on trends

### Implementation Steps

#### 1. Create Regression Service

Create `workout-logger/services/RegressionService.js`:

```javascript
/**
 * Simple Linear Regression Service
 * Used for predicting progressive overload recommendations
 */
class RegressionService {
  /**
   * Calculate linear regression for a dataset
   * @param {Array} dataPoints - Array of {x, y} points
   * @returns {Object} - {slope, intercept, rSquared}
   */
  linearRegression(dataPoints) {
    if (dataPoints.length < 2) {
      return null;
    }

    const n = dataPoints.length;
    let sumX = 0;
    let sumY = 0;
    let sumXY = 0;
    let sumXX = 0;
    let sumYY = 0;

    for (const point of dataPoints) {
      sumX += point.x;
      sumY += point.y;
      sumXY += point.x * point.y;
      sumXX += point.x * point.x;
      sumYY += point.y * point.y;
    }

    const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    const intercept = (sumY - slope * sumX) / n;

    // Calculate R² (coefficient of determination)
    const meanY = sumY / n;
    let ssRes = 0; // Sum of squares of residuals
    let ssTot = 0; // Total sum of squares

    for (const point of dataPoints) {
      const predicted = slope * point.x + intercept;
      ssRes += Math.pow(point.y - predicted, 2);
      ssTot += Math.pow(point.y - meanY, 2);
    }

    const rSquared = 1 - (ssRes / ssTot);

    return { slope, intercept, rSquared };
  }

  /**
   * Predict next value based on regression
   */
  predict(regression, x) {
    if (!regression) return null;
    return regression.slope * x + regression.intercept;
  }

  /**
   * Calculate progressive overload recommendation for an exercise
   * @param {Array} history - Array of workout history with weight and reps
   * @returns {Object} - Recommended weight and reps
   */
  calculateProgressiveOverload(history) {
    if (history.length === 0) {
      return {
        recommendedWeight: 0,
        recommendedReps: 10,
        confidence: 0,
        message: 'No history available. Start with a comfortable weight.',
      };
    }

    // Sort by date
    history.sort((a, b) => new Date(a.date) - new Date(b.date));

    // Calculate volume trend (weight × reps)
    const volumePoints = history.map((entry, index) => ({
      x: index,
      y: entry.weight_lbs * entry.reps,
    }));

    const volumeRegression = this.linearRegression(volumePoints);

    // Calculate weight trend
    const weightPoints = history.map((entry, index) => ({
      x: index,
      y: entry.weight_lbs,
    }));

    const weightRegression = this.linearRegression(weightPoints);

    // Get most recent workout
    const lastWorkout = history[history.length - 1];
    const nextIndex = history.length;

    // Predict next workout values
    let recommendedWeight = lastWorkout.weight_lbs;
    let recommendedReps = lastWorkout.reps;

    if (weightRegression && weightRegression.rSquared > 0.3) {
      // Good trend, use regression
      const predictedWeight = this.predict(weightRegression, nextIndex);
      
      // Progressive overload: increase by 2.5-5%
      recommendedWeight = Math.round(predictedWeight * 1.025 / 2.5) * 2.5;
      
      // Adjust reps based on weight increase
      const weightIncrease = (recommendedWeight - lastWorkout.weight_lbs) / lastWorkout.weight_lbs;
      
      if (weightIncrease > 0.05) {
        // Significant weight increase, reduce reps slightly
        recommendedReps = Math.max(lastWorkout.reps - 1, 5);
      } else {
        // Small weight increase, maintain or increase reps
        recommendedReps = Math.min(lastWorkout.reps + 1, 12);
      }
    } else {
      // Poor trend or not enough data, use simple progression
      if (lastWorkout.reps >= 12) {
        // High reps, increase weight
        recommendedWeight = lastWorkout.weight_lbs + 5;
        recommendedReps = 8;
      } else {
        // Low-medium reps, increase reps first
        recommendedWeight = lastWorkout.weight_lbs;
        recommendedReps = lastWorkout.reps + 1;
      }
    }

    // Determine confidence and message
    let confidence = 0;
    let message = '';

    if (!weightRegression) {
      confidence = 20;
      message = 'Start building your trend. Be consistent!';
    } else if (weightRegression.rSquared < 0.3) {
      confidence = 40;
      message = 'Your progress is inconsistent. Focus on form and consistency.';
    } else if (weightRegression.rSquared < 0.7) {
      confidence = 70;
      message = 'Good progress! Keep pushing gradually.';
    } else {
      confidence = 90;
      message = 'Excellent progression! You're getting stronger.';
    }

    return {
      recommendedWeight,
      recommendedReps,
      confidence,
      message,
      trend: weightRegression ? (weightRegression.slope > 0 ? 'increasing' : 'decreasing') : 'neutral',
      rSquared: weightRegression ? weightRegression.rSquared : 0,
    };
  }

  /**
   * Calculate muscle group growth rate
   * @param {Array} volumeHistory - Array of {week, volume} data points
   * @returns {Object} - Growth rate and predictions
   */
  calculateMuscleGrowthRate(volumeHistory) {
    if (volumeHistory.length < 3) {
      return {
        weeklyGrowthRate: 0,
        predictedNextWeekVolume: 0,
        status: 'insufficient_data',
      };
    }

    const dataPoints = volumeHistory.map((entry, index) => ({
      x: index,
      y: entry.volume,
    }));

    const regression = this.linearRegression(dataPoints);

    if (!regression) {
      return {
        weeklyGrowthRate: 0,
        predictedNextWeekVolume: volumeHistory[volumeHistory.length - 1].volume,
        status: 'no_trend',
      };
    }

    const weeklyGrowthRate = regression.slope;
    const currentVolume = volumeHistory[volumeHistory.length - 1].volume;
    const predictedNextWeekVolume = this.predict(regression, volumeHistory.length);

    let status = 'on_track';
    
    if (regression.slope < 0) {
      status = 'declining';
    } else if (regression.slope === 0) {
      status = 'plateaued';
    } else if (regression.rSquared > 0.7) {
      status = 'strong_growth';
    }

    return {
      weeklyGrowthRate,
      predictedNextWeekVolume: Math.round(predictedNextWeekVolume),
      currentVolume: Math.round(currentVolume),
      rSquared: regression.rSquared,
      status,
      percentageGrowth: currentVolume > 0 
        ? Math.round((weeklyGrowthRate / currentVolume) * 100) 
        : 0,
    };
  }

  /**
   * Determine if deload is recommended
   * @param {Array} history - Recent workout history
   * @returns {Boolean} - Whether deload is recommended
   */
  shouldDeload(history) {
    if (history.length < 4) return false;

    // Check if performance is declining over last 4 workouts
    const recentPoints = history.slice(-4).map((entry, index) => ({
      x: index,
      y: entry.weight_lbs * entry.reps,
    }));

    const regression = this.linearRegression(recentPoints);

    if (!regression) return false;

    // Recommend deload if:
    // 1. Volume is declining (negative slope)
    // 2. Decline is statistically significant (R² > 0.5)
    return regression.slope < 0 && regression.rSquared > 0.5;
  }
}

export default new RegressionService();
```

#### 2. Create Predictions Repository

Create `workout-logger/repositories/PredictionsRepository.js`:

```javascript
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
    const history = await ExerciseRepository.getExerciseHistory(exerciseId, 20);

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
      if (!workoutMap[entry.date] || 
          (entry.weight_lbs * entry.reps) > (workoutMap[entry.date].weight_lbs * workoutMap[entry.date].reps)) {
        workoutMap[entry.date] = entry;
      }
    });

    const bestSets = Object.values(workoutMap);
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

    return insights;
  }
}

export default new PredictionsRepository();
```

#### 3. Update WorkoutLoggerScreen to Show Recommendations

Add this to the `ExerciseCard` component in [WorkoutLoggerScreen.js](workout-logger/screens/WorkoutLoggerScreen.js):

```javascript
import PredictionsRepository from '../repositories/PredictionsRepository';

// Inside WorkoutLoggerScreen component, add state
const [recommendations, setRecommendations] = useState({});

// Load recommendations when exercises are added
const loadRecommendation = async (exerciseId) => {
  const rec = await PredictionsRepository.getExerciseRecommendation(exerciseId);
  setRecommendations(prev => ({
    ...prev,
    [exerciseId]: rec,
  }));
};

// In ExerciseCard, show recommendation
const ExerciseCard = ({ exercise, recommendation }) => {
  return (
    <View style={styles.card}>
      {/* ...existing code... */}
      
      {recommendation && recommendation.hasHistory && (
        <View style={styles.recommendationBanner}>
          <MaterialCommunityIcons name="lightbulb" size={16} color="#f9a825" />
          <Text style={styles.recommendationText}>
            Suggested: {recommendation.recommendation.recommendedWeight} lbs × {' '}
            {recommendation.recommendation.recommendedReps} reps
          </Text>
        </View>
      )}
      
      {/* ...rest of card... */}
    </View>
  );
};
```

### Key Features Implemented

1. **Linear Regression**: Statistical analysis of strength progression
2. **Progressive Overload**: Automatic weight/rep recommendations
3. **Confidence Scores**: How reliable the predictions are
4. **Deload Detection**: Warns when performance is declining
5. **Muscle Growth Rate**: Weekly growth percentage per muscle
6. **Trend Analysis**: Increasing, decreasing, or plateaued
7. **Personalized Insights**: AI-powered recommendations

### Algorithm Explanation

**Progressive Overload Formula**:
```
If R² > 0.7 (strong trend):
  Next Weight = Predicted Weight × 1.025 (2.5% increase)
  Next Reps = Adjusted based on weight increase

If R² < 0.7 (weak trend):
  If Reps >= 12:
    Next Weight = Current Weight + 5 lbs
    Next Reps = 8
  Else:
    Next Weight = Current Weight
    Next Reps = Current Reps + 1
```

**Deload Trigger**:
```
If last 4 workouts show:
  - Declining volume (negative slope)
  - R² > 0.5 (significant decline)
  → Recommend deload week
```

### Files to Create
- `workout-logger/services/RegressionService.js`
- `workout-logger/repositories/PredictionsRepository.js`

### Files to Modify
- `workout-logger/screens/WorkoutLoggerScreen.js` - Show recommendations
- `workout-logger/screens/ProgressDashboardScreen.js` - Show growth predictions

### Testing Checklist
- [ ] Predictions work with various history lengths
- [ ] Recommendations increase gradually (2.5-5%)
- [ ] Deload detection works when performance declines
- [ ] Growth rate calculations are accurate
- [ ] R² confidence scores are meaningful
- [ ] Handles edge cases (no history, single workout)

### Next Steps
- Fix #9: Create workout detail view screen
- Fix #10: Add export data functionality
