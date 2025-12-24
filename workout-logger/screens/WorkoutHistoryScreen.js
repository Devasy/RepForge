import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  Alert
} from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useHistory } from '../contexts/HistoryContext';
import { useWorkout } from '../contexts/WorkoutContext';

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

const WorkoutCard = ({ workout, onPress, onDelete }) => {
  const date = new Date(workout.date);
  const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  const formatDuration = (seconds) => {
    if (!seconds) return '0m';
    const mins = Math.floor(seconds / 60);
    const hrs = Math.floor(mins / 60);
    if (hrs > 0) return `${hrs}h ${mins % 60}m`;
    return `${mins}m`;
  };

  return (
    <TouchableOpacity
      style={styles.workoutCard}
      onPress={onPress}
      onLongPress={() => {
        Alert.alert(
          'Delete Workout',
          'Are you sure you want to delete this workout?',
          [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Delete', style: 'destructive', onPress: onDelete },
          ]
        );
      }}
    >
      <View style={styles.workoutCardHeader}>
        <View style={styles.datePill}>
          <Text style={styles.dateMonth}>{monthNames[date.getMonth()]}</Text>
          <Text style={styles.dateDay}>{date.getDate()}</Text>
        </View>
        <View style={styles.workoutInfo}>
          <Text style={styles.workoutTitle}>{workout.name}</Text>
          <Text style={styles.workoutSubtitle}>
            {formatDuration(workout.duration_seconds)} | {' '}
            {Math.round(workout.total_volume || 0).toLocaleString()} lbs | {' '}
            {workout.exercise_count || 0} exercises
          </Text>
        </View>
        <MaterialCommunityIcons name="chevron-right" size={24} color="#929bc9" />
      </View>
    </TouchableOpacity>
  );
};

const WorkoutHistoryScreen = ({ navigation }) => {
  const { workouts, stats, loading, loadWorkouts, loadStats, deleteWorkout } = useHistory();
  const { loadWorkout } = useWorkout();
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadWorkouts();
    loadStats();
  }, []);

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadWorkouts();
    await loadStats();
    setRefreshing(false);
  };

  const handleWorkoutPress = async (workoutId) => {
    try {
      const workout = await loadWorkout(workoutId);
      // Navigate to a workout detail screen (we'll create this later)
      // For now, just show an alert with workout details
      Alert.alert(
        workout.name,
        `Date: ${workout.date}\nExercises: ${workout.exercises.length}\nDuration: ${Math.floor(workout.duration_seconds / 60)} mins`
      );
    } catch (error) {
      Alert.alert('Error', 'Failed to load workout details');
    }
  };

  const handleDeleteWorkout = async (workoutId) => {
    try {
      await deleteWorkout(workoutId);
      Alert.alert('Success', 'Workout deleted');
    } catch (error) {
      Alert.alert('Error', 'Failed to delete workout');
    }
  };

  // Group workouts by month
  const groupedWorkouts = workouts.reduce((groups, workout) => {
    const date = new Date(workout.date);
    const monthYear = `${date.toLocaleString('default', { month: 'long' })} ${date.getFullYear()}`;

    if (!groups[monthYear]) {
      groups[monthYear] = [];
    }
    groups[monthYear].push(workout);
    return groups;
  }, {});

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>History</Text>
        <View style={styles.headerIcons}>
          <TouchableOpacity onPress={handleRefresh}>
            <MaterialCommunityIcons name="refresh" size={24} color="white" />
          </TouchableOpacity>
        </View>
      </View>

      <ScrollView
        style={styles.scrollContainer}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} tintColor="#1337ec" />
        }
      >
        <View style={styles.statsSection}>
          <StatCard
            icon="dumbbell"
            title="Total Workouts"
            value={stats.totalWorkouts?.toString() || '0'}
          />
          <StatCard
            icon="fire"
            title="Current Streak"
            value={`${stats.currentStreak || 0} days`}
          />
        </View>

        {workouts.length === 0 ? (
          <View style={styles.emptyState}>
            <MaterialCommunityIcons name="history" size={64} color="#929bc9" />
            <Text style={styles.emptyText}>No workout history yet</Text>
            <Text style={styles.emptySubtext}>Complete your first workout to see it here!</Text>
          </View>
        ) : (
          Object.entries(groupedWorkouts).map(([monthYear, monthWorkouts]) => (
            <View key={monthYear} style={styles.timelineSection}>
              <Text style={styles.timelineTitle}>{monthYear}</Text>
              {monthWorkouts.map((workout) => (
                <WorkoutCard
                  key={workout.id}
                  workout={workout}
                  onPress={() => handleWorkoutPress(workout.id)}
                  onDelete={() => handleDeleteWorkout(workout.id)}
                />
              ))}
            </View>
          ))
        )}
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
    fontSize: 12,
  },
  statCardValue: {
    color: 'white',
    fontSize: 24,
    fontWeight: 'bold',
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
  timelineSection: {
    marginBottom: 30,
  },
  timelineTitle: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 15,
  },
  workoutCard: {
    backgroundColor: '#1c2136',
    borderRadius: 10,
    marginBottom: 15,
    overflow: 'hidden',
  },
  workoutCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 15,
  },
  datePill: {
    backgroundColor: '#1337ec',
    borderRadius: 10,
    width: 50,
    height: 50,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 15,
  },
  dateMonth: {
    color: 'white',
    fontSize: 10,
    fontWeight: 'bold',
    textTransform: 'uppercase',
  },
  dateDay: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  workoutInfo: {
    flex: 1,
  },
  workoutTitle: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  workoutSubtitle: {
    color: '#929bc9',
    fontSize: 12,
  },
});

export default WorkoutHistoryScreen;
