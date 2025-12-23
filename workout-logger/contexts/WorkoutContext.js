import React, { createContext, useContext, useState } from 'react';
import WorkoutRepository from '../repositories/WorkoutRepository';
import ExerciseRepository from '../repositories/ExerciseRepository';
import SetRepository from '../repositories/SetRepository';

const WorkoutContext = createContext();

export const useWorkout = () => {
  const context = useContext(WorkoutContext);
  if (!context) {
    throw new Error('useWorkout must be used within WorkoutProvider');
  }
  return context;
};

export const WorkoutProvider = ({ children }) => {
  // Active workout session
  const [activeWorkout, setActiveWorkout] = useState(null);
  const [workoutStartTime, setWorkoutStartTime] = useState(null);
  const [isWorkoutActive, setIsWorkoutActive] = useState(false);
  const [error, setError] = useState(null);

  const clearError = () => setError(null);

  const handleError = (e) => {
    console.error(e);
    setError(e.message || 'An error occurred');
    throw e;
  };

  /**
   * Start a new workout session
   */
  const startWorkout = async (name) => {
    try {
      setError(null);
      const now = new Date().toISOString();
      const date = now.split('T')[0]; // YYYY-MM-DD

      const workoutId = await WorkoutRepository.createWorkout({
        name: name || 'Workout',
        date,
        startTime: now,
      });

      const workout = {
        id: workoutId,
        name: name || 'Workout',
        date,
        startTime: now,
        exercises: [],
      };

      setActiveWorkout(workout);
      setWorkoutStartTime(new Date(now));
      setIsWorkoutActive(true);

      return workout;
    } catch (e) {
      handleError(e);
    }
  };

  /**
   * Add exercise to active workout
   */
  const addExerciseToWorkout = async (exerciseId) => {
    try {
      if (!activeWorkout) throw new Error('No active workout');

      const exercise = await ExerciseRepository.getExerciseById(exerciseId);
      const orderIndex = activeWorkout.exercises.length;

      const workoutExerciseId = await ExerciseRepository.addExerciseToWorkout(
        activeWorkout.id,
        exerciseId,
        orderIndex
      );

      const newExercise = {
        workout_exercise_id: workoutExerciseId,
        exercise_id: exerciseId,
        name: exercise.name,
        muscle_group: exercise.muscle_group,
        equipment_type: exercise.equipment_type,
        order_index: orderIndex,
        sets: [],
      };

      setActiveWorkout(prev => ({
        ...prev,
        exercises: [...prev.exercises, newExercise],
      }));

      return newExercise;
    } catch (e) {
      handleError(e);
    }
  };

  /**
   * Add set to exercise in active workout
   */
  const addSet = async (workoutExerciseId, weightLbs = null, reps = null) => {
    try {
      if (!activeWorkout) throw new Error('No active workout');

      const exercise = activeWorkout.exercises.find(
        ex => ex.workout_exercise_id === workoutExerciseId
      );

      if (!exercise) throw new Error('Exercise not found');

      const setNumber = exercise.sets.length + 1;
      const setId = await SetRepository.addSet(workoutExerciseId, setNumber, weightLbs, reps);

      const newSet = {
        id: setId,
        set_number: setNumber,
        weight_lbs: weightLbs,
        reps: reps,
        is_completed: 0,
      };

      setActiveWorkout(prev => ({
        ...prev,
        exercises: prev.exercises.map(ex =>
          ex.workout_exercise_id === workoutExerciseId
            ? { ...ex, sets: [...ex.sets, newSet] }
            : ex
        ),
      }));

      return newSet;
    } catch (e) {
      handleError(e);
    }
  };

  /**
   * Update set values
   */
  const updateSet = async (setId, updates) => {
    try {
      if (!activeWorkout) throw new Error('No active workout');

      await SetRepository.updateSet(setId, updates);

      setActiveWorkout(prev => ({
        ...prev,
        exercises: prev.exercises.map(ex => ({
          ...ex,
          sets: ex.sets.map(set =>
            set.id === setId ? { ...set, ...updates } : set
          ),
        })),
      }));
    } catch (e) {
      handleError(e);
    }
  };

  /**
   * Complete a set
   */
  const completeSet = async (setId) => {
    await updateSet(setId, { is_completed: 1 });
  };

  /**
   * Delete a set
   */
  const deleteSet = async (setId) => {
    try {
      if (!activeWorkout) throw new Error('No active workout');

      await SetRepository.deleteSet(setId);

      setActiveWorkout(prev => ({
        ...prev,
        exercises: prev.exercises.map(ex => ({
          ...ex,
          sets: ex.sets.filter(set => set.id !== setId),
        })),
      }));
    } catch (e) {
      handleError(e);
    }
  };

  /**
   * Remove exercise from workout
   */
  const removeExercise = async (workoutExerciseId) => {
    try {
      if (!activeWorkout) throw new Error('No active workout');

      await ExerciseRepository.removeExerciseFromWorkout(workoutExerciseId);

      setActiveWorkout(prev => ({
        ...prev,
        exercises: prev.exercises.filter(
          ex => ex.workout_exercise_id !== workoutExerciseId
        ),
      }));
    } catch (e) {
      handleError(e);
    }
  };

  /**
   * Finish workout
   */
  const finishWorkout = async () => {
    try {
      if (!activeWorkout || !workoutStartTime) throw new Error('No active workout');

      const endTime = new Date().toISOString();
      const durationSeconds = Math.floor((new Date(endTime) - workoutStartTime) / 1000);

      await WorkoutRepository.finishWorkout(activeWorkout.id, endTime, durationSeconds);

      setActiveWorkout(null);
      setWorkoutStartTime(null);
      setIsWorkoutActive(false);

      return { endTime, durationSeconds };
    } catch (e) {
      handleError(e);
    }
  };

  /**
   * Cancel workout (delete it)
   */
  const cancelWorkout = async () => {
    try {
      if (!activeWorkout) return;

      await WorkoutRepository.deleteWorkout(activeWorkout.id);

      setActiveWorkout(null);
      setWorkoutStartTime(null);
      setIsWorkoutActive(false);
    } catch (e) {
      handleError(e);
    }
  };

  /**
   * Load a previous workout to view/edit
   */
  const loadWorkout = async (workoutId) => {
    try {
      const workout = await WorkoutRepository.getWorkoutById(workoutId);
      return workout;
    } catch (e) {
      handleError(e);
    }
  };

  /**
   * Calculate current workout stats
   */
  const getWorkoutStats = () => {
    if (!activeWorkout) return { totalVolume: 0, completedSets: 0, duration: 0 };

    const completedSets = activeWorkout.exercises.reduce(
      (acc, ex) => acc + ex.sets.filter(s => s.is_completed).length,
      0
    );

    const totalVolume = activeWorkout.exercises.reduce(
      (acc, ex) => acc + ex.sets.reduce(
        (sum, set) => sum + (set.is_completed ? (set.weight_lbs || 0) * (set.reps || 0) : 0),
        0
      ),
      0
    );

    const duration = workoutStartTime
      ? Math.floor((new Date() - workoutStartTime) / 1000)
      : 0;

    return { totalVolume, completedSets, duration };
  };

  const value = {
    // State
    activeWorkout,
    isWorkoutActive,
    workoutStartTime,
    error,

    // Actions
    startWorkout,
    finishWorkout,
    cancelWorkout,
    loadWorkout,
    addExerciseToWorkout,
    removeExercise,
    addSet,
    updateSet,
    completeSet,
    deleteSet,
    getWorkoutStats,
    clearError,
  };

  return <WorkoutContext.Provider value={value}>{children}</WorkoutContext.Provider>;
};
