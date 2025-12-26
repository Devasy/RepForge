import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Dimensions,
  ActivityIndicator
} from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LineChart, BarChart } from 'react-native-chart-kit';
import { useHistory } from '../contexts/HistoryContext';
import AnalyticsRepository from '../repositories/AnalyticsRepository';

const screenWidth = Dimensions.get('window').width;

const MetricCard = ({ icon, title, value, change }) => (
  <View style={styles.metricCard}>
    <View style={styles.metricHeader}>
      <MaterialCommunityIcons name={icon} size={24} color="#1337ec" />
      <Text style={styles.metricTitle}>{title}</Text>
    </View>
    <Text style={styles.metricValue}>{value}</Text>
    {change && <Text style={styles.metricChange}>{change}</Text>}
  </View>
);

const ProgressBar = ({ label, percentage, color, volume }) => (
  <View style={styles.progressContainer}>
    <View style={styles.progressLabels}>
      <Text style={styles.progressLabel}>{label}</Text>
      <View style={styles.progressRight}>
        <Text style={styles.progressVolume}>{volume} lbs</Text>
        <Text style={styles.progressPercentage}>{percentage}%</Text>
      </View>
    </View>
    <View style={styles.progressBarBackground}>
      <View
        style={[
          styles.progressBarFill,
          { width: `${percentage}%`, backgroundColor: color }
        ]}
      />
    </View>
  </View>
);

const ProgressDashboardScreen = () => {
  const { stats, getVolumeByMuscleGroup, getWorkoutFrequency } = useHistory();
  const [loading, setLoading] = useState(true);
  const [volumeData, setVolumeData] = useState([]);
  const [frequencyData, setFrequencyData] = useState([]);
  const [strengthData, setStrengthData] = useState([]);
  const [recommendations, setRecommendations] = useState([]);

  useEffect(() => {
    loadAnalytics();
  }, []);

  const loadAnalytics = async () => {
    setLoading(true);
    try {
      // Get volume by muscle group (last 30 days)
      const endDate = new Date().toISOString().split('T')[0];
      const startDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
        .toISOString()
        .split('T')[0];

      const volume = await getVolumeByMuscleGroup(startDate, endDate);
      setVolumeData(volume);

      // Get workout frequency (last 12 weeks)
      const frequency = await getWorkoutFrequency(12);
      setFrequencyData(frequency);

      // Generate recommendations based on data
      generateRecommendations(volume, frequency);

    } catch (error) {
      console.error('Failed to load analytics:', error);
    } finally {
      setLoading(false);
    }
  };

  const generateRecommendations = (volumeData, frequencyData) => {
    const recommendations = [];

    // Calculate total volume
    const totalVolume = volumeData.reduce((sum, item) => sum + item.total_volume, 0);

    // Check for muscle imbalances
    if (volumeData.length > 0) {
      const maxVolume = Math.max(...volumeData.map(v => v.total_volume));
      const imbalanced = volumeData.filter(v => v.total_volume < maxVolume * 0.3);

      if (imbalanced.length > 0) {
        recommendations.push({
          type: 'warning',
          title: 'Muscle Imbalance Detected',
          message: `Your ${imbalanced[0].muscle_group} volume is significantly lower. Consider adding more exercises for this muscle group.`,
        });
      }
    }

    // Check workout consistency
    const recentFrequency = frequencyData.slice(0, 4);
    const avgFrequency = recentFrequency.length > 0
      ? recentFrequency.reduce((sum, item) => sum + item.workout_count, 0) / recentFrequency.length
      : 0;

    if (avgFrequency < 2) {
      recommendations.push({
        type: 'info',
        title: 'Increase Frequency',
        message: `You're averaging ${avgFrequency.toFixed(1)} workouts per week. Aim for 3-5 weekly sessions for optimal progress.`,
      });
    } else if (avgFrequency > 6) {
      recommendations.push({
        type: 'warning',
        title: 'Recovery Warning',
        message: `You're training very frequently. Ensure you're getting adequate rest and recovery.`,
      });
    }

    // Progressive overload recommendation
    recommendations.push({
      type: 'success',
      title: 'Keep Building',
      message: 'Track your weights and reps. Aim to increase volume by 5-10% each week for progressive overload.',
    });

    setRecommendations(recommendations);
  };

  // Calculate percentages for muscle split
  const totalVolume = volumeData.reduce((sum, item) => sum + item.total_volume, 0);
  const musclePercentages = volumeData.map(item => ({
    ...item,
    percentage: totalVolume > 0 ? Math.round((item.total_volume / totalVolume) * 100) : 0,
  }));

  // Chart colors
  const muscleColors = {
    'Chest': '#1337ec',
    'Back': '#6a1b9a',
    'Legs': '#0288d1',
    'Shoulders': '#f57c00',
    'Arms': '#388e3c',
    'Core': '#d32f2f',
    'default': '#929bc9',
  };

  // Prepare frequency chart data
  const frequencyChartData = {
    labels: frequencyData.slice(0, 8).reverse().map(item => {
      const [year, week] = item.week.split('-');
      return `W${week}`;
    }),
    datasets: [
      {
        data: frequencyData.slice(0, 8).reverse().map(item => item.workout_count),
        color: (opacity = 1) => `rgba(19, 55, 236, ${opacity})`,
        strokeWidth: 2,
      },
    ],
  };

  if (loading) {
    return (
      <View style={[styles.container, styles.centerContainer]}>
        <ActivityIndicator size="large" color="#1337ec" />
        <Text style={styles.loadingText}>Loading analytics...</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Progress Dashboard</Text>
      </View>

      <View style={styles.content}>
        <View style={styles.metricsGrid}>
          <MetricCard
            icon="fire"
            title="Streak"
            value={stats.currentStreak || 0}
            change={`${stats.currentStreak > 0 ? '+' : ''}${stats.currentStreak} days`}
          />
          <MetricCard
            icon="dumbbell"
            title="Workouts"
            value={stats.totalWorkouts || 0}
            change="total"
          />
        </View>

        {/* Workout Frequency Chart */}
        {frequencyData.length > 0 && (
          <View style={styles.chartContainer}>
            <Text style={styles.sectionTitle}>Workout Frequency</Text>
            <LineChart
              data={frequencyChartData}
              width={screenWidth - 40}
              height={220}
              chartConfig={{
                backgroundColor: '#1c2136',
                backgroundGradientFrom: '#1c2136',
                backgroundGradientTo: '#1c2136',
                decimalPlaces: 0,
                color: (opacity = 1) => `rgba(19, 55, 236, ${opacity})`,
                labelColor: (opacity = 1) => `rgba(146, 155, 201, ${opacity})`,
                style: {
                  borderRadius: 16,
                },
                propsForDots: {
                  r: '6',
                  strokeWidth: '2',
                  stroke: '#1337ec',
                },
              }}
              bezier
              style={styles.chart}
            />
          </View>
        )}

        {/* Muscle Split */}
        {volumeData.length > 0 && (
          <View style={styles.muscleSplitContainer}>
            <Text style={styles.sectionTitle}>Volume by Muscle Group (30 days)</Text>
            {musclePercentages
              .sort((a, b) => b.total_volume - a.total_volume)
              .map((item) => (
                <ProgressBar
                  key={item.muscle_group}
                  label={item.muscle_group}
                  percentage={item.percentage}
                  color={muscleColors[item.muscle_group] || muscleColors.default}
                  volume={Math.round(item.total_volume).toLocaleString()}
                />
              ))}
          </View>
        )}

        {/* Recommendations */}
        {recommendations.length > 0 && (
          <View style={styles.recommendationsContainer}>
            <Text style={styles.sectionTitle}>Insights & Recommendations</Text>
            {recommendations.map((rec, index) => (
              <View key={index} style={styles.recommendationCard}>
                <MaterialCommunityIcons
                  name={
                    rec.type === 'warning' ? 'alert-circle-outline' :
                    rec.type === 'success' ? 'check-circle-outline' :
                    'lightbulb-on-outline'
                  }
                  size={24}
                  color={
                    rec.type === 'warning' ? '#f9a825' :
                    rec.type === 'success' ? '#4caf50' :
                    '#2196f3'
                  }
                />
                <View style={styles.recommendationTextContainer}>
                  <Text style={styles.recommendationTitle}>{rec.title}</Text>
                  <Text style={styles.recommendationText}>{rec.message}</Text>
                </View>
              </View>
            ))}
          </View>
        )}

        {volumeData.length === 0 && frequencyData.length === 0 && (
          <View style={styles.emptyState}>
            <MaterialCommunityIcons name="chart-line" size={64} color="#929bc9" />
            <Text style={styles.emptyText}>No data yet</Text>
            <Text style={styles.emptySubtext}>
              Complete some workouts to see your progress analytics!
            </Text>
          </View>
        )}
      </View>
    </ScrollView>
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
    padding: 20,
    paddingTop: 40,
    alignItems: 'center',
  },
  headerTitle: {
    color: 'white',
    fontSize: 24,
    fontWeight: 'bold',
  },
  content: {
    padding: 20,
  },
  loadingText: {
    color: '#929bc9',
    marginTop: 10,
  },
  metricsGrid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 30,
  },
  metricCard: {
    backgroundColor: '#1c2136',
    borderRadius: 10,
    padding: 15,
    flex: 1,
    marginHorizontal: 5,
  },
  metricHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 10,
  },
  metricTitle: {
    color: '#929bc9',
    marginLeft: 10,
    fontSize: 12,
  },
  metricValue: {
    color: 'white',
    fontSize: 28,
    fontWeight: 'bold',
  },
  metricChange: {
    color: '#1337ec',
    fontSize: 12,
    marginTop: 5,
  },
  chartContainer: {
    marginBottom: 30,
  },
  sectionTitle: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 15,
  },
  chart: {
    marginVertical: 8,
    borderRadius: 16,
  },
  muscleSplitContainer: {
    marginBottom: 30,
  },
  progressContainer: {
    marginBottom: 20,
  },
  progressLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  progressLabel: {
    color: 'white',
    fontSize: 14,
  },
  progressRight: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  progressVolume: {
    color: '#929bc9',
    fontSize: 12,
    marginRight: 10,
  },
  progressPercentage: {
    color: '#1337ec',
    fontSize: 14,
    fontWeight: 'bold',
  },
  progressBarBackground: {
    height: 10,
    backgroundColor: '#2a2f4c',
    borderRadius: 5,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 5,
  },
  recommendationsContainer: {
    marginBottom: 30,
  },
  recommendationCard: {
    flexDirection: 'row',
    backgroundColor: '#1c2136',
    padding: 15,
    borderRadius: 10,
    marginBottom: 15,
  },
  recommendationTextContainer: {
    flex: 1,
    marginLeft: 15,
  },
  recommendationTitle: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  recommendationText: {
    color: '#929bc9',
    fontSize: 14,
    lineHeight: 20,
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
});

export default ProgressDashboardScreen;
