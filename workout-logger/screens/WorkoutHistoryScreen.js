import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const StatCard = ({ icon, title, value }) => {
  return (
    <View style={styles.statCard}>
      <View style={styles.statCardHeader}>
        <MaterialCommunityIcons name={icon} size={20} color="#1337ec" />
        <Text style={styles.statCardTitle}>{title}</Text>
      </View>
      <Text style={styles.statCardValue}>{value}</Text>
    </View>
  );
};

const WorkoutCard = ({ date, title, duration, weight, tags }) => {
  return (
    <TouchableOpacity style={styles.workoutCard}>
      <View style={styles.workoutCardHeader}>
        <View style={styles.datePill}>
          <Text style={styles.dateMonth}>{date.month}</Text>
          <Text style={styles.dateDay}>{date.day}</Text>
        </View>
        <View style={styles.workoutInfo}>
          <Text style={styles.workoutTitle}>{title}</Text>
          <Text style={styles.workoutSubtitle}>{`${duration} | ${weight}`}</Text>
        </View>
        <MaterialCommunityIcons name="chevron-right" size={24} color="#929bc9" />
      </View>
      <View style={styles.tagsContainer}>
        {tags.map((tag, index) => (
          <View key={index} style={styles.tag}>
            <Text style={styles.tagText}>{tag}</Text>
          </View>
        ))}
      </View>
    </TouchableOpacity>
  );
};

const WorkoutHistoryScreen = () => {
  const workouts = [
    {
      date: { month: 'Oct', day: '24' },
      title: 'Upper Body Power',
      duration: '45m',
      weight: '3,200kg',
      tags: ['Chest', 'Triceps', 'Shoulders'],
    },
    {
      date: { month: 'Oct', day: '22' },
      title: 'Leg Day Destruction',
      duration: '65m',
      weight: '8,450kg',
      tags: ['Quads', 'Hamstrings', 'Calves'],
    },
  ];

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>History</Text>
        <View style={styles.headerIcons}>
          <TouchableOpacity>
            <MaterialCommunityIcons name="magnify" size={24} color="white" />
          </TouchableOpacity>
          <TouchableOpacity>
            <MaterialCommunityIcons name="filter-variant" size={24} color="white" />
          </TouchableOpacity>
        </View>
      </View>
      <ScrollView style={styles.scrollContainer}>
        <View style={styles.statsSection}>
          <StatCard icon="dumbbell" title="Total Workouts" value="42" />
          <StatCard icon="fire" title="Active Streak" value="5 days" />
        </View>
        <View style={styles.timelineSection}>
          <Text style={styles.timelineTitle}>October 2023</Text>
          {workouts.map((workout, index) => (
            <WorkoutCard key={index} {...workout} />
          ))}
        </View>
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
        borderBottomWidth: 1,
        borderBottomColor: '#2a2f4c',
    },
    headerTitle: {
        color: 'white',
        fontSize: 24,
        fontWeight: 'bold',
    },
    headerIcons: {
        flexDirection: 'row',
        gap: 15,
    },
    scrollContainer: {
        flex: 1,
        padding: 20,
    },
    statsSection: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        marginBottom: 30,
    },
    statCard: {
        backgroundColor: '#1c2136',
        borderRadius: 10,
        padding: 15,
        flex: 1,
        marginHorizontal: 5,
    },
    statCardHeader: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 10,
    },
    statCardTitle: {
        color: '#929bc9',
        marginLeft: 10,
    },
    statCardValue: {
        color: 'white',
        fontSize: 24,
        fontWeight: 'bold',
    },
    timelineSection: {},
    timelineTitle: {
        color: 'white',
        fontSize: 18,
        fontWeight: 'bold',
        marginBottom: 15,
    },
    workoutCard: {
        backgroundColor: '#1c2136',
        borderRadius: 10,
        padding: 15,
        marginBottom: 15,
    },
    workoutCardHeader: {
        flexDirection: 'row',
        alignItems: 'center',
        marginBottom: 10,
    },
    datePill: {
        backgroundColor: '#1337ec20',
        borderRadius: 10,
        padding: 10,
        alignItems: 'center',
        marginRight: 15,
    },
    dateMonth: {
        color: '#1337ec',
        fontSize: 10,
        fontWeight: 'bold',
    },
    dateDay: {
        color: '#1337ec',
        fontSize: 20,
        fontWeight: 'bold',
    },
    workoutInfo: {
        flex: 1,
    },
    workoutTitle: {
        color: 'white',
        fontSize: 16,
        fontWeight: 'bold',
    },
    workoutSubtitle: {
        color: '#929bc9',
        fontSize: 12,
    },
    tagsContainer: {
        flexDirection: 'row',
        flexWrap: 'wrap',
        marginTop: 10,
    },
    tag: {
        backgroundColor: '#252b42',
        borderRadius: 5,
        paddingVertical: 5,
        paddingHorizontal: 10,
        marginRight: 10,
        marginBottom: 10,
    },
    tagText: {
        color: '#929bc9',
        fontSize: 12,
    },
});

export default WorkoutHistoryScreen;
