# Fix #3: State Management with React Context

## Problem
Without state management:
- Components can't share workout data
- No way to update UI when data changes
- Database queries repeated across components
- Props drilling through multiple levels
- Hard to maintain current workout session

## Solution: React Context API

### Why Context API?
- **Built-in**: No external dependencies
- **Simple**: Easy to understand and maintain
- **Efficient**: Prevents unnecessary re-renders
- **Perfect fit**: Ideal for workout session management
- **No overhead**: Unlike Redux, no boilerplate

### Implementation Steps

#### 1. Create Workout Context

Create `workout-logger/contexts/WorkoutContext.js`:

```javascript
import React, { createContext, useContext, useState, useEffect } from 'react';
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

  /**
   * Start a new workout session
   */
  const startWorkout = async (name) => {
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
  };

  /**
   * Add exercise to active workout
   */
  const addExerciseToWorkout = async (exerciseId) => {
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
  };

  /**
   * Add set to exercise in active workout
   */
  const addSet = async (workoutExerciseId, weightLbs = null, reps = null) => {
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
  };

  /**
   * Update set values
   */
  const updateSet = async (setId, updates) => {
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
    if (!activeWorkout) throw new Error('No active workout');

    await SetRepository.deleteSet(setId);

    setActiveWorkout(prev => ({
      ...prev,
      exercises: prev.exercises.map(ex => ({
        ...ex,
        sets: ex.sets.filter(set => set.id !== setId),
      })),
    }));
  };

  /**
   * Remove exercise from workout
   */
  const removeExercise = async (workoutExerciseId) => {
    if (!activeWorkout) throw new Error('No active workout');

    await ExerciseRepository.removeExerciseFromWorkout(workoutExerciseId);

    setActiveWorkout(prev => ({
      ...prev,
      exercises: prev.exercises.filter(
        ex => ex.workout_exercise_id !== workoutExerciseId
      ),
    }));
  };

  /**
   * Finish workout
   */
  const finishWorkout = async () => {
    if (!activeWorkout || !workoutStartTime) throw new Error('No active workout');

    const endTime = new Date().toISOString();
    const durationSeconds = Math.floor((new Date(endTime) - workoutStartTime) / 1000);

    await WorkoutRepository.finishWorkout(activeWorkout.id, endTime, durationSeconds);

    setActiveWorkout(null);
    setWorkoutStartTime(null);
    setIsWorkoutActive(false);

    return { endTime, durationSeconds };
  };

  /**
   * Cancel workout (delete it)
   */
  const cancelWorkout = async () => {
    if (!activeWorkout) return;

    await WorkoutRepository.deleteWorkout(activeWorkout.id);
    
    setActiveWorkout(null);
    setWorkoutStartTime(null);
    setIsWorkoutActive(false);
  };

  /**
   * Load a previous workout to view/edit
   */
  const loadWorkout = async (workoutId) => {
    const workout = await WorkoutRepository.getWorkoutById(workoutId);
    return workout;
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
  };

  return <WorkoutContext.Provider value={value}>{children}</WorkoutContext.Provider>;
};
```

#### 2. Create Exercise Library Context

Create `workout-logger/contexts/ExerciseContext.js`:

```javascript
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

  /**
   * Load all exercises from database
   */
  const loadExercises = async () => {
    setLoading(true);
    try {
      const allExercises = await ExerciseRepository.getAllExercises({
        muscleGroup: selectedMuscleGroup,
        searchQuery: searchQuery || null,
      });
      setExercises(allExercises);
    } catch (error) {
      console.error('Failed to load exercises:', error);
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
      console.error('Failed to load muscle groups:', error);
    }
  };

  /**
   * Create custom exercise
   */
  const createCustomExercise = async (exerciseData) => {
    const id = await ExerciseRepository.createExercise(exerciseData);
    await loadExercises();
    return id;
  };

  /**
   * Get exercise history
   */
  const getExerciseHistory = async (exerciseId) => {
    return await ExerciseRepository.getExerciseHistory(exerciseId);
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
    loadExercises,
    createCustomExercise,
    getExerciseHistory,
    searchExercises,
    filterByMuscleGroup,
  };

  return <ExerciseContext.Provider value={value}>{children}</ExerciseContext.Provider>;
};
```

#### 3. Create History/Analytics Context

Create `workout-logger/contexts/HistoryContext.js`:

```javascript
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

  /**
   * Load workout history
   */
  const loadWorkouts = async (limit = 50, offset = 0) => {
    setLoading(true);
    try {
      const data = await WorkoutRepository.getAllWorkouts({ limit, offset });
      setWorkouts(data);
    } catch (error) {
      console.error('Failed to load workouts:', error);
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
      console.error('Failed to load stats:', error);
    }
  };

  /**
   * Get volume by muscle group
   */
  const getVolumeByMuscleGroup = async (startDate, endDate) => {
    return await AnalyticsRepository.getVolumeByMuscleGroup(startDate, endDate);
  };

  /**
   * Get workout frequency
   */
  const getWorkoutFrequency = async (weeks = 12) => {
    return await AnalyticsRepository.getWorkoutFrequency(weeks);
  };

  /**
   * Get personal records
   */
  const getPersonalRecords = async () => {
    return await AnalyticsRepository.getPersonalRecords();
  };

  /**
   * Delete a workout
   */
  const deleteWorkout = async (workoutId) => {
    await WorkoutRepository.deleteWorkout(workoutId);
    await loadWorkouts();
    await loadStats();
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
    loadWorkouts,
    loadStats,
    getVolumeByMuscleGroup,
    getWorkoutFrequency,
    getPersonalRecords,
    deleteWorkout,
  };

  return <HistoryContext.Provider value={value}>{children}</HistoryContext.Provider>;
};
```

#### 4. Wrap App with Providers

Update `workout-logger/App.js`:

```javascript
import React, { useEffect, useState } from 'react';
import AppNavigator from './navigation/AppNavigator';
import DatabaseService from './services/database';
import { ActivityIndicator, View } from 'react-native';
import { WorkoutProvider } from './contexts/WorkoutContext';
import { ExerciseProvider } from './contexts/ExerciseContext';
import { HistoryProvider } from './contexts/HistoryContext';

export default function App() {
  const [isDbReady, setIsDbReady] = useState(false);

  useEffect(() => {
    async function initializeApp() {
      await DatabaseService.init();
      setIsDbReady(true);
    }
    initializeApp();
  }, []);

  if (!isDbReady) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#101322' }}>
        <ActivityIndicator size="large" color="#1337ec" />
      </View>
    );
  }

  return (
    <WorkoutProvider>
      <ExerciseProvider>
        <HistoryProvider>
          <AppNavigator />
        </HistoryProvider>
      </ExerciseProvider>
    </WorkoutProvider>
  );
}
```

### Files to Create
- `workout-logger/contexts/WorkoutContext.js` - Active workout session management
- `workout-logger/contexts/ExerciseContext.js` - Exercise library management
- `workout-logger/contexts/HistoryContext.js` - History and analytics

### Files to Modify
- `workout-logger/App.js` - Wrap with context providers

### Testing Checklist
- [ ] Can start a workout session
- [ ] Can add exercises to active workout
- [ ] Can add and update sets
- [ ] State updates reflect in UI immediately
- [ ] Finishing workout saves to database
- [ ] Context persists across screen navigation

### Usage Examples

In any component:

```javascript
import { useWorkout } from '../contexts/WorkoutContext';

const MyComponent = () => {
  const { 
    activeWorkout, 
    isWorkoutActive, 
    startWorkout, 
    addExerciseToWorkout 
  } = useWorkout();

  // Start workout
  const handleStart = async () => {
    await startWorkout('Morning Workout');
  };

  // Add exercise
  const handleAddExercise = async (exerciseId) => {
    await addExerciseToWorkout(exerciseId);
  };

  return (
    <View>
      {isWorkoutActive ? (
        <Text>Workout in progress!</Text>
      ) : (
        <Button title="Start Workout" onPress={handleStart} />
      )}
    </View>
  );
};
```

### Next Steps
- Fix #4: Update WorkoutLoggerScreen to use contexts
- Fix #5: Update HistoryScreen to display real data
- Fix #6: Update ExerciseLibraryScreen with search/filter
