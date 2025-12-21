import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Image, Switch } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const ProfileHeader = () => (
  <View style={styles.profileHeader}>
    <View style={styles.avatarContainer}>
      <Image
        source={{ uri: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAigDPOdLe0TfNpLNo_wfNN9z40UdNN2E95-x-th_Z3ubRERixfQOYc2i9tp2bv820KhiO42r26lmozp591BMdojdF4SfplqfVV3dpGns3MuktJn_d3oLuHHjXodGFBYZWolhEoMTRSui2RVhMpvcrm-GAB0womKndKg5isZjHjcuKjYiGMDyHyuoGMRRD6yW9Tkqag54uceuObjc4TZBBtb57fjAa9FEG9CpDkwnwPuHZHMP8QWFwr1CVc-aJEVrpKn1ohlNJLKf_L' }}
        style={styles.avatar}
      />
      <View style={styles.verifiedBadge}>
        <MaterialCommunityIcons name="check" size={16} color="white" />
      </View>
    </View>
    <Text style={styles.profileName}>John Doe</Text>
    <View style={styles.membershipBadge}>
      <Text style={styles.membershipText}>ELITE MEMBER</Text>
    </View>
    <Text style={styles.joinDate}>Joined Jan 2023</Text>
  </View>
);

const ProfileStats = () => (
  <View style={styles.profileStats}>
    <View style={styles.statItem}>
      <Text style={styles.statValue}>45</Text>
      <Text style={styles.statLabel}>Workouts</Text>
    </View>
    <View style={styles.statItem}>
      <Text style={styles.statValue}>12</Text>
      <Text style={styles.statLabel}>Day Streak</Text>
    </View>
    <View style={styles.statItem}>
      <Text style={styles.statValue}>15k</Text>
      <Text style={styles.statLabel}>Lbs Lifted</Text>
    </View>
  </View>
);

const SettingsItem = ({ icon, label, value, isToggle, onToggle, isDestructive }) => (
  <TouchableOpacity style={styles.settingsItem}>
    <MaterialCommunityIcons name={icon} size={24} color={isDestructive ? '#e53935' : '#1337ec'} style={styles.settingsIcon} />
    <Text style={[styles.settingsLabel, isDestructive && styles.destructiveText]}>{label}</Text>
    <View style={styles.settingsValueContainer}>
      {value && <Text style={styles.settingsValue}>{value}</Text>}
      {isToggle ? (
        <Switch value={true} onValueChange={onToggle} />
      ) : (
        !isDestructive && <MaterialCommunityIcons name="chevron-right" size={24} color="#929bc9" />
      )}
    </View>
  </TouchableOpacity>
);

const ProfileScreen = () => {
  return (
    <ScrollView style={styles.container}>
      <ProfileHeader />
      <ProfileStats />
      <View style={styles.settingsContainer}>
        <Text style={styles.settingsGroupTitle}>Account</Text>
        <View style={styles.settingsGroup}>
          <SettingsItem icon="account-circle-outline" label="Personal Details" />
          <SettingsItem icon="star-circle-outline" label="Subscription" value="Pro" />
        </View>

        <Text style={styles.settingsGroupTitle}>Fitness Goals</Text>
        <View style={styles.settingsGroup}>
          <SettingsItem icon="flag-checkered" label="Weekly Goal" value="4 Days" />
          <SettingsItem icon="chart-line" label="Body Metrics" />
        </View>

        <Text style={styles.settingsGroupTitle}>App Preferences</Text>
        <View style={styles.settingsGroup}>
          <SettingsItem icon="ruler" label="Units" value="Imperial (lbs)" />
          <SettingsItem icon="timer-outline" label="Rest Timer" value="60s" />
          <SettingsItem icon="bell-outline" label="Notifications" isToggle />
        </View>

        <Text style={styles.settingsGroupTitle}>Support & Info</Text>
        <View style={styles.settingsGroup}>
            <SettingsItem icon="help-circle-outline" label="Help Center" />
            <SettingsItem icon="logout" label="Log Out" isDestructive />
        </View>
      </View>
      <Text style={styles.versionText}>Version 1.0.2 (Build 450)</Text>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#101322',
    },
    profileHeader: {
        alignItems: 'center',
        padding: 20,
    },
    avatarContainer: {
        position: 'relative',
        marginBottom: 10,
    },
    avatar: {
        width: 100,
        height: 100,
        borderRadius: 50,
        borderWidth: 4,
        borderColor: '#1c2136',
    },
    verifiedBadge: {
        position: 'absolute',
        bottom: 0,
        right: 0,
        backgroundColor: '#1337ec',
        borderRadius: 15,
        padding: 5,
        borderWidth: 2,
        borderColor: '#101322',
    },
    profileName: {
        color: 'white',
        fontSize: 24,
        fontWeight: 'bold',
    },
    membershipBadge: {
        backgroundColor: '#f9a82520',
        borderRadius: 5,
        paddingVertical: 3,
        paddingHorizontal: 8,
        marginTop: 5,
    },
    membershipText: {
        color: '#f9a825',
        fontSize: 12,
        fontWeight: 'bold',
    },
    joinDate: {
        color: '#929bc9',
        marginTop: 5,
    },
    profileStats: {
        flexDirection: 'row',
        justifyContent: 'space-around',
        padding: 20,
        paddingTop: 0,
    },
    statItem: {
        alignItems: 'center',
    },
    statValue: {
        color: 'white',
        fontSize: 24,
        fontWeight: 'bold',
    },
    statLabel: {
        color: '#929bc9',
        fontSize: 12,
    },
    settingsContainer: {
        paddingHorizontal: 20,
    },
    settingsGroupTitle: {
        color: '#929bc9',
        fontSize: 14,
        fontWeight: 'bold',
        textTransform: 'uppercase',
        marginBottom: 10,
    },
    settingsGroup: {
        backgroundColor: '#1c2136',
        borderRadius: 10,
        marginBottom: 20,
    },
    settingsItem: {
        flexDirection: 'row',
        alignItems: 'center',
        padding: 15,
        borderBottomWidth: 1,
        borderBottomColor: '#2a2f4c',
    },
    settingsIcon: {
        marginRight: 15,
    },
    settingsLabel: {
        color: 'white',
        fontSize: 16,
        flex: 1,
    },
    settingsValueContainer: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    settingsValue: {
        color: '#929bc9',
        marginRight: 10,
    },
    destructiveText: {
        color: '#e53935',
    },
    versionText: {
        color: '#929bc9',
        textAlign: 'center',
        marginBottom: 20,
    },
});

export default ProfileScreen;
