import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, TextInput, ImageBackground } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const ExerciseListItem = ({ name, muscleGroup, equipment, imageUri }) => (
  <TouchableOpacity style={styles.exerciseItem}>
    <ImageBackground
      source={{ uri: imageUri }}
      style={styles.exerciseImage}
      imageStyle={{ borderRadius: 10 }}
    >
      <View style={styles.imageOverlay} />
    </ImageBackground>
    <View style={styles.exerciseInfo}>
      <Text style={styles.exerciseName}>{name}</Text>
      <Text style={styles.exerciseDetails}>{muscleGroup} • {equipment}</Text>
    </View>
    <MaterialCommunityIcons name="chevron-right" size={24} color="#929bc9" />
  </TouchableOpacity>
);

const ExerciseLibraryScreen = () => {
  const exercises = [
    { name: 'Barbell Bench Press', muscleGroup: 'Chest', equipment: 'Barbell', imageUri: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDW1ViXCWmWMrIEC4zP3cxuhFj6A2JT85BPbOatPo1Qx2PKxmQwhJ90LcgM-f04CDZ5hL8cN5lvyTW0owqUk1jfNtGzE8Lqs5M_VzdEbeycg7bJsa6N4X4kYQn7dYBKRHsIAyCQXqy5DoEhbyxKG6ILhxWdCBbfnZE4W9pyIqEnOCz41-iTuD461ytjHmq1J10Blh--rltE9CXOxNQauo_2fwp4Tq2fTowB0gIuUXtj88o8LZEuiIG23iFQPMDm-7bZ98aJI4H767sQ' },
    { name: 'Back Squat', muscleGroup: 'Legs', equipment: 'Barbell', imageUri: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA-PmSwKXhxjbOEzCzx4fFBvwECmHViqlQlDgusyUvR9wx0JVo7EYiTLwWgyJpJDO15OTt_PalLp_ZM_ja6jE4gK_1i_KprFt8vujwNqjrQ01mb4gu1TsPIC5l4rRXeVM1ddYRxVVjVDfSVrQ71t7g6WfnQkdmZEH8eJo-5VEqS3BUjaDBg3XkBIQQHV35vaoW7ubjYOPBX4wScuPvwrWnn-Gl6bfnvZNGkBUCZ6G1SaXLtZ0E9CYyKr9ycB_YMV1Ozt5rwd3rMvaM4' },
    { name: 'Seated Bicep Curl', muscleGroup: 'Arms', equipment: 'Dumbbells', imageUri: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAh4bVyl1OW58VAf6vbDK0fHf4mB_fyFn2CTOmMfZjuuFeMvc6WZwH2XrseoOD2Dz22BUou_rqRAFFWhKMUNO1EommWELlOx1FfhACvhikesctV96HBtkrSoZiVrmsnFWLEUAIbVH6EjOWoIM2aG9R3vBmtEHHzrnQkHv4fhgbxS9dGpOlqODe8PFEd12pAKz463jyXc2L64HP2PJyGybbBjHp7GuldzdstVB49TekBvLQoyvTHmS3T3CKbLbxeNYqx6tWHcva2q50_' },
  ];

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Exercise Library</Text>
        <TouchableOpacity>
          <MaterialCommunityIcons name="plus" size={24} color="#1337ec" />
        </TouchableOpacity>
      </View>
      <View style={styles.searchBarContainer}>
        <MaterialCommunityIcons name="magnify" size={24} color="#929bc9" />
        <TextInput style={styles.searchInput} placeholder="Search exercises..." placeholderTextColor="#929bc9" />
      </View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.filtersContainer}>
        <TouchableOpacity style={[styles.filterChip, styles.activeFilter]}>
          <Text style={[styles.filterText, styles.activeFilterText]}>All</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.filterChip}>
          <Text style={styles.filterText}>Chest</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.filterChip}>
          <Text style={styles.filterText}>Back</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.filterChip}>
          <Text style={styles.filterText}>Legs</Text>
        </TouchableOpacity>
      </ScrollView>
      <ScrollView style={styles.exerciseList}>
        {exercises.map((exercise, index) => (
          <ExerciseListItem key={index} {...exercise} />
        ))}
      </ScrollView>
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
    },
});

export default ExerciseLibraryScreen;
