import React, { createContext, useContext, useState, useEffect } from 'react';
import ExerciseRepository from '../repositories/ExerciseRepository';

const ExerciseContext = createContext();

export const useExercise = () => {
  const context = useContext(ExerciseContext);
  if (!context) {
    throw new Error('useExercise must be used within ExerciseProvider');
  }
  return context;
};

export const ExerciseProvider = ({ children }) => {
  const [exercises, setExercises] = useState([]);
  const [muscleGroups, setMuscleGroups] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedMuscleGroup, setSelectedMuscleGroup] = useState(null);
  const [error, setError] = useState(null);

  const clearError = () => setError(null);

  const handleError = (e) => {
    console.error(e);
    setError(e.message || 'An error occurred');
  };

  /**
   * Load all exercises from database
   */
  const loadExercises = async () => {
    setLoading(true);
    setError(null);
    try {
      const allExercises = await ExerciseRepository.getAllExercises({
        muscleGroup: selectedMuscleGroup,
        searchQuery: searchQuery || null,
      });
      setExercises(allExercises);
    } catch (error) {
      handleError(error);
    } finally {
      setLoading(false);
    }
  };

  /**
   * Load muscle groups
   */
  const loadMuscleGroups = async () => {
    try {
      const groups = await ExerciseRepository.getMuscleGroups();
      setMuscleGroups(groups.map(g => g.muscle_group));
    } catch (error) {
      handleError(error);
    }
  };

  /**
   * Create custom exercise
   */
  const createCustomExercise = async (exerciseData) => {
    try {
      setError(null);
      const id = await ExerciseRepository.createExercise(exerciseData);
      await loadExercises();
      return id;
    } catch (e) {
      handleError(e);
      throw e;
    }
  };

  /**
   * Get exercise history
   */
  const getExerciseHistory = async (exerciseId) => {
    try {
      return await ExerciseRepository.getExerciseHistory(exerciseId);
    } catch (e) {
      handleError(e);
      throw e;
    }
  };

  /**
   * Search exercises
   */
  const searchExercises = (query) => {
    setSearchQuery(query);
  };

  /**
   * Filter by muscle group
   */
  const filterByMuscleGroup = (muscleGroup) => {
    setSelectedMuscleGroup(muscleGroup);
  };

  // Load exercises when filters change
  useEffect(() => {
    loadExercises();
  }, [searchQuery, selectedMuscleGroup]);

  // Load muscle groups on mount
  useEffect(() => {
    loadMuscleGroups();
  }, []);

  const value = {
    exercises,
    muscleGroups,
    loading,
    searchQuery,
    selectedMuscleGroup,
    error,
    loadExercises,
    createCustomExercise,
    getExerciseHistory,
    searchExercises,
    filterByMuscleGroup,
    clearError,
  };

  return <ExerciseContext.Provider value={value}>{children}</ExerciseContext.Provider>;
};
