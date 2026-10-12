import 'dart:async';

import 'package:flutter/services.dart';

/// Schedules the Android alert outside the Flutter process so it can fire
/// while the screen is locked. Calls are serialized: an earlier permission
/// request must never schedule an alert after a later skip or adjustment.
class RestAlertService {
  RestAlertService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('repforge/rest_alert');

  final MethodChannel _channel;
  Future<void> _pending = Future<void>.value();

  Future<void> schedule(
    DateTime deadline, {
    required bool sound,
    required bool vibration,
  }) => _enqueue(() async {
    try {
      final permitted = await _channel.invokeMethod<bool>('requestPermission');
      if (permitted != true || !deadline.isAfter(DateTime.now())) return;
      await _channel.invokeMethod<void>('schedule', {
        'deadlineMillis': deadline.millisecondsSinceEpoch,
        'sound': sound,
        'vibration': vibration,
      });
    } on MissingPluginException {
      // The foreground countdown still works on non-Android platforms.
    } on PlatformException {
      // Permission or alarm access can be revoked in system settings.
    }
  });

  Future<void> cancel() => _enqueue(() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // No native alarm exists on this platform.
    } on PlatformException {
      // The countdown remains usable if the system service is unavailable.
    }
  });

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
}
