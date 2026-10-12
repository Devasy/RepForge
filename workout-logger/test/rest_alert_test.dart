import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/rest_alert_service.dart';
import 'package:repforge/services/rest_countdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('countdown uses elapsed time and adjustments update its deadline', () {
    var now = DateTime.utc(2026, 10, 12);
    final rest = RestCountdown(90, clock: () => now);
    now = now.add(const Duration(seconds: 27, milliseconds: 100));
    expect(rest.remainingSeconds, 63);
    rest.adjust(30);
    expect(rest.remainingSeconds, 93);
    now = now.add(const Duration(minutes: 2));
    expect(rest.remainingSeconds, 0);
    rest.adjust(30);
    expect(rest.remainingSeconds, 30);
    rest.adjust(-60);
    expect(rest.remainingSeconds, 0);
  });

  test(
    'skipping while permission is pending cancels a late schedule',
    () async {
      const channel = MethodChannel('repforge/rest_alert_test');
      final permission = Completer<bool>();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'requestPermission') return permission.future;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final alerts = RestAlertService(channel: channel);
      final scheduled = alerts.schedule(
        DateTime.now().add(const Duration(minutes: 2)),
        sound: true,
        vibration: false,
      );
      final cancelled = alerts.cancel();
      permission.complete(true);
      await Future.wait([scheduled, cancelled]);
      expect(calls, ['requestPermission', 'schedule', 'cancel']);
    },
  );

  test('denied notification permission never schedules an alarm', () async {
    const channel = MethodChannel('repforge/rest_alert_denied_test');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return false;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await RestAlertService(channel: channel).schedule(
      DateTime.now().add(const Duration(minutes: 1)),
      sound: false,
      vibration: false,
    );
    expect(calls, ['requestPermission']);
  });

  test('a failed platform call does not block the next cancellation', () async {
    final channel = _FailOnceChannel();
    final alerts = RestAlertService(channel: channel);
    await expectLater(alerts.cancel(), throwsStateError);
    await alerts.cancel();
    expect(channel.calls, 2);
  });
}

class _FailOnceChannel extends MethodChannel {
  _FailOnceChannel() : super('repforge/rest_alert_fail_once_test');

  int calls = 0;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    calls++;
    if (calls == 1) throw StateError('platform unavailable');
    return null;
  }
}
