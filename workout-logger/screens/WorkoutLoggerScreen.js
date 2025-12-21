import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, TextInput } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const ExerciseCard = ({ exerciseName, exerciseType, sets }) => {
  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <View style={styles.cardHeaderText}>
          <Text style={styles.cardTitle}>{exerciseName}</Text>
          <Text style={styles.cardSubtitle}>{exerciseType}</Text>
        </View>
        <TouchableOpacity>
          <MaterialCommunityIcons name="dots-horizontal" size={24} color="#929bc9" />
        </TouchableOpacity>
      </View>
      <View style={styles.setsContainer}>
        <View style={styles.setsHeader}>
          <Text style={styles.setHeaderText}>Set</Text>
          <Text style={styles.setHeaderText}>Lbs</Text>
          <Text style={styles.setHeaderText}>Reps</Text>
          <MaterialCommunityIcons name="check" size={18} color="#929bc9" />
        </View>
        {sets.map((set, index) => (
          <View key={index} style={styles.setRow}>
            <Text style={styles.setText}>{index + 1}</Text>
            <TextInput style={styles.input} defaultValue={set.lbs} keyboardType="numeric" />
            <TextInput style={styles.input} defaultValue={set.reps} keyboardType="numeric" />
            <TouchableOpacity style={styles.checkbox} />
          </View>
        ))}
      </View>
      <TouchableOpacity style={styles.addSetButton}>
        <Text style={styles.addSetButtonText}>Add Set</Text>
      </TouchableOpacity>
    </View>
  );
};

const WorkoutLoggerScreen = () => {
  const exercises = [
    {
      exerciseName: 'Squats',
      exerciseType: 'Barbell • Legs',
      sets: [{ lbs: '135', reps: '10' }, { lbs: '185', reps: '8' }, { lbs: '', reps: '' }],
    },
    {
      exerciseName: 'Leg Extensions',
      exerciseType: 'Machine • Legs',
      sets: [{ lbs: '', reps: '' }],
    },
  ];

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity>
          <MaterialCommunityIcons name="arrow-left" size={24} color="white" />
        </TouchableOpacity>
        <View style={styles.headerTitleContainer}>
            <Text style={styles.headerTitle}>Leg Day - Morning</Text>
            <Text style={styles.headerSubtitle}>00:45:12 | 12,450 lbs</Text>
        </View>
        <TouchableOpacity style={styles.finishButton}>
          <Text style={styles.finishButtonText}>Finish</Text>
        </TouchableOpacity>
      </View>
      <ScrollView style={styles.scrollContainer}>
        {exercises.map((exercise, index) => (
          <ExerciseCard key={index} {...exercise} />
        ))}
      </ScrollView>
      <TouchableOpacity style={styles.fab}>
        <MaterialCommunityIcons name="plus" size={24} color="white" />
        <Text style={styles.fabText}>Add Exercise</Text>
      </TouchableOpacity>
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
      fontWeight: 'bold',
      flex: 1,
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
      fontSize: 16,
      fontWeight: 'bold',
    },
    input: {
      backgroundColor: '#2a2f4c',
      color: 'white',
      padding: 10,
      borderRadius: 5,
      flex: 1,
      marginHorizontal: 5,
      textAlign: 'center',
      fontSize: 16,
    },
    checkbox: {
      width: 24,
      height: 24,
      borderRadius: 5,
      borderWidth: 2,
      borderColor: '#929bc9',
    },
    addSetButton: {
      backgroundColor: '#2a2f4c',
      padding: 15,
      borderBottomLeftRadius: 10,
      borderBottomRightRadius: 10,
      alignItems: 'center',
    },
    addSetButtonText: {
      color: '#1337ec',
      fontWeight: 'bold',
    },
    fab: {
      position: 'absolute',
      bottom: 30,
      right: 30,
      backgroundColor: '#1337ec',
      borderRadius: 30,
      paddingVertical: 15,
      paddingHorizontal: 20,
      flexDirection: 'row',
      alignItems: 'center',
      elevation: 5,
    },
    fabText: {
      color: 'white',
      fontWeight: 'bold',
      marginLeft: 10,
    },
  });


export default WorkoutLoggerScreen;
