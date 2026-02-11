import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // TODO: Replace with your Railway URL
  static const String _baseUrl = 'http://10.0.2.2:8000'; // For Android Emulator
  // static const String _baseUrl = 'http://localhost:8000'; // For iOS Simulator

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<void> reportUsage(Map<String, dynamic> stats) async {
    try {
      // Map Dart camelCase stats to Python snake_case model
      final payload = {
        'total_workouts': stats['totalWorkouts'],
        'weekly_workouts': stats['weeklyWorkouts'],
        'weekly_volume': stats['weeklyVolume'],
        'exercises_this_week': stats['exercisesThisWeek'],
        'report_date': DateTime.now().toIso8601String(),
      };

      final response = await _client.post(
        Uri.parse('$_baseUrl/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to report usage: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error reporting usage: $e');
    }
  }

  Future<bool> backupData(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/backup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('Failed to backup data: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error backing up data: $e');
      return false;
    }
  }
}
