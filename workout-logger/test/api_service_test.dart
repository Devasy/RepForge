import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repforge/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Box<String> settingsBox;
  late ApiService service;

  setUpAll(() async {
    Hive.init('./test/tmp_hive_api_service');
    if (Hive.isBoxOpen('settings')) {
      settingsBox = Hive.box<String>('settings');
    } else {
      settingsBox = await Hive.openBox<String>('settings');
    }
  });

  setUp(() {
    service = ApiService();
  });

  tearDownAll(() async {
    await settingsBox.close();
    await Hive.deleteFromDisk();
  });

  group('ApiService', () {
    test('userAppId returns non-empty string and persists to box', () async {
      final id = await service.userAppId;
      expect(id, isNotEmpty);
      expect(settingsBox.get('user_app_id'), equals(id));

      final secondCall = await service.userAppId;
      expect(secondCall, equals(id));
    });

    test('sendHeartbeat sends POST request to /heartbeat', () async {
      bool called = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/heartbeat') {
          called = true;
          final jsonBody = jsonDecode(request.body) as Map<String, dynamic>;
          expect(jsonBody.containsKey('user_app_id'), isTrue);
          expect(jsonBody.containsKey('platform'), isTrue);
          return http.Response('{"status": "ok"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      ApiService.setTestClient(mockClient);
      await service.sendHeartbeat();
      expect(called, isTrue);
    });

    test('trackEvent sends POST request to /event with metadata', () async {
      bool called = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/event') {
          called = true;
          final jsonBody = jsonDecode(request.body) as Map<String, dynamic>;
          expect(jsonBody['event'], equals('workout_started'));
          expect(jsonBody['metadata'], equals({'routine_id': 'rot_123'}));
          return http.Response('{"status": "ok"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      ApiService.setTestClient(mockClient);
      await service.trackEvent('workout_started', metadata: {'routine_id': 'rot_123'});
      expect(called, isTrue);
    });

    test('reportUsage posts stats to /report', () async {
      bool called = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/report') {
          called = true;
          final jsonBody = jsonDecode(request.body) as Map<String, dynamic>;
          expect(jsonBody['total_workouts'], equals(15));
          expect(jsonBody['weekly_volume'], equals(12500.0));
          return http.Response('{"status": "ok"}', 200);
        }
        return http.Response('Error', 500);
      });

      ApiService.setTestClient(mockClient);
      await service.reportUsage({
        'totalWorkouts': 15,
        'weeklyWorkouts': 3,
        'weeklyVolume': 12500.0,
        'exercisesThisWeek': 12,
      });
      expect(called, isTrue);
    });

    test('backupData posts backup payload and returns true on 200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/backup') {
          return http.Response('{"status": "success"}', 200);
        }
        return http.Response('Forbidden', 403);
      });

      ApiService.setTestClient(mockClient);
      final result = await service.backupData({'routines': [], 'sessions': []});
      expect(result, isTrue);
    });

    test('backupData returns false on error status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Error', 500);
      });

      ApiService.setTestClient(mockClient);
      final result = await service.backupData({});
      expect(result, isFalse);
    });
  });
}
