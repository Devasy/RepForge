import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Modal,
  FlatList,
  Alert
} from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useWorkout } from '../contexts/WorkoutContext';
import { useExercise } from '../contexts/ExerciseContext';
import { useFocusEffect } from '@react-navigation/native';

// Note: Alert.alert is used as a placeholder for error handling.
// It should be replaced with Toast notifications in a future UI polish step.

const SetRow = ({ set, onUpdateSet, onDeleteSet }) => {
  const [weight, setWeight] = useState(set.weight_lbs?.toString() || '');
  const [reps, setReps] = useState(set.reps?.toString() || '');

  // Sync local state when prop changes (e.g. initial load or external update)
  useEffect(() => {
    setWeight(set.weight_lbs?.toString() || '');
  }, [set.weight_lbs]);

  useEffect(() => {
    setReps(set.reps?.toString() || '');
  }, [set.reps]);

  const handleWeightBlur = () => {
    const val = parseFloat(weight);
    if (!isNaN(val) && val !== set.weight_lbs) {
      onUpdateSet(set.id, { weight_lbs: val });
    }
  };

  const handleRepsBlur = () => {
    const val = parseInt(reps);
    if (!isNaN(val) && val !== set.reps) {
      onUpdateSet(set.id, { reps: val });
    }
  };

  return (
    <View style={styles.setRow}>
      <Text style={styles.setText}>{set.set_number}</Text>

      <TextInput
        style={styles.input}
        value={weight}
        onChangeText={setWeight}
        onBlur={handleWeightBlur}
        keyboardType="numeric"
        placeholder="0"
        placeholderTextColor="#929bc9"
      />

      <TextInput
        style={styles.input}
        value={reps}
        onChangeText={setReps}
        onBlur={handleRepsBlur}
        keyboardType="numeric"
        placeholder="0"
        placeholderTextColor="#929bc9"
      />

      <TouchableOpacity
        style={[styles.checkbox, set.is_completed && styles.checkboxChecked]}
        onPress={() => onUpdateSet(set.id, { is_completed: set.is_completed ? 0 : 1 })}
      >
        {set.is_completed ? (
          <MaterialCommunityIcons name="check" size={16} color="white" />
        ) : null}
      </TouchableOpacity>

      <TouchableOpacity onPress={() => onDeleteSet(set.id)}>
        <MaterialCommunityIcons name="close" size={16} color="#929bc9" />
      </TouchableOpacity>
    </View>
  );
};

const ExerciseCard = ({ exercise, onAddSet, onUpdateSet, onDeleteSet, onRemove }) => {
  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <View style={styles.cardHeaderText}>
          <Text style={styles.cardTitle}>{exercise.name}</Text>
          <Text style={styles.cardSubtitle}>
            {exercise.equipment_type} • {exercise.muscle_group}
          </Text>
        </View>
        <TouchableOpacity onPress={() => onRemove(exercise.workout_exercise_id)}>
          <MaterialCommunityIcons name="delete-outline" size={24} color="#929bc9" />
        </TouchableOpacity>
      </View>

      <View style={styles.setsContainer}>
        <View style={styles.setsHeader}>
          <Text style={styles.setHeaderText}>Set</Text>
          <Text style={styles.setHeaderText}>Lbs</Text>
          <Text style={styles.setHeaderText}>Reps</Text>
          <MaterialCommunityIcons name="check" size={18} color="#929bc9" />
        </View>

        {exercise.sets.map((set) => (
          <SetRow
            key={set.id}
            set={set}
            onUpdateSet={onUpdateSet}
            onDeleteSet={onDeleteSet}
          />
        ))}
      </View>

      <TouchableOpacity
        style={styles.addSetButton}
        onPress={() => onAddSet(exercise.workout_exercise_id)}
      >
        <Text style={styles.addSetButtonText}>Add Set</Text>
      </TouchableOpacity>
    </View>
  );
};

const ExercisePickerModal = ({ visible, onClose, onSelectExercise }) => {
  const { exercises, searchExercises, filterByMuscleGroup, muscleGroups } = useExercise();
  const [selectedFilter, setSelectedFilter] = useState(null);

  const handleFilterSelect = (filter) => {
    setSelectedFilter(filter);
    filterByMuscleGroup(filter);
  };

  return (
    <Modal visible={visible} animationType="slide" transparent={true}>
      <View style={styles.modalContainer}>
        <View style={styles.modalContent}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Add Exercise</Text>
            <TouchableOpacity onPress={onClose}>
              <MaterialCommunityIcons name="close" size={24} color="white" />
            </TouchableOpacity>
          </View>

          <TextInput
            style={styles.searchInput}
            placeholder="Search exercises..."
            placeholderTextColor="#929bc9"
            onChangeText={searchExercises}
          />

          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.filterChips}>
            <TouchableOpacity
              style={[styles.filterChip, !selectedFilter && styles.filterChipActive]}
              onPress={() => handleFilterSelect(null)}
            >
              <Text style={[styles.filterChipText, !selectedFilter && styles.filterChipTextActive]}>
                All
              </Text>
            </TouchableOpacity>
            {muscleGroups.map((group) => (
              <TouchableOpacity
                key={group}
                style={[styles.filterChip, selectedFilter === group && styles.filterChipActive]}
                onPress={() => handleFilterSelect(group)}
              >
                <Text style={[styles.filterChipText, selectedFilter === group && styles.filterChipTextActive]}>
                  {group}
                </Text>
              </TouchableOpacity>
            ))}
          </ScrollView>

          <FlatList
            data={exercises}
            keyExtractor={(item) => item.id.toString()}
            renderItem={({ item }) => (
              <TouchableOpacity
                style={styles.exerciseItem}
                onPress={() => {
                  onSelectExercise(item.id);
                  onClose();
                }}
              >
                <View>
                  <Text style={styles.exerciseName}>{item.name}</Text>
                  <Text style={styles.exerciseDetails}>
                    {item.muscle_group} • {item.equipment_type}
                  </Text>
                </View>
                <MaterialCommunityIcons name="plus" size={24} color="#1337ec" />
              </TouchableOpacity>
            )}
          />
        </View>
      </View>
    </Modal>
  );
};

const WorkoutLoggerScreen = ({ navigation }) => {
  const {
    activeWorkout,
    isWorkoutActive,
    startWorkout,
    finishWorkout,
    cancelWorkout,
    addExerciseToWorkout,
    removeExercise,
    addSet,
    updateSet,
    deleteSet,
    getWorkoutStats,
  } = useWorkout();

  const [showExercisePicker, setShowExercisePicker] = useState(false);
  const [stats, setStats] = useState({ totalVolume: 0, completedSets: 0, duration: 0 });

  // Update stats every second
  useEffect(() => {
    let interval;
    if (isWorkoutActive && activeWorkout) {
      // Calculate immediate stats
      setStats(getWorkoutStats());

      // Update timer every second
      interval = setInterval(() => {
        setStats(getWorkoutStats());
      }, 1000);
    }
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [isWorkoutActive, activeWorkout, getWorkoutStats]);

  const handleStartWorkout = async (name) => {
    try {
      await startWorkout(name);
    } catch (error) {
      Alert.alert('Error', 'Failed to start workout');
    }
  };

  // Start workout on screen focus if not active
  useFocusEffect(
    React.useCallback(() => {
      const initWorkout = async () => {
        if (!isWorkoutActive) {
            const name = `Workout - ${new Date().toLocaleDateString()}`;
            await handleStartWorkout(name);
        }
      };

      // Using a small timeout to ensure we don't conflict with navigation transitions
      // and checking if we actually need to start one
      const timer = setTimeout(() => {
          initWorkout();
      }, 100);

      return () => clearTimeout(timer);
    }, [isWorkoutActive]) // Depend on isWorkoutActive to re-run if it changes while focused
  );

  const handleFinishWorkout = async () => {
    Alert.alert(
      'Finish Workout',
      'Are you sure you want to finish this workout?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Finish',
          onPress: async () => {
            try {
              await finishWorkout();
              Alert.alert('Success', 'Workout completed!');
              navigation.navigate('History');
            } catch (error) {
              Alert.alert('Error', 'Failed to finish workout');
            }
          },
        },
      ]
    );
  };

  const handleCancelWorkout = () => {
    Alert.alert(
      'Cancel Workout',
      'Are you sure? This will delete all progress.',
      [
        { text: 'No', style: 'cancel' },
        {
          text: 'Yes, Delete',
          style: 'destructive',
          onPress: async () => {
            await cancelWorkout();
            navigation.navigate('History');
          },
        },
      ]
    );
  };

  const handleAddExercise = async (exerciseId) => {
    try {
      const exercise = await addExerciseToWorkout(exerciseId);
      // Add first set automatically
      await handleAddSet(exercise.workout_exercise_id);
    } catch (error) {
      Alert.alert('Error', 'Failed to add exercise');
    }
  };

  const handleAddSet = async (workoutExerciseId) => {
    try {
      await addSet(workoutExerciseId, null, null);
    } catch (error) {
      Alert.alert('Error', 'Failed to add set');
    }
  };

  const handleUpdateSet = async (setId, updates) => {
    try {
      await updateSet(setId, updates);
    } catch (error) {
      Alert.alert('Error', 'Failed to update set');
    }
  };

  const handleDeleteSet = async (setId) => {
    try {
      await deleteSet(setId);
    } catch (error) {
      Alert.alert('Error', 'Failed to delete set');
    }
  };

  const handleRemoveExercise = async (workoutExerciseId) => {
    Alert.alert(
      'Remove Exercise',
      'Remove this exercise from workout?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: async () => {
            try {
              await removeExercise(workoutExerciseId);
            } catch (error) {
              Alert.alert('Error', 'Failed to remove exercise');
            }
          },
        },
      ]
    );
  };

  const formatDuration = (seconds) => {
    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hrs.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  if (!isWorkoutActive || !activeWorkout) {
    return (
      <View style={[styles.container, styles.centerContainer]}>
        <Text style={styles.emptyText}>Starting workout...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={handleCancelWorkout}>
          <MaterialCommunityIcons name="close" size={24} color="white" />
        </TouchableOpacity>

        <View style={styles.headerTitleContainer}>
          <Text style={styles.headerTitle}>{activeWorkout.name}</Text>
          <Text style={styles.headerSubtitle}>
            {formatDuration(stats.duration)} | {stats.totalVolume.toFixed(0)} lbs
          </Text>
        </View>

        <TouchableOpacity style={styles.finishButton} onPress={handleFinishWorkout}>
          <Text style={styles.finishButtonText}>Finish</Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.scrollContainer}>
        {activeWorkout.exercises.length === 0 ? (
          <View style={styles.emptyState}>
            <MaterialCommunityIcons name="dumbbell" size={64} color="#929bc9" />
            <Text style={styles.emptyText}>No exercises added yet</Text>
            <Text style={styles.emptySubtext}>Tap the + button below to add exercises</Text>
          </View>
        ) : (
          activeWorkout.exercises.map((exercise) => (
            <ExerciseCard
              key={exercise.workout_exercise_id}
              exercise={exercise}
              onAddSet={handleAddSet}
              onUpdateSet={handleUpdateSet}
              onDeleteSet={handleDeleteSet}
              onRemove={handleRemoveExercise}
            />
          ))
        )}
      </ScrollView>

      <TouchableOpacity
        style={styles.fab}
        onPress={() => setShowExercisePicker(true)}
      >
        <MaterialCommunityIcons name="plus" size={24} color="white" />
        <Text style={styles.fabText}>Add Exercise</Text>
      </TouchableOpacity>

      <ExercisePickerModal
        visible={showExercisePicker}
        onClose={() => setShowExercisePicker(false)}
        onSelectExercise={handleAddExercise}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#101322',
  },
  centerContainer: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    paddingTop: 40,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2f4c',
  },
  headerTitleContainer: {
    alignItems: 'center',
  },
  headerTitle: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  headerSubtitle: {
    color: '#929bc9',
    fontSize: 12,
  },
  finishButton: {
    backgroundColor: '#1337ec',
    paddingVertical: 8,
    paddingHorizontal: 15,
    borderRadius: 5,
  },
  finishButtonText: {
    color: 'white',
    fontWeight: 'bold',
  },
  scrollContainer: {
    flex: 1,
    padding: 20,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
  },
  emptyText: {
    color: '#929bc9',
    fontSize: 18,
    marginTop: 20,
  },
  emptySubtext: {
    color: '#929bc9',
    fontSize: 14,
    marginTop: 10,
  },
  card: {
    backgroundColor: '#1c2136',
    borderRadius: 10,
    marginBottom: 20,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2f4c',
  },
  cardHeaderText: {},
  cardTitle: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  cardSubtitle: {
    color: '#929bc9',
    fontSize: 12,
  },
  setsContainer: {
    padding: 15,
  },
  setsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  setHeaderText: {
    color: '#929bc9',
    fontSize: 12,
    width: 50,
    textAlign: 'center',
  },
  setRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  setText: {
    color: 'white',
    width: 50,
    textAlign: 'center',
  },
  input: {
    backgroundColor: '#2a2f4c',
    color: 'white',
    width: 70,
    padding: 8,
    borderRadius: 5,
    textAlign: 'center',
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 4,
    borderWidth: 2,
    borderColor: '#929bc9',
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxChecked: {
    backgroundColor: '#1337ec',
    borderColor: '#1337ec',
  },
  addSetButton: {
    padding: 12,
    alignItems: 'center',
    borderTopWidth: 1,
    borderTopColor: '#2a2f4c',
  },
  addSetButtonText: {
    color: '#1337ec',
    fontWeight: 'bold',
  },
  fab: {
    position: 'absolute',
    bottom: 20,
    right: 20,
    backgroundColor: '#1337ec',
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 30,
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  fabText: {
    color: 'white',
    marginLeft: 8,
    fontWeight: 'bold',
  },
  // Modal styles
  modalContainer: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.8)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#1c2136',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 20,
    maxHeight: '80%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  modalTitle: {
    color: 'white',
    fontSize: 20,
    fontWeight: 'bold',
  },
  searchInput: {
    backgroundColor: '#2a2f4c',
    color: 'white',
    padding: 12,
    borderRadius: 10,    marginBottom: 15,
  },
  filterChips: {
    marginBottom: 15,
  },
  filterChip: {
    backgroundColor: '#2a2f4c',
    paddingVertical: 8,
    paddingHorizontal: 15,
    borderRadius: 20,
    marginRight: 10,
  },
  filterChipActive: {
    backgroundColor: '#1337ec',
  },
  filterChipText: {
    color: '#929bc9',
  },
  filterChipTextActive: {
    color: 'white',
    fontWeight: 'bold',
  },
  exerciseItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#2a2f4c',
    padding: 15,
    borderRadius: 10,
    marginBottom: 10,
  },
  exerciseName: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
  },
  exerciseDetails: {
    color: '#929bc9',
    fontSize: 12,
  },
});

export default WorkoutLoggerScreen;
