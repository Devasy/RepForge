import React, { useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import AppNavigator from './navigation/AppNavigator';
import DatabaseService from './services/database';
import { WorkoutProvider } from './contexts/WorkoutContext';
import { ExerciseProvider } from './contexts/ExerciseContext';
import { HistoryProvider } from './contexts/HistoryContext';

export default function App() {
  const [isDbReady, setIsDbReady] = useState(false);

  useEffect(() => {
    async function initializeApp() {
      try {
        await DatabaseService.init();
        setIsDbReady(true);
      } catch (error) {
        console.error('Failed to initialize database:', error);
      }
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
