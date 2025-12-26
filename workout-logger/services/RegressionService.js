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

    const denominator = (n * sumXX - sumX * sumX);
    if (denominator === 0) return null; // Avoid division by zero

    const slope = (n * sumXY - sumX * sumY) / denominator;
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

    // If ssTot is 0 (all y values are the same), R² is technically 1 (perfect fit) or undefined.
    const rSquared = ssTot === 0 ? 0 : 1 - (ssRes / ssTot);

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
      // Round to nearest 2.5
      recommendedWeight = Math.round((predictedWeight * 1.025) / 2.5) * 2.5;

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
      message = 'Excellent progression! You\'re getting stronger.';
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
        predictedNextWeekVolume: volumeHistory.length > 0 ? volumeHistory[volumeHistory.length - 1].volume : 0,
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
