import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const MetricCard = ({ icon, title, value, change }) => (
  <View style={styles.metricCard}>
    <View style={styles.metricHeader}>
      <MaterialCommunityIcons name={icon} size={24} color="#1337ec" />
      <Text style={styles.metricTitle}>{title}</Text>
    </View>
    <Text style={styles.metricValue}>{value}</Text>
    <Text style={styles.metricChange}>{change}</Text>
  </View>
);

const ProgressBar = ({ label, percentage, color }) => (
  <View style={styles.progressContainer}>
    <View style={styles.progressLabels}>
      <Text style={styles.progressLabel}>{label}</Text>
      <Text style={styles.progressPercentage}>{percentage}%</Text>
    </View>
    <View style={styles.progressBarBackground}>
      <View style={[styles.progressBarFill, { width: `${percentage}%`, backgroundColor: color }]} />
    </View>
  </View>
);

const ProgressDashboardScreen = () => {
  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Progress Dashboard</Text>
      </View>
      <View style={styles.content}>
        <View style={styles.metricsGrid}>
          <MetricCard icon="fire" title="Streak" value="12" change="+2 days" />
          <MetricCard icon="dumbbell" title="Volume" value="45k" change="+5% lbs" />
        </View>

        <View style={styles.chartContainer}>
          <Text style={styles.sectionTitle}>Strength Gains</Text>
          <View style={styles.chartPlaceholder}>
            <Text style={styles.chartText}>Strength Gains Chart</Text>
          </View>
        </View>

        <View style={styles.muscleSplitContainer}>
          <Text style={styles.sectionTitle}>Muscle Split</Text>
          <ProgressBar label="Push (Chest, Shoulders, Triceps)" percentage={45} color="#1337ec" />
          <ProgressBar label="Pull (Back, Biceps)" percentage={30} color="#6a1b9a" />
          <ProgressBar label="Legs (Quads, Hams, Calves)" percentage={25} color="#0288d1" />
        </View>

        <View style={styles.frequencyContainer}>
          <Text style={styles.sectionTitle}>Frequency</Text>
          <View style={styles.chartPlaceholder}>
            <Text style={styles.chartText}>Workout Frequency Chart</Text>
          </View>
        </View>

        <View style={styles.coachTipContainer}>
            <MaterialCommunityIcons name="lightbulb-on-outline" size={24} color="#f9a825" />
            <View style={styles.coachTipTextContainer}>
                <Text style={styles.coachTipTitle}>Coach's Tip</Text>
                <Text style={styles.coachTipText}>Your chest volume is significantly higher than last week. Consider a lighter session next time to optimize recovery.</Text>
            </View>
        </View>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#101322',
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
    },
    metricValue: {
        color: 'white',
        fontSize: 24,
        fontWeight: 'bold',
    },
    metricChange: {
        color: '#4caf50',
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
    chartPlaceholder: {
        backgroundColor: '#1c2136',
        borderRadius: 10,
        height: 150,
        justifyContent: 'center',
        alignItems: 'center',
    },
    chartText: {
        color: '#929bc9',
    },
    muscleSplitContainer: {
        marginBottom: 30,
    },
    progressContainer: {
        marginBottom: 15,
    },
    progressLabels: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        marginBottom: 5,
    },
    progressLabel: {
        color: 'white',
    },
    progressPercentage: {
        color: '#929bc9',
    },
    progressBarBackground: {
        backgroundColor: '#2a2f4c',
        height: 10,
        borderRadius: 5,
    },
    progressBarFill: {
        height: 10,
        borderRadius: 5,
    },
    frequencyContainer: {
        marginBottom: 30,
    },
    coachTipContainer: {
        backgroundColor: '#1c2136',
        borderRadius: 10,
        padding: 15,
        flexDirection: 'row',
    },
    coachTipTextContainer: {
        marginLeft: 15,
        flex: 1,
    },
    coachTipTitle: {
        color: '#f9a825',
        fontWeight: 'bold',
    },
    coachTipText: {
        color: '#929bc9',
        marginTop: 5,
    },
});

export default ProgressDashboardScreen;
