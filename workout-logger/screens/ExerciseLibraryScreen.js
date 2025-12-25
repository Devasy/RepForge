import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  TextInput,
  ImageBackground,
  Modal,
  Alert
} from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useExercise } from '../contexts/ExerciseContext';

const ExerciseListItem = ({ exercise, onPress, onHistory }) => (
  <TouchableOpacity style={styles.exerciseItem} onPress={() => onPress(exercise)}>
    <ImageBackground
      source={exercise.image_url ? { uri: exercise.image_url } : require('../assets/placeholder.png')}
      style={styles.exerciseImage}
      imageStyle={{ borderRadius: 10 }}
    >
      <View style={styles.imageOverlay} />
    </ImageBackground>
    <View style={styles.exerciseInfo}>
      <Text style={styles.exerciseName}>{exercise.name}</Text>
      <Text style={styles.exerciseDetails}>
        {exercise.muscle_group} • {exercise.equipment_type || 'Bodyweight'}
      </Text>
      {exercise.is_custom === 1 && (
        <Text style={styles.customBadge}>Custom</Text>
      )}
    </View>
    <TouchableOpacity onPress={() => onHistory(exercise)}>
      <MaterialCommunityIcons name="history" size={24} color="#929bc9" />
    </TouchableOpacity>
  </TouchableOpacity>
);

const AddExerciseModal = ({ visible, onClose, onCreate }) => {
  const [name, setName] = useState('');
  const [muscleGroup, setMuscleGroup] = useState('');
  const [equipmentType, setEquipmentType] = useState('');
  const [description, setDescription] = useState('');

  const muscleGroups = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs',
    'Core', 'Cardio', 'Other'
  ];

  const equipmentTypes = [
    'Barbell', 'Dumbbell', 'Machine', 'Cable',
    'Bodyweight', 'Resistance Band', 'Other'
  ];

  const handleCreate = () => {
    if (!name.trim()) {
      Alert.alert('Error', 'Please enter exercise name');
      return;
    }
    if (!muscleGroup) {
      Alert.alert('Error', 'Please select muscle group');
      return;
    }

    onCreate({
      name: name.trim(),
      muscleGroup,
      equipmentType: equipmentType || 'Other',
      description: description.trim(),
      imageUrl: null,
    });

    // Reset form
    setName('');
    setMuscleGroup('');
    setEquipmentType('');
    setDescription('');
  };

  return (
    <Modal visible={visible} animationType="slide" transparent={true}>
      <View style={styles.modalContainer}>
        <View style={styles.modalContent}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Add Custom Exercise</Text>
            <TouchableOpacity onPress={onClose}>
              <MaterialCommunityIcons name="close" size={24} color="white" />
            </TouchableOpacity>
          </View>

          <ScrollView>
            <Text style={styles.label}>Exercise Name *</Text>
            <TextInput
              style={styles.textInput}
              placeholder="e.g., Bulgarian Split Squat"
              placeholderTextColor="#929bc9"
              value={name}
              onChangeText={setName}
            />

            <Text style={styles.label}>Muscle Group *</Text>
            <View style={styles.chipContainer}>
              {muscleGroups.map((group) => (
                <TouchableOpacity
                  key={group}
                  style={[
                    styles.selectionChip,
                    muscleGroup === group && styles.selectionChipActive,
                  ]}
                  onPress={() => setMuscleGroup(group)}
                >
                  <Text
                    style={[
                      styles.selectionChipText,
                      muscleGroup === group && styles.selectionChipTextActive,
                    ]}
                  >
                    {group}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text style={styles.label}>Equipment Type</Text>
            <View style={styles.chipContainer}>
              {equipmentTypes.map((type) => (
                <TouchableOpacity
                  key={type}
                  style={[
                    styles.selectionChip,
                    equipmentType === type && styles.selectionChipActive,
                  ]}
                  onPress={() => setEquipmentType(type)}
                >
                  <Text
                    style={[
                      styles.selectionChipText,
                      equipmentType === type && styles.selectionChipTextActive,
                    ]}
                  >
                    {type}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text style={styles.label}>Description (optional)</Text>
            <TextInput
              style={[styles.textInput, styles.textArea]}
              placeholder="How to perform this exercise..."
              placeholderTextColor="#929bc9"
              value={description}
              onChangeText={setDescription}
              multiline
              numberOfLines={4}
            />

            <TouchableOpacity style={styles.createButton} onPress={handleCreate}>
              <Text style={styles.createButtonText}>Create Exercise</Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
};

const ExerciseHistoryModal = ({ visible, exercise, onClose }) => {
  const { getExerciseHistory } = useExercise();
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (visible && exercise) {
      loadHistory();
    }
  }, [visible, exercise]);

  const loadHistory = async () => {
    setLoading(true);
    try {
      const data = await getExerciseHistory(exercise.id);
      setHistory(data);
    } catch (error) {
      Alert.alert('Error', 'Failed to load exercise history');
    } finally {
      setLoading(false);
    }
  };

  if (!exercise) return null;

  return (
    <Modal visible={visible} animationType="slide" transparent={true}>
      <View style={styles.modalContainer}>
        <View style={styles.modalContent}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>{exercise.name} History</Text>
            <TouchableOpacity onPress={onClose}>
              <MaterialCommunityIcons name="close" size={24} color="white" />
            </TouchableOpacity>
          </View>

          {loading ? (
            <Text style={styles.loadingText}>Loading...</Text>
          ) : history.length === 0 ? (
            <View style={styles.emptyState}>
              <Text style={styles.emptyText}>No history yet</Text>
              <Text style={styles.emptySubtext}>
                You haven't performed this exercise yet
              </Text>
            </View>
          ) : (
            <ScrollView>
              {history.map((entry, index) => (
                <View key={index} style={styles.historyEntry}>
                  <Text style={styles.historyDate}>
                    {new Date(entry.date).toLocaleDateString()}
                  </Text>
                  <Text style={styles.historyWorkout}>{entry.workout_name}</Text>
                  <Text style={styles.historyDetails}>
                    Set {entry.set_number}: {entry.weight_lbs} lbs × {entry.reps} reps
                  </Text>
                </View>
              ))}
            </ScrollView>
          )}
        </View>
      </View>
    </Modal>
  );
};

const ExerciseLibraryScreen = () => {
  const {
    exercises,
    muscleGroups,
    loading,
    searchQuery,
    selectedMuscleGroup,
    searchExercises,
    filterByMuscleGroup,
    createCustomExercise,
  } = useExercise();

  const [showAddModal, setShowAddModal] = useState(false);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [selectedExercise, setSelectedExercise] = useState(null);

  const handleCreateExercise = async (exerciseData) => {
    try {
      await createCustomExercise(exerciseData);
      setShowAddModal(false);
      Alert.alert('Success', 'Custom exercise created!');
    } catch (error) {
      Alert.alert('Error', 'Failed to create exercise. Exercise might already exist.');
    }
  };

  const handleExercisePress = (exercise) => {
    Alert.alert(
      exercise.name,
      `Muscle Group: ${exercise.muscle_group}\nEquipment: ${exercise.equipment_type || 'Bodyweight'}${
        exercise.description ? `\n\n${exercise.description}` : ''
      }`,
      [
        { text: 'OK' },
        { text: 'View History', onPress: () => handleShowHistory(exercise) },
      ]
    );
  };

  const handleShowHistory = (exercise) => {
    setSelectedExercise(exercise);
    setShowHistoryModal(true);
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Exercise Library</Text>
        <TouchableOpacity onPress={() => setShowAddModal(true)}>
          <MaterialCommunityIcons name="plus" size={24} color="#1337ec" />
        </TouchableOpacity>
      </View>

      <View style={styles.searchBarContainer}>
        <MaterialCommunityIcons name="magnify" size={24} color="#929bc9" />
        <TextInput
          style={styles.searchInput}
          placeholder="Search exercises..."
          placeholderTextColor="#929bc9"
          value={searchQuery}
          onChangeText={searchExercises}
        />
        {searchQuery !== '' && (
          <TouchableOpacity onPress={() => searchExercises('')}>
            <MaterialCommunityIcons name="close" size={20} color="#929bc9" />
          </TouchableOpacity>
        )}
      </View>

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.filtersContainer}
      >
        <TouchableOpacity
          style={[styles.filterChip, !selectedMuscleGroup && styles.activeFilter]}
          onPress={() => filterByMuscleGroup(null)}
        >
          <Text
            style={[styles.filterText, !selectedMuscleGroup && styles.activeFilterText]}
          >
            All
          </Text>
        </TouchableOpacity>
        {muscleGroups.map((group) => (
          <TouchableOpacity
            key={group}
            style={[
              styles.filterChip,
              selectedMuscleGroup === group && styles.activeFilter,
            ]}
            onPress={() => filterByMuscleGroup(group)}
          >
            <Text
              style={[
                styles.filterText,
                selectedMuscleGroup === group && styles.activeFilterText,
              ]}
            >
              {group}
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      <ScrollView style={styles.exerciseList}>
        {loading ? (
          <Text style={styles.loadingText}>Loading exercises...</Text>
        ) : exercises.length === 0 ? (
          <View style={styles.emptyState}>
            <MaterialCommunityIcons name="dumbbell" size={64} color="#929bc9" />
            <Text style={styles.emptyText}>No exercises found</Text>
            <Text style={styles.emptySubtext}>
              Try adjusting your search or filters
            </Text>
          </View>
        ) : (
          exercises.map((exercise) => (
            <ExerciseListItem
              key={exercise.id}
              exercise={exercise}
              onPress={handleExercisePress}
              onHistory={handleShowHistory}
            />
          ))
        )}
      </ScrollView>

      <AddExerciseModal
        visible={showAddModal}
        onClose={() => setShowAddModal(false)}
        onCreate={handleCreateExercise}
      />

      <ExerciseHistoryModal
        visible={showHistoryModal}
        exercise={selectedExercise}
        onClose={() => {
          setShowHistoryModal(false);
          setSelectedExercise(null);
        }}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#101322',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    paddingTop: 40,
  },
  headerTitle: {
    color: 'white',
    fontSize: 24,
    fontWeight: 'bold',
  },
  searchBarContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1e2338',
    borderRadius: 10,
    paddingHorizontal: 15,
    marginHorizontal: 20,
    marginBottom: 10,
  },
  searchInput: {
    color: 'white',
    flex: 1,
    paddingVertical: 10,
    marginLeft: 10,
  },
  filtersContainer: {
    paddingHorizontal: 20,
    marginBottom: 10,
    flexDirection: 'row',
  },
  filterChip: {
    backgroundColor: '#232948',
    borderRadius: 20,
    paddingVertical: 8,
    paddingHorizontal: 15,
    marginRight: 10,
  },
  activeFilter: {
    backgroundColor: '#1337ec',
  },
  filterText: {
    color: '#929bc9',
  },
  activeFilterText: {
    color: 'white',
    fontWeight: 'bold',
  },
  exerciseList: {
    paddingHorizontal: 20,
  },
  exerciseItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1e2338',
    borderRadius: 10,
    padding: 10,
    marginBottom: 10,
  },
  exerciseImage: {
    width: 60,
    height: 60,
    marginRight: 15,
  },
  imageOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.3)',
    borderRadius: 10,
  },
  exerciseInfo: {
    flex: 1,
  },
  exerciseName: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
  },
  exerciseDetails: {
    color: '#929bc9',
    fontSize: 12,
    marginTop: 2,
  },
  customBadge: {
    color: '#1337ec',
    fontSize: 10,
    marginTop: 4,
    fontWeight: 'bold',
  },
  loadingText: {
    color: '#929bc9',
    textAlign: 'center',
    marginTop: 40,
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
    textAlign: 'center',
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
    maxHeight: '90%',
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
  label: {
    color: 'white',
    fontSize: 14,
    fontWeight: 'bold',
    marginTop: 15,
    marginBottom: 10,
  },
  textInput: {
    backgroundColor: '#2a2f4c',
    color: 'white',
    padding: 12,
    borderRadius: 10,
    marginBottom: 10,
  },
  textArea: {
    height: 100,
    textAlignVertical: 'top',
  },
  chipContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: 10,
  },
  selectionChip: {
    backgroundColor: '#2a2f4c',
    paddingVertical: 8,
    paddingHorizontal: 15,
    borderRadius: 20,
    marginRight: 10,
    marginBottom: 10,
  },
  selectionChipActive: {
    backgroundColor: '#1337ec',
  },
  selectionChipText: {
    color: '#929bc9',
  },
  selectionChipTextActive: {
    color: 'white',
    fontWeight: 'bold',
  },
  createButton: {
    backgroundColor: '#1337ec',
    padding: 15,
    borderRadius: 10,
    alignItems: 'center',
    marginTop: 20,
  },
  createButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
  },
  historyEntry: {
    backgroundColor: '#2a2f4c',
    padding: 15,
    borderRadius: 10,
    marginBottom: 10,
  },
  historyDate: {
    color: '#1337ec',
    fontSize: 12,
    fontWeight: 'bold',
  },
  historyWorkout: {
    color: 'white',
    fontSize: 14,
    marginTop: 5,
  },
  historyDetails: {
    color: '#929bc9',
    fontSize: 12,
    marginTop: 5,
  },
});

export default ExerciseLibraryScreen;
