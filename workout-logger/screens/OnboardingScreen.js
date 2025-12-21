import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ImageBackground } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const OnboardingScreen = ({ navigation }) => {
  return (
    <ImageBackground
      source={{ uri: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAEswCxSf-JJ1yR7YRmVWvssXp-66zFbVD23WU_zLaeaqIbvnqRar1VktXTMnvH1S4NiGiDzrJhA-gl8Hxlvmi13vtXwyK52cBN1Xlvg7AZzxgJ7UZrldP2BKjzUQc9ley2qf1YfTvEgIbr2d3YmptjEYSdJmfeyieenYxsyBKylK4Es5qeHPH5t-iWlkteQ33rnfiZBmR5v-JOD75WI-1bzXUpMW5Th5NKMBAeIrMAZiRnPS0fcUKzKG4bACtkZRfwzNp8Hn_PLuah' }}
      style={styles.background}
    >
      <View style={styles.container}>
        <TouchableOpacity style={styles.skipButton} onPress={() => navigation.navigate('Main')}>
          <Text style={styles.skipText}>Skip</Text>
        </TouchableOpacity>
        <View style={styles.content}>
          <Text style={styles.title}>
            Track Every <Text style={styles.highlight}>Rep</Text>
          </Text>
          <Text style={styles.subtitle}>
            Effortlessly log your workouts and keep your entire history in one secure place.
          </Text>
        </View>
        <View style={styles.footer}>
          <View style={styles.indicators}>
            <View style={[styles.indicator, styles.activeIndicator]} />
            <View style={styles.indicator} />
            <View style={styles.indicator} />
          </View>
          <TouchableOpacity style={styles.getStartedButton} onPress={() => navigation.navigate('Main')}>
            <Text style={styles.getStartedButtonText}>Get Started</Text>
            <MaterialCommunityIcons name="arrow-right" size={20} color="white" />
          </TouchableOpacity>
          <TouchableOpacity onPress={() => navigation.navigate('Main')}>
            <Text style={styles.loginText}>
              Already have an account? <Text style={styles.loginLink}>Log in</Text>
            </Text>
          </TouchableOpacity>
        </View>
      </View>
    </ImageBackground>
  );
};

const styles = StyleSheet.create({
  background: {
    flex: 1,
    justifyContent: 'center',
  },
  container: {
    flex: 1,
    padding: 20,
    justifyContent: 'space-between',
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  skipButton: {
    alignSelf: 'flex-end',
  },
  skipText: {
    color: '#929bc9',
    fontSize: 16,
    fontWeight: 'bold',
  },
  content: {
    alignItems: 'center',
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: 'white',
    textAlign: 'center',
  },
  highlight: {
    color: '#1337ec',
  },
  subtitle: {
    fontSize: 16,
    color: '#929bc9',
    textAlign: 'center',
    marginTop: 10,
  },
  footer: {
    alignItems: 'center',
  },
  indicators: {
    flexDirection: 'row',
    marginBottom: 20,
  },
  indicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#323b67',
    marginHorizontal: 5,
  },
  activeIndicator: {
    backgroundColor: '#1337ec',
    width: 20,
  },
  getStartedButton: {
    backgroundColor: '#1337ec',
    paddingVertical: 15,
    paddingHorizontal: 30,
    borderRadius: 10,
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
    justifyContent: 'center',
  },
  getStartedButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
    marginRight: 10,
  },
  loginText: {
    color: '#929bc9',
    marginTop: 20,
  },
  loginLink: {
    color: '#1337ec',
    fontWeight: 'bold',
  },
});

export default OnboardingScreen;
