import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

// Conditional import: uses dart:io on native, stub on web.
import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';

/// Singleton service for communicating with the RepForge analytics backend.
class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://workout-logger-production-1e93.up.railway.app',
  );

  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;
  ApiService._internal();

  http.Client _client = http.Client();

  /// Replace the HTTP client for testing only.
  @visibleForTesting
  static void setTestClient(http.Client client) {
    _instance._client = client;
  }

  String? _cachedAppId;

  /// Returns a stable installation ID (UUID v4) persisted in Hive.
  Future<String> get userAppId async {
    if (_cachedAppId != null) return _cachedAppId!;
    // Defensively open the box if it's not already open
    final Box<String> box;
    if (Hive.isBoxOpen('settings')) {
      box = Hive.box<String>('settings');
    } else {
      box = await Hive.openBox<String>('settings');
    }
    var id = box.get('user_app_id');
    if (id == null) {
      id = const Uuid().v4();
      await box.put('user_app_id', id);
    }
    _cachedAppId = id;
    return id;
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return getPlatformName();
  }

  // ───────── ingest helpers ─────────

  Future<void> sendHeartbeat() async {
    try {
      final id = await userAppId;
      final body = {
        'user_app_id': id,
        'platform': _platform,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        debugPrint('Heartbeat failed: ${res.body}');
      }
    } on TimeoutException {
      debugPrint('Heartbeat timeout after 10 seconds');
    } catch (e) {
      debugPrint('Heartbeat error: $e');
    }
  }

  Future<void> trackEvent(
    String event, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final id = await userAppId;
      final body = {
        'user_app_id': id,
        'event': event,
        'platform': _platform,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/event'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        debugPrint('Event tracking failed: ${res.body}');
      }
    } on TimeoutException {
      debugPrint('Event tracking timeout after 10 seconds');
    } catch (e) {
      debugPrint('Event tracking error: $e');
    }
  }

  Future<void> reportUsage(Map<String, dynamic> stats) async {
    try {
      final id = await userAppId;
      final payload = {
        'user_app_id': id,
        'total_workouts': stats['totalWorkouts'],
        'weekly_workouts': stats['weeklyWorkouts'],
        'weekly_volume': stats['weeklyVolume'],
        'exercises_this_week': stats['exercisesThisWeek'],
        'platform': _platform,
        'report_date': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/report'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('Failed to report usage: ${response.body}');
      }
    } on TimeoutException {
      debugPrint('Usage report timeout after 10 seconds');
    } catch (e) {
      debugPrint('Error reporting usage: $e');
    }
  }

  Future<bool> backupData(Map<String, dynamic> data) async {
    try {
      final id = await userAppId;

      final payload = <String, dynamic>{'user_app_id': id, ...data};

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/backup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('Failed to backup data: ${response.body}');
        return false;
      }
    } on TimeoutException {
      debugPrint('Backup upload timeout after 2 minutes');
      return false;
    } catch (e) {
      debugPrint('Error backing up data: $e');
      return false;
    }
  }
}
