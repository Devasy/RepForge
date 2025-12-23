import React, { createContext, useContext, useState, useEffect } from 'react';
import WorkoutRepository from '../repositories/WorkoutRepository';
import AnalyticsRepository from '../repositories/AnalyticsRepository';

const HistoryContext = createContext();

export const useHistory = () => {
  const context = useContext(HistoryContext);
  if (!context) {
    throw new Error('useHistory must be used within HistoryProvider');
  }
  return context;
};

export const HistoryProvider = ({ children }) => {
  const [workouts, setWorkouts] = useState([]);
  const [stats, setStats] = useState({
    totalWorkouts: 0,
    currentStreak: 0,
    totalVolume: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const clearError = () => setError(null);

  const handleError = (e) => {
    console.error(e);
    setError(e.message || 'An error occurred');
  };

  /**
   * Load workout history
   */
  const loadWorkouts = async (limit = 50, offset = 0) => {
    setLoading(true);
    setError(null);
    try {
      const data = await WorkoutRepository.getAllWorkouts({ limit, offset });
      setWorkouts(data);
    } catch (error) {
      handleError(error);
    } finally {
      setLoading(false);
    }
  };

  /**
   * Load statistics
   */
  const loadStats = async () => {
    try {
      const workoutStats = await WorkoutRepository.getWorkoutStats();
      const streak = await WorkoutRepository.getCurrentStreak();

      setStats({
        totalWorkouts: workoutStats.total_workouts || 0,
        currentStreak: streak,
        totalVolume: workoutStats.total_volume || 0,
      });
    } catch (error) {
      handleError(error);
    }
  };

  /**
   * Get volume by muscle group
   */
  const getVolumeByMuscleGroup = async (startDate, endDate) => {
    try {
      return await AnalyticsRepository.getVolumeByMuscleGroup(startDate, endDate);
    } catch (e) {
      handleError(e);
      throw e;
    }
  };

  /**
   * Get workout frequency
   */
  const getWorkoutFrequency = async (weeks = 12) => {
    try {
      return await AnalyticsRepository.getWorkoutFrequency(weeks);
    } catch (e) {
      handleError(e);
      throw e;
    }
  };

  /**
   * Get personal records
   */
  const getPersonalRecords = async () => {
    try {
      return await AnalyticsRepository.getPersonalRecords();
    } catch (e) {
      handleError(e);
      throw e;
    }
  };

  /**
   * Delete a workout
   */
  const deleteWorkout = async (workoutId) => {
    try {
      setError(null);
      await WorkoutRepository.deleteWorkout(workoutId);
      await loadWorkouts();
      await loadStats();
    } catch (e) {
      handleError(e);
      throw e;
    }
  };

  // Load data on mount
  useEffect(() => {
    loadWorkouts();
    loadStats();
  }, []);

  const value = {
    workouts,
    stats,
    loading,
    error,
    loadWorkouts,
    loadStats,
    getVolumeByMuscleGroup,
    getWorkoutFrequency,
    getPersonalRecords,
    deleteWorkout,
    clearError,
  };

  return <HistoryContext.Provider value={value}>{children}</HistoryContext.Provider>;
};
