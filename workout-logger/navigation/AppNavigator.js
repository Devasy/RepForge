import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { MaterialCommunityIcons } from '@expo/vector-icons';

import OnboardingScreen from '../screens/OnboardingScreen';
import WorkoutHistoryScreen from '../screens/WorkoutHistoryScreen';
import WorkoutLoggerScreen from '../screens/WorkoutLoggerScreen';
import ProfileScreen from '../screens/ProfileScreen';
import ProgressDashboardScreen from '../screens/ProgressDashboardScreen';
import ExerciseLibraryScreen from '../screens/ExerciseLibraryScreen';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

const MainTabs = () => {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ color, size }) => {
          let iconName;
          if (route.name === 'History') {
            iconName = 'history';
          } else if (route.name === 'Log') {
            iconName = 'plus-box-outline';
          } else if (route.name === 'Profile') {
            iconName = 'account-circle-outline';
          } else if (route.name === 'Progress') {
            iconName = 'chart-line';
          } else if (route.name === 'Library') {
            iconName = 'dumbbell';
          }
          return <MaterialCommunityIcons name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#1337ec',
        tabBarInactiveTintColor: 'gray',
        tabBarStyle: { backgroundColor: '#101322' },
        headerShown: false,
      })}
    >
      <Tab.Screen name="History" component={WorkoutHistoryScreen} />
      <Tab.Screen name="Log" component={WorkoutLoggerScreen} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
      <Tab.Screen name="Progress" component={ProgressDashboardScreen} />
      <Tab.Screen name="Library" component={ExerciseLibraryScreen} />
    </Tab.Navigator>
  );
};

const AppNavigator = () => {
  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        <Stack.Screen name="Onboarding" component={OnboardingScreen} />
        <Stack.Screen name="Main" component={MainTabs} />
      </Stack.Navigator>
    </NavigationContainer>
  );
};

export default AppNavigator;
